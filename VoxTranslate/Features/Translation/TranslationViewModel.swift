// TranslationViewModel.swift
// VoxTranslate
//
// Main view model with full state machine for the translation flow.

import Foundation
import os.log
import SwiftUI

// MARK: - Translation State

/// The state machine for the translation flow.
enum TranslationState: Equatable {
    /// Idle — waiting for user to tap record.
    case idle
    /// Recording — microphone is active, capturing audio.
    case recording
    /// Processing — audio has been sent, waiting for translation.
    case processing
    /// Translating — partial translation results are arriving.
    case translating
    /// Speaking — translated audio is playing back.
    case speaking
    /// Error — an error occurred during translation.
    case error(String)

    var isRecording: Bool { self == .recording }
    var isProcessing: Bool { self == .processing || self == .translating }
    var isSpeaking: Bool { self == .speaking }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

// MARK: - Active Panel

/// Which panel is currently active for recording.
enum ActivePanel: Sendable {
    case top
    case bottom
}

// MARK: - Translation View Model

/// Main view model controlling the dual-panel translation interface.
///
/// Manages the complete lifecycle: recording → streaming → transcription →
/// translation → TTS playback, with automatic tier switching and error recovery.
@Observable
@MainActor
final class TranslationViewModel {
    // MARK: - Published State

    /// The current state of the translation flow.
    private(set) var state: TranslationState = .idle

    /// Source text (what the user said) — shown in the active panel.
    private(set) var sourceText: String = ""

    /// Translated text — shown in the opposite panel.
    private(set) var translatedText: String = ""

    /// Whether the source text is a partial (streaming) result.
    private(set) var isSourcePartial = false

    /// Whether the translated text is a partial result.
    private(set) var isTranslationPartial = false

    /// The currently active recording panel.
    private(set) var activePanel: ActivePanel?

    /// Current audio level for waveform visualization (0.0 to 1.0).
    var audioLevel: Float { audioStreamManager.currentAudioLevel }

    /// The conversation history for the current session.
    private(set) var conversationHistory: [ConversationEntry] = []

    /// The current engine tier.
    var currentTier: EngineTierLevel { engineManager.activeTier }

    /// Current error message, if any.
    private(set) var errorMessage: String?

    /// TTS playback speed (0.75, 1.0, 1.25).
    var playbackSpeed: Float = 1.0

    // MARK: - Dependencies

    let engineManager: EngineManager
    let languageStore: LanguageStore
    let audioStreamManager: AudioStreamManager
    let networkMonitor: NetworkMonitor
    let permissionsManager: PermissionsManager

    // MARK: - Private

    private let logger = Logger(subsystem: "com.voxtranslate", category: "TranslationVM")
    private var liveSessionTask: Task<Void, Never>?
    private var accumulatedAudioData = Data()

    // MARK: - Initialization

    init(
        engineManager: EngineManager = EngineManager(),
        languageStore: LanguageStore = LanguageStore(),
        audioStreamManager: AudioStreamManager = AudioStreamManager(),
        networkMonitor: NetworkMonitor = NetworkMonitor(),
        permissionsManager: PermissionsManager = PermissionsManager()
    ) {
        self.engineManager = engineManager
        self.languageStore = languageStore
        self.audioStreamManager = audioStreamManager
        self.networkMonitor = networkMonitor
        self.permissionsManager = permissionsManager

        setupNetworkMonitoring()
        setupAudioCallbacks()
    }

    // MARK: - Setup

    private func setupNetworkMonitoring() {
        networkMonitor.onConnectivityChanged = { [weak self] isConnected in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.engineManager.updateNetworkAvailability(isConnected)
                if !isConnected {
                    HapticManager.shared.offlineModeActivated()
                }
            }
        }
        networkMonitor.start()
    }

    private func setupAudioCallbacks() {
        audioStreamManager.onSilenceDetected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.state == .recording else { return }
                self.logger.info("Silence detected — auto-stopping recording")
                await self.stopRecording()
            }
        }
    }

    // MARK: - Recording Control

    /// Starts recording from the specified panel.
    func startRecording(from panel: ActivePanel) async {
        guard state.isIdle || state == .error("") || errorMessage != nil else {
            logger.warning("Cannot start recording in state: \(String(describing: self.state))")
            return
        }

        // Check permissions
        guard permissionsManager.hasMicrophonePermission else {
            let granted = await permissionsManager.requestMicrophonePermission()
            guard granted else {
                state = .error(VoxTranslateError.microphonePermissionDenied.localizedDescription)
                return
            }
        }

        logger.info("Starting recording from \(panel == .top ? "top" : "bottom") panel")

        activePanel = panel
        sourceText = ""
        translatedText = ""
        isSourcePartial = true
        isTranslationPartial = true
        errorMessage = nil
        state = .recording

        HapticManager.shared.recordingStarted()

        // Configure audio session
        do {
            try AudioSessionManager.shared.configure()
        } catch {
            handleError(error)
            return
        }

        // Sync engine manager state
        engineManager.isTargetArabic = currentTargetLanguage.id == "ar"
        engineManager.selectedDialect = languageStore.selectedDialect
        engineManager.reevaluateTier()

        // Start the appropriate pipeline
        if let voiceProvider = engineManager.voiceTranslationProvider {
            await startLivePipeline(voiceProvider: voiceProvider, panel: panel)
        } else {
            await startChainedPipeline(panel: panel)
        }
    }

    /// Stops recording and triggers translation.
    func stopRecording() async {
        guard state == .recording else { return }

        logger.info("Stopping recording")
        HapticManager.shared.recordingStopped()

        audioStreamManager.stopCapture()
        state = .processing

        if let voiceProvider = engineManager.voiceTranslationProvider {
            do {
                try await voiceProvider.endAudioInput()
            } catch {
                logger.error("Failed to send end-of-input: \(error.localizedDescription)")
            }
        }
    }

    /// Toggles recording on/off for the specified panel.
    func toggleRecording(for panel: ActivePanel) async {
        if state == .recording && activePanel == panel {
            await stopRecording()
        } else if state.isIdle || state == .error("") || errorMessage != nil {
            await startRecording(from: panel)
        }
    }

    // MARK: - Language Management

    /// Swaps the source and target languages.
    func swapLanguages() {
        languageStore.swapLanguages()
        HapticManager.shared.languageSwapped()
    }

    /// The effective source language for the current recording.
    var currentSourceLanguage: LanguageCode {
        switch activePanel {
        case .top: return languageStore.sourceLanguage
        case .bottom: return languageStore.targetLanguage
        case nil: return languageStore.sourceLanguage
        }
    }

    /// The effective target language for the current recording.
    var currentTargetLanguage: LanguageCode {
        switch activePanel {
        case .top: return languageStore.targetLanguage
        case .bottom: return languageStore.sourceLanguage
        case nil: return languageStore.targetLanguage
        }
    }

    // MARK: - TTS Replay

    /// Replays the TTS for the current translated text.
    func replayTranslation() async {
        guard !translatedText.isEmpty else { return }

        state = .speaking
        do {
            let audioData = try await engineManager.speechSynthesisProvider.synthesize(
                translatedText,
                language: currentTargetLanguage,
                dialect: currentTargetLanguage.id == "ar" ? languageStore.selectedDialect : nil
            )
            try audioStreamManager.playAudio(audioData) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                }
            }
        } catch {
            logger.error("TTS replay failed: \(error.localizedDescription)")
            state = .idle
        }
    }

    /// Replays TTS for a specific conversation entry.
    func replayEntry(_ entry: ConversationEntry) async {
        if let audio = entry.cachedAudio {
            state = .speaking
            do {
                try audioStreamManager.playAudio(audio) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.state = .idle
                    }
                }
            } catch {
                state = .idle
            }
        } else {
            translatedText = entry.translatedText
            await replayTranslation()
        }
    }

    // MARK: - History

    /// Clears the conversation history.
    func clearHistory() {
        conversationHistory.removeAll()
    }
}

// MARK: - Gemini Live Pipeline (Tier 1)

private extension TranslationViewModel {
    func startLivePipeline(voiceProvider: VoiceTranslationProvider, panel: ActivePanel) async {
        let source = currentSourceLanguage
        let target = currentTargetLanguage
        let dialect = target.id == "ar" ? languageStore.selectedDialect : nil

        do {
            // Start the live session
            try await voiceProvider.startSession(
                sourceLanguage: source,
                targetLanguage: target,
                dialect: dialect
            )

            // Set up audio streaming from mic to Gemini
            audioStreamManager.onAudioCaptured = { [weak self] audioChunk in
                guard let self else { return }
                Task {
                    try? await voiceProvider.streamAudio(audioChunk)
                }
            }

            // Start capturing audio
            try audioStreamManager.startCapture()

            // Start receiving results
            liveSessionTask = Task { [weak self] in
                guard let self else { return }
                do {
                    for try await event in voiceProvider.receiveResults() {
                        await self.handleTranslationEvent(event)
                    }
                } catch {
                    await MainActor.run {
                        self.handleError(error)
                    }
                }
            }
        } catch {
            logger.error("Failed to start live pipeline: \(error.localizedDescription)")
            engineManager.reportGeminiLiveFailure()
            handleError(error)

            // Attempt fallback to chained pipeline
            if engineManager.activeTier != .tier1GeminiLive {
                await startChainedPipeline(panel: panel)
            }
        }
    }

    @MainActor
    func handleTranslationEvent(_ event: TranslationEvent) {
        switch event {
        case .sessionStarted:
            logger.info("Live session started")

        case .partialTranscription(let text):
            sourceText = text
            isSourcePartial = true

        case .finalTranscription(let text):
            sourceText = text
            isSourcePartial = false

        case .partialTranslation(let text):
            translatedText = text
            isTranslationPartial = true
            if state == .processing {
                state = .translating
            }

        case .finalTranslation(let text):
            translatedText = text
            isTranslationPartial = false
            state = .translating

        case .audioChunk(let data):
            if state != .speaking {
                state = .speaking
                do {
                    try audioStreamManager.preparePlayback()
                    audioStreamManager.setPlaybackRate(playbackSpeed)
                } catch {
                    logger.error("Failed to prepare playback: \(error.localizedDescription)")
                }
            }
            audioStreamManager.playAudioChunk(data)

        case .audioComplete:
            logger.info("Audio response complete")

        case .turnComplete:
            addToHistory()
            state = .idle
            HapticManager.shared.translationComplete()

        case .languageDetected(let language, let dialect):
            logger.info("Detected language: \(language.englishName), dialect: \(dialect?.englishName ?? "none")")

        case .error(let voxError):
            handleError(voxError)
        }
    }
}

// MARK: - Chained Pipeline (Tier 2 / Tier 3)

private extension TranslationViewModel {
    func startChainedPipeline(panel: ActivePanel) async {
        let source = currentSourceLanguage
        let target = currentTargetLanguage
        let dialect = target.id == "ar" ? languageStore.selectedDialect : nil

        // For chained pipeline, we accumulate all audio and then process
        accumulatedAudioData = Data()

        audioStreamManager.onAudioCaptured = { [weak self] audioChunk in
            self?.accumulatedAudioData.append(audioChunk)
        }

        do {
            try audioStreamManager.startCapture()
        } catch {
            handleError(error)
            return
        }

        // When recording stops (state changes to .processing), run the chain
        // This is handled by observing state changes in stopRecording()
        // After stopRecording sets state to .processing, we continue here

        // Wait for recording to stop
        while state == .recording {
            try? await Task.sleep(for: .milliseconds(100))
        }

        guard state == .processing else { return }

        // Step 1: STT
        do {
            let sttProvider = engineManager.speechRecognitionProvider
            let stream = sttProvider.startStreaming(locale: source.locale)

            var finalText = ""
            // For batch processing with accumulated audio, we use the Hamsa batch API if available
            if let hamsaSTT = sttProvider as? HamsaSTTService {
                let transcript = try await hamsaSTT.transcribe(audioData: accumulatedAudioData, locale: source.locale)
                finalText = transcript.text
                sourceText = finalText
                isSourcePartial = false
            } else {
                // For Apple STT, we would need to feed the audio buffer
                // This is a simplified implementation
                for try await transcript in stream {
                    sourceText = transcript.text
                    isSourcePartial = !transcript.isFinal
                    if transcript.isFinal {
                        finalText = transcript.text
                        break
                    }
                }
            }

            guard !finalText.isEmpty else {
                HapticManager.shared.noSpeechDetected()
                state = .error(VoxTranslateError.noSpeechDetected.localizedDescription)
                errorMessage = VoxTranslateError.noSpeechDetected.localizedDescription
                return
            }

            // Step 2: Translation
            state = .translating
            let result = try await engineManager.translationProvider.translate(
                finalText,
                from: source,
                to: target,
                dialect: dialect
            )
            translatedText = result.translatedText
            isTranslationPartial = false

            // Step 3: TTS
            state = .speaking
            let audioData = try await engineManager.speechSynthesisProvider.synthesize(
                result.translatedText,
                language: target,
                dialect: dialect
            )

            try audioStreamManager.playAudio(audioData) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.state = .idle
                    self?.addToHistory()
                    HapticManager.shared.translationComplete()
                }
            }
        } catch {
            handleError(error)
        }
    }
}

// MARK: - History Management

private extension TranslationViewModel {
    func addToHistory() {
        guard !sourceText.isEmpty, !translatedText.isEmpty else { return }

        let entry = ConversationEntry(
            sourceText: sourceText,
            sourceLanguage: currentSourceLanguage,
            translatedText: translatedText,
            targetLanguage: currentTargetLanguage,
            dialect: currentTargetLanguage.id == "ar" ? languageStore.selectedDialect : nil,
            engineTier: EngineTier(rawValue: engineManager.activeTier == .tier1GeminiLive ? "gemini_live" :
                                    engineManager.activeTier == .tier2Hamsa ? "hamsa" : "apple") ?? .geminiLive
        )

        conversationHistory.insert(entry, at: 0)
    }
}

// MARK: - Error Handling

private extension TranslationViewModel {
    func handleError(_ error: Error) {
        let message: String
        if let voxError = error as? VoxTranslateError {
            message = voxError.localizedDescription
        } else {
            message = error.localizedDescription
        }

        logger.error("Translation error: \(message)")
        errorMessage = message
        state = .idle
        HapticManager.shared.translationError()

        audioStreamManager.stopCapture()
        audioStreamManager.stopPlayback()
        liveSessionTask?.cancel()
        liveSessionTask = nil
    }
}

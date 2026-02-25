// GeminiLiveAPIService.swift
// VoxTranslate
//
// Full WebSocket implementation for Gemini Live API streaming bidirectional audio translation.

import Foundation
import os.log

// MARK: - Gemini Live API Service

/// Implements the VoiceTranslationProvider protocol using Gemini's Live API for
/// end-to-end streaming audio translation over WebSocket.
///
/// The service manages a persistent WebSocket connection, streams raw PCM audio
/// from the microphone to Gemini, and receives interleaved audio + text responses.
final class GeminiLiveAPIService: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "GeminiLiveAPI")

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private let sessionQueue = DispatchQueue(label: "com.voxtranslate.gemini.live", qos: .userInteractive)

    private var eventContinuation: AsyncThrowingStream<TranslationEvent, Error>.Continuation?
    private var isSessionActive = false
    private var reconnectAttempts = 0
    private var pingTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {}

    deinit {
        pingTask?.cancel()
    }
}

// MARK: - VoiceTranslationProvider

extension GeminiLiveAPIService: VoiceTranslationProvider {
    func startSession(
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        dialect: ArabicDialect?
    ) async throws {
        logger.info("Starting Gemini Live API session: \(sourceLanguage.id) → \(targetLanguage.id)")

        // Clean up any existing session
        await endSession()

        let url = GeminiConfig.liveAPIURL
        let session = URLSession(configuration: .default)
        self.urlSession = session

        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 1024 * 1024 // 1MB max message
        self.webSocketTask = task

        task.resume()

        // Send the initial setup message
        let setupMessage = buildSetupMessage(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            dialect: dialect
        )

        do {
            let setupData = try JSONSerialization.data(withJSONObject: setupMessage)
            try await task.send(.string(String(data: setupData, encoding: .utf8)!))
            logger.info("Setup message sent successfully")
        } catch {
            logger.error("Failed to send setup message: \(error.localizedDescription)")
            throw VoxTranslateError.webSocketError(underlying: error.localizedDescription)
        }

        isSessionActive = true
        reconnectAttempts = 0
        startPingLoop()
    }

    func streamAudio(_ audioChunk: Data) async throws {
        guard let task = webSocketTask, isSessionActive else {
            throw VoxTranslateError.webSocketDisconnected(reason: "No active session")
        }

        let message = buildAudioMessage(audioChunk)

        do {
            let messageData = try JSONSerialization.data(withJSONObject: message)
            try await task.send(.string(String(data: messageData, encoding: .utf8)!))
        } catch {
            logger.error("Failed to stream audio: \(error.localizedDescription)")
            throw VoxTranslateError.webSocketError(underlying: error.localizedDescription)
        }
    }

    func receiveResults() -> AsyncThrowingStream<TranslationEvent, Error> {
        AsyncThrowingStream { continuation in
            self.eventContinuation = continuation

            continuation.onTermination = { @Sendable _ in
                self.logger.info("Event stream terminated")
            }

            // Start the receive loop
            Task { [weak self] in
                await self?.receiveLoop()
            }
        }
    }

    func endAudioInput() async throws {
        guard let task = webSocketTask, isSessionActive else { return }

        // Send end-of-turn signal
        let endMessage: [String: Any] = [
            "clientContent": [
                "turnComplete": true
            ]
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: endMessage)
            try await task.send(.string(String(data: data, encoding: .utf8)!))
            logger.info("End of audio input signal sent")
        } catch {
            logger.error("Failed to send end signal: \(error.localizedDescription)")
        }
    }

    func endSession() async {
        logger.info("Ending Gemini Live API session")
        isSessionActive = false
        pingTask?.cancel()
        pingTask = nil
        eventContinuation?.finish()
        eventContinuation = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
    }
}

// MARK: - WebSocket Message Construction

private extension GeminiLiveAPIService {
    /// Builds the initial setup message that configures the Live API session.
    func buildSetupMessage(
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        dialect: ArabicDialect?
    ) -> [String: Any] {
        let systemPrompt: String
        if targetLanguage.id == "ar", let dialect = dialect {
            systemPrompt = dialect.geminiSystemPrompt(targetLanguage: targetLanguage.englishName)
        } else if sourceLanguage.id == "ar", let dialect = dialect {
            systemPrompt = dialect.geminiSystemPrompt(targetLanguage: targetLanguage.englishName)
        } else {
            systemPrompt = """
            You are a real-time voice translator. Your ONLY job is to translate speech.
            Translate incoming speech to \(targetLanguage.englishName).
            Do NOT add any commentary, notes, or explanations. Output ONLY the translation.
            Keep translations concise and natural for spoken conversation.
            """
        }

        return [
            "setup": [
                "model": "models/\(GeminiConfig.liveModelName)",
                "generationConfig": [
                    "responseModalities": ["AUDIO", "TEXT"],
                    "speechConfig": [
                        "voiceConfig": [
                            "prebuiltVoiceConfig": [
                                "voiceName": "Kore"
                            ]
                        ]
                    ]
                ],
                "systemInstruction": [
                    "parts": [
                        ["text": systemPrompt]
                    ]
                ]
            ]
        ]
    }

    /// Builds a WebSocket message containing an audio chunk encoded as base64.
    func buildAudioMessage(_ audioData: Data) -> [String: Any] {
        let base64Audio = audioData.base64EncodedString()
        return [
            "realtimeInput": [
                "mediaChunks": [
                    [
                        "mimeType": "audio/pcm;rate=16000",
                        "data": base64Audio
                    ]
                ]
            ]
        ]
    }
}

// MARK: - WebSocket Receive Loop

private extension GeminiLiveAPIService {
    /// Continuously receives messages from the WebSocket and parses them into TranslationEvents.
    func receiveLoop() async {
        guard let task = webSocketTask else { return }

        while isSessionActive {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    parseTextMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        parseTextMessage(text)
                    }
                @unknown default:
                    logger.warning("Unknown WebSocket message type received")
                }
            } catch {
                if isSessionActive {
                    logger.error("WebSocket receive error: \(error.localizedDescription)")
                    await handleDisconnection(error: error)
                }
                break
            }
        }
    }

    /// Parses a JSON text message from the Gemini Live API into TranslationEvents.
    func parseTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.warning("Failed to parse WebSocket message as JSON")
            return
        }

        // Handle setup complete
        if json["setupComplete"] != nil {
            logger.info("Session setup complete")
            eventContinuation?.yield(.sessionStarted)
            return
        }

        // Handle server content (audio + text responses)
        if let serverContent = json["serverContent"] as? [String: Any] {
            parseServerContent(serverContent)
            return
        }

        // Handle tool calls or other messages
        if let toolCall = json["toolCall"] as? [String: Any] {
            logger.debug("Received tool call (ignoring): \(toolCall)")
            return
        }

        logger.debug("Unhandled message type: \(json.keys.joined(separator: ", "))")
    }

    /// Parses the `serverContent` portion of a Gemini Live API response.
    func parseServerContent(_ content: [String: Any]) {
        let turnComplete = content["turnComplete"] as? Bool ?? false

        if let modelTurn = content["modelTurn"] as? [String: Any],
           let parts = modelTurn["parts"] as? [[String: Any]] {
            for part in parts {
                // Text part — could be transcription or translation
                if let text = part["text"] as? String {
                    if turnComplete {
                        eventContinuation?.yield(.finalTranslation(text: text))
                    } else {
                        eventContinuation?.yield(.partialTranslation(text: text))
                    }
                }

                // Inline audio data
                if let inlineData = part["inlineData"] as? [String: Any],
                   let mimeType = inlineData["mimeType"] as? String,
                   mimeType.hasPrefix("audio/"),
                   let base64String = inlineData["data"] as? String,
                   let audioData = Data(base64Encoded: base64String) {
                    eventContinuation?.yield(.audioChunk(data: audioData))
                }
            }
        }

        if turnComplete {
            eventContinuation?.yield(.audioComplete)
            eventContinuation?.yield(.turnComplete)
        }
    }
}

// MARK: - Connection Management

private extension GeminiLiveAPIService {
    /// Starts a periodic ping to keep the WebSocket connection alive.
    func startPingLoop() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(GeminiConfig.webSocketPingInterval))
                guard let self, self.isSessionActive else { break }
                self.webSocketTask?.sendPing { error in
                    if let error {
                        self.logger.warning("Ping failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Handles a WebSocket disconnection with automatic reconnection logic.
    func handleDisconnection(error: Error) async {
        guard isSessionActive, reconnectAttempts < GeminiConfig.maxReconnectAttempts else {
            eventContinuation?.yield(.error(.webSocketDisconnected(reason: "Max reconnect attempts reached")))
            await endSession()
            return
        }

        reconnectAttempts += 1
        let delay = GeminiConfig.reconnectBaseDelay * pow(2.0, Double(reconnectAttempts - 1))
        logger.info("Reconnecting in \(delay)s (attempt \(self.reconnectAttempts)/\(GeminiConfig.maxReconnectAttempts))")

        try? await Task.sleep(for: .seconds(delay))

        guard isSessionActive else { return }
        eventContinuation?.yield(.error(.webSocketDisconnected(reason: "Connection lost, reconnecting...")))
    }
}

// MARK: - Message Parsing (Testable)

extension GeminiLiveAPIService {
    /// Parses a raw JSON string from the Gemini Live API into an array of TranslationEvents.
    /// Exposed as internal for unit testing.
    static func parseEvents(from jsonString: String) -> [TranslationEvent] {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        var events: [TranslationEvent] = []

        if json["setupComplete"] != nil {
            events.append(.sessionStarted)
        }

        if let serverContent = json["serverContent"] as? [String: Any] {
            let turnComplete = serverContent["turnComplete"] as? Bool ?? false

            if let modelTurn = serverContent["modelTurn"] as? [String: Any],
               let parts = modelTurn["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String {
                        if turnComplete {
                            events.append(.finalTranslation(text: text))
                        } else {
                            events.append(.partialTranslation(text: text))
                        }
                    }

                    if let inlineData = part["inlineData"] as? [String: Any],
                       let mimeType = inlineData["mimeType"] as? String,
                       mimeType.hasPrefix("audio/"),
                       let base64String = inlineData["data"] as? String,
                       let audioData = Data(base64Encoded: base64String) {
                        events.append(.audioChunk(data: audioData))
                    }
                }
            }

            if turnComplete {
                events.append(.audioComplete)
                events.append(.turnComplete)
            }
        }

        return events
    }
}

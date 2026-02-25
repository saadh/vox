// AudioStreamManager.swift
// VoxTranslate
//
// AVAudioEngine capture and playback management for streaming audio to/from the Gemini Live API.

import AVFoundation
import Foundation
import os.log

// MARK: - Audio Stream Manager

/// Manages microphone audio capture and speaker playback using AVAudioEngine.
///
/// Captures PCM audio from the microphone, converts it to the format required by
/// the Gemini Live API (16-bit, 16kHz, mono), and provides streaming playback for
/// received audio chunks.
@Observable
final class AudioStreamManager: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "AudioStream")

    private let audioEngine = AVAudioEngine()
    private var playerNode: AVAudioPlayerNode?
    private var audioConverter: AVAudioConverter?

    /// Current audio level from the microphone (0.0 to 1.0), used for waveform visualization.
    private(set) var currentAudioLevel: Float = 0.0

    /// Whether the audio engine is currently capturing microphone input.
    private(set) var isCapturing = false

    /// Whether audio is currently being played back.
    private(set) var isPlaying = false

    /// Callback for audio chunks captured from the microphone.
    /// Each chunk is ~100ms of PCM 16-bit 16kHz mono audio.
    var onAudioCaptured: ((Data) -> Void)?

    /// Callback when silence is detected for auto-stop.
    var onSilenceDetected: (() -> Void)?

    // MARK: - Audio Level Monitoring

    private var silenceStartTime: Date?
    private let silenceThreshold: Float = 0.01
    private let silenceDuration: TimeInterval = 1.5

    // MARK: - Target Format

    /// The audio format expected by Gemini's Live API for input.
    private var targetInputFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: GeminiConfig.InputAudio.sampleRate,
            channels: AVAudioChannelCount(GeminiConfig.InputAudio.channelCount),
            interleaved: true
        )!
    }

    /// The audio format for Gemini's output audio playback.
    private var outputPlaybackFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: GeminiConfig.OutputAudio.sampleRate,
            channels: AVAudioChannelCount(GeminiConfig.OutputAudio.channelCount),
            interleaved: true
        )!
    }
}

// MARK: - Capture (Microphone → Gemini)

extension AudioStreamManager {
    /// Starts capturing audio from the microphone and streaming chunks via `onAudioCaptured`.
    ///
    /// - Throws: `VoxTranslateError.audioEngineFailed` if the engine fails to start.
    func startCapture() throws {
        guard !isCapturing else { return }

        logger.info("Starting audio capture")

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create converter from microphone format to Gemini's expected format
        guard let converter = AVAudioConverter(from: inputFormat, to: targetInputFormat) else {
            throw VoxTranslateError.audioEngineFailed(
                underlying: "Cannot create audio converter from \(inputFormat) to \(self.targetInputFormat)"
            )
        }
        self.audioConverter = converter

        // Install a tap on the input node to capture audio
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * GeminiConfig.InputAudio.chunkDuration)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Update audio level for waveform visualization
            self.updateAudioLevel(from: buffer)

            // Convert to target format and send chunk
            if let convertedData = self.convertBuffer(buffer, using: converter) {
                self.onAudioCaptured?(convertedData)
            }

            // Check for silence
            self.checkSilence()
        }

        do {
            try audioEngine.start()
            isCapturing = true
            silenceStartTime = nil
            logger.info("Audio capture started at \(inputFormat.sampleRate)Hz")
        } catch {
            inputNode.removeTap(onBus: 0)
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
            throw VoxTranslateError.audioEngineFailed(underlying: error.localizedDescription)
        }
    }

    /// Stops capturing audio from the microphone.
    func stopCapture() {
        guard isCapturing else { return }

        logger.info("Stopping audio capture")
        audioEngine.inputNode.removeTap(onBus: 0)

        if !isPlaying {
            audioEngine.stop()
        }

        isCapturing = false
        currentAudioLevel = 0.0
        silenceStartTime = nil
    }
}

// MARK: - Playback (Gemini → Speaker)

extension AudioStreamManager {
    /// Prepares the playback pipeline for receiving audio chunks.
    func preparePlayback() throws {
        guard playerNode == nil else { return }

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: outputPlaybackFormat)
        self.playerNode = player

        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                logger.error("Failed to start audio engine for playback: \(error.localizedDescription)")
                throw VoxTranslateError.audioEngineFailed(underlying: error.localizedDescription)
            }
        }

        player.play()
        isPlaying = true
        logger.info("Playback pipeline prepared")
    }

    /// Plays a chunk of audio data received from the Gemini Live API.
    ///
    /// - Parameter data: Raw PCM audio data (16-bit, 24kHz, mono).
    func playAudioChunk(_ data: Data) {
        guard let player = playerNode else {
            logger.warning("Player node not initialized — call preparePlayback() first")
            return
        }

        let frameCount = AVAudioFrameCount(data.count / GeminiConfig.OutputAudio.bytesPerSample)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputPlaybackFormat, frameCapacity: frameCount) else {
            logger.warning("Failed to create playback buffer")
            return
        }

        buffer.frameLength = frameCount
        data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData?[0], baseAddress, data.count)
            }
        }

        player.scheduleBuffer(buffer)
    }

    /// Plays a complete AudioData object.
    ///
    /// - Parameter audioData: The audio to play.
    /// - Parameter completion: Called when playback finishes.
    func playAudio(_ audioData: AudioData, completion: (() -> Void)? = nil) throws {
        try preparePlayback()

        let frameCount = AVAudioFrameCount(audioData.data.count / (audioData.bitsPerSample / 8))
        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: audioData.sampleRate,
            channels: AVAudioChannelCount(audioData.channelCount),
            interleaved: true
        )!

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw VoxTranslateError.audioEngineFailed(underlying: "Failed to create playback buffer")
        }

        buffer.frameLength = frameCount
        audioData.data.withUnsafeBytes { rawBuffer in
            if let baseAddress = rawBuffer.baseAddress {
                memcpy(buffer.int16ChannelData?[0], baseAddress, audioData.data.count)
            }
        }

        playerNode?.scheduleBuffer(buffer) {
            DispatchQueue.main.async {
                completion?()
            }
        }
    }

    /// Stops audio playback.
    func stopPlayback() {
        playerNode?.stop()
        isPlaying = false

        if !isCapturing {
            audioEngine.stop()
        }

        logger.info("Playback stopped")
    }

    /// Sets the playback rate (0.75, 1.0, 1.25).
    func setPlaybackRate(_ rate: Float) {
        playerNode?.rate = rate
    }
}

// MARK: - Audio Processing

private extension AudioStreamManager {
    /// Converts an audio buffer from the microphone format to Gemini's expected format.
    func convertBuffer(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> Data? {
        let ratio = targetInputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: targetInputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return nil }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                outStatus.pointee = .haveData
                hasData = false
                return buffer
            }
            outStatus.pointee = .noDataNow
            return nil
        }

        if let error = error {
            logger.warning("Audio conversion error: \(error.localizedDescription)")
            return nil
        }

        guard let channelData = outputBuffer.int16ChannelData else { return nil }
        let byteCount = Int(outputBuffer.frameLength) * GeminiConfig.InputAudio.bytesPerSample
        return Data(bytes: channelData[0], count: byteCount)
    }

    /// Updates the current audio level from a buffer for waveform visualization.
    func updateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }

        let average = sum / Float(frameLength)
        // Smooth the level to avoid jittery waveforms
        let smoothed = currentAudioLevel * 0.7 + average * 0.3
        currentAudioLevel = min(smoothed, 1.0)
    }

    /// Checks if silence has been detected for auto-stop.
    func checkSilence() {
        if currentAudioLevel < silenceThreshold {
            if silenceStartTime == nil {
                silenceStartTime = Date()
            } else if let start = silenceStartTime,
                      Date().timeIntervalSince(start) >= silenceDuration {
                onSilenceDetected?()
                silenceStartTime = nil
            }
        } else {
            silenceStartTime = nil
        }
    }
}

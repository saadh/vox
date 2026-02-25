// AudioSessionManager.swift
// VoxTranslate
//
// AVAudioSession configuration for simultaneous recording and playback.

import AVFoundation
import Foundation
import os.log

// MARK: - Audio Session Manager

/// Manages the AVAudioSession configuration for VoxTranslate.
///
/// Configures the audio session for simultaneous microphone recording and speaker playback,
/// supporting Bluetooth devices and low-latency audio processing.
final class AudioSessionManager: Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "AudioSession")

    /// Shared singleton instance.
    static let shared = AudioSessionManager()

    private init() {}

    // MARK: - Configuration

    /// Configures the audio session for voice translation.
    ///
    /// Sets up simultaneous recording and playback with low-latency settings
    /// optimized for the Gemini Live API's audio format requirements.
    ///
    /// - Throws: `VoxTranslateError.audioSessionSetupFailed` if configuration fails.
    func configure() throws {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers
            ])

            // Set preferred sample rate to match Gemini's expected input (16kHz)
            try session.setPreferredSampleRate(16000)

            // 10ms buffer for low latency
            try session.setPreferredIOBufferDuration(0.01)

            try session.setActive(true, options: .notifyOthersOnDeactivation)

            logger.info("Audio session configured successfully. Sample rate: \(session.sampleRate)Hz, Buffer: \(session.ioBufferDuration)s")
        } catch {
            logger.error("Failed to configure audio session: \(error.localizedDescription)")
            throw VoxTranslateError.audioSessionSetupFailed(underlying: error.localizedDescription)
        }
    }

    /// Deactivates the audio session.
    ///
    /// Call this when the app moves to the background or when translation is not actively in use.
    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            logger.info("Audio session deactivated")
        } catch {
            logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Route Monitoring

    /// The current audio output route (speaker, headphones, Bluetooth, etc.)
    var currentOutputRoute: String {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.first?.portName ?? "Unknown"
    }

    /// Whether headphones or Bluetooth audio output is connected.
    var isExternalOutputConnected: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
        }
    }

    // MARK: - Permissions

    /// Requests microphone recording permission.
    /// - Returns: `true` if permission was granted.
    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// The current microphone permission status.
    var microphonePermissionStatus: AVAudioSession.RecordPermission {
        AVAudioSession.sharedInstance().recordPermission
    }
}

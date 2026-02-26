// PermissionsManager.swift
// VoxTranslate
//
// Centralized permission management for microphone and speech recognition.

import AVFoundation
import Foundation
import Speech
import UIKit
import os.log

// MARK: - Permissions Manager

/// Manages permission requests and status checks for microphone and speech recognition.
@Observable
final class PermissionsManager: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "Permissions")

    /// Whether microphone permission has been granted.
    private(set) var hasMicrophonePermission = false

    /// Whether speech recognition permission has been granted.
    private(set) var hasSpeechRecognitionPermission = false

    /// Whether all required permissions are granted.
    var hasAllRequiredPermissions: Bool {
        hasMicrophonePermission
    }

    /// Whether all permissions (including optional) are granted.
    var hasAllPermissions: Bool {
        hasMicrophonePermission && hasSpeechRecognitionPermission
    }

    // MARK: - Initialization

    init() {
        refreshStatus()
    }

    // MARK: - Status Refresh

    /// Refreshes the current permission statuses.
    func refreshStatus() {
        hasMicrophonePermission = AVAudioSession.sharedInstance().recordPermission == .granted
        hasSpeechRecognitionPermission = SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Permission Requests

    /// Requests microphone permission.
    /// - Returns: `true` if permission was granted.
    @discardableResult
    func requestMicrophonePermission() async -> Bool {
        if hasMicrophonePermission { return true }

        let granted = await AVAudioApplication.requestRecordPermission()
        hasMicrophonePermission = granted

        if granted {
            logger.info("Microphone permission granted")
        } else {
            logger.warning("Microphone permission denied")
        }

        return granted
    }

    /// Requests speech recognition permission (needed for Tier 3 offline mode).
    /// - Returns: `true` if permission was granted.
    @discardableResult
    func requestSpeechRecognitionPermission() async -> Bool {
        if hasSpeechRecognitionPermission { return true }

        let granted = await AppleSpeechRecognitionService.requestAuthorization()
        hasSpeechRecognitionPermission = granted

        if granted {
            logger.info("Speech recognition permission granted")
        } else {
            logger.warning("Speech recognition permission denied")
        }

        return granted
    }

    /// Requests all required permissions sequentially.
    func requestAllPermissions() async {
        await requestMicrophonePermission()
        await requestSpeechRecognitionPermission()
    }

    // MARK: - Settings Deep Link

    /// Opens the app's settings page in the Settings app.
    @MainActor
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

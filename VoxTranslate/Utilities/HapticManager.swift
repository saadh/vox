// HapticManager.swift
// VoxTranslate
//
// Haptic feedback patterns for recording, translation, and error states.

import UIKit
import os.log

// MARK: - Haptic Manager

/// Provides haptic feedback for key interactions in the translation flow.
///
/// Uses UIKit's haptic engine for precise, contextual feedback that enhances
/// the tap-to-speak interaction without requiring visual attention.
final class HapticManager: Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "Haptics")

    /// Shared singleton instance.
    static let shared = HapticManager()

    private init() {}

    // MARK: - Recording Haptics

    /// Plays a haptic when the user taps to start recording.
    /// Medium impact — confirms the mic is now active.
    func recordingStarted() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Plays a haptic when the user taps to stop recording.
    /// Light impact — confirms the mic has stopped.
    func recordingStopped() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Translation Haptics

    /// Plays a success haptic when translation completes.
    func translationComplete() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Plays an error haptic when translation fails.
    func translationError() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - UI Haptics

    /// Plays a light selection haptic for language/dialect selection changes.
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    /// Plays a haptic for the language swap action.
    func languageSwapped() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Plays a warning haptic when switching to offline mode.
    func offlineModeActivated() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Plays a gentle haptic when no speech is detected (retry prompt).
    func noSpeechDetected() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
}

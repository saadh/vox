// SpeechSynthesisProvider.swift
// VoxTranslate
//
// Protocol for text-to-speech providers.

import Foundation

// MARK: - Speech Synthesis Provider

/// Handles the text to spoken audio pipeline.
///
/// Conforming types accept translated text and produce audio data suitable for playback,
/// optionally using dialect-specific pronunciation for Arabic output.
protocol SpeechSynthesisProvider: Sendable {
    /// Synthesizes speech audio from the given text.
    ///
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - language: The language of the text.
    ///   - dialect: The Arabic dialect for pronunciation, if applicable.
    ///     Pass `nil` for non-Arabic languages.
    /// - Returns: An `AudioData` container with the synthesized speech audio.
    /// - Throws: `VoxTranslateError` if synthesis fails.
    func synthesize(
        _ text: String,
        language: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> AudioData
}

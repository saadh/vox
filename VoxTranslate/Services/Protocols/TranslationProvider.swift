// TranslationProvider.swift
// VoxTranslate
//
// Protocol for text-to-translated-text providers.

import Foundation

// MARK: - Translation Provider

/// Handles the text to translated text pipeline.
///
/// Conforming types accept source text and produce a translated result, optionally
/// targeting a specific Arabic dialect for culturally appropriate output.
protocol TranslationProvider: Sendable {
    /// Translates the given text from source to target language.
    ///
    /// - Parameters:
    ///   - text: The source text to translate.
    ///   - source: The source language code.
    ///   - target: The target language code.
    ///   - dialect: The target Arabic dialect, if translating to Arabic.
    ///     Pass `nil` when translating to non-Arabic languages.
    /// - Returns: A `TranslationResult` containing the translated text and metadata.
    /// - Throws: `VoxTranslateError` if translation fails.
    func translate(
        _ text: String,
        from source: LanguageCode,
        to target: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> TranslationResult
}

// AppleTranslationService.swift
// VoxTranslate
//
// On-device translation fallback using Apple's Translation framework.

import Foundation
import Translation
import os.log

// MARK: - Apple Translation Service

/// On-device translation using Apple's `Translation` framework as the Tier 3 offline fallback.
///
/// Limitations: MSA only for Arabic, limited language pairs.
/// Requires iOS 26.0+ for programmatic translation.
@available(iOS 26.0, *)
final class AppleTranslationService: TranslationProvider, @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "AppleTranslation")

    // MARK: - TranslationProvider

    func translate(
        _ text: String,
        from source: LanguageCode,
        to target: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> TranslationResult {
        logger.info("Translating via Apple Translation: \(source.id) → \(target.id)")

        let sourceLanguage = Locale.Language(identifier: source.id)
        let targetLanguage = Locale.Language(identifier: target.id)

        let translatedText: String
        do {
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            let response = try await session.translate(text)
            translatedText = response.targetText
        } catch {
            logger.error("Apple Translation failed: \(error.localizedDescription)")
            throw VoxTranslateError.translationFailed(underlying: error.localizedDescription)
        }

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText,
            detectedSourceLanguage: source,
            targetLanguage: target,
            dialect: nil, // Apple Translation only supports MSA
            confidence: nil,
            engineTier: .apple
        )
    }
}

// MARK: - Language Pack Management

@available(iOS 26.0, *)
extension AppleTranslationService {
    /// Checks if the required language pack is available on-device.
    static func isLanguagePairAvailable(source: LanguageCode, target: LanguageCode) async -> Bool {
        let sourceLanguage = Locale.Language(identifier: source.id)
        let targetLanguage = Locale.Language(identifier: target.id)

        let availability = LanguageAvailability()
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )

        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }
}

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
/// Requires iOS 17.4+.
@available(iOS 17.4, *)
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

        guard let sourceLanguage = Locale.Language(identifier: source.id).languageCode,
              let targetLanguage = Locale.Language(identifier: target.id).languageCode else {
            throw VoxTranslateError.unsupportedLanguagePair(source: source.id, target: target.id)
        }

        let configuration = TranslationSession.Configuration(
            source: sourceLanguage,
            target: targetLanguage
        )

        let translatedText: String
        do {
            let session = try await TranslationSession(configuration: configuration)
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

@available(iOS 17.4, *)
extension AppleTranslationService {
    /// Checks if the required language pack is available on-device.
    static func isLanguagePairAvailable(source: LanguageCode, target: LanguageCode) async -> Bool {
        guard let sourceLanguage = Locale.Language(identifier: source.id).languageCode,
              let targetLanguage = Locale.Language(identifier: target.id).languageCode else {
            return false
        }

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

// HamsaTranslationService.swift
// VoxTranslate
//
// Hamsa Faseeh translation API implementation.

import Foundation
import os.log

// MARK: - Hamsa Translation Service

/// Arabic dialect translation using the Hamsa Faseeh API.
///
/// Supports 16 Arabic dialects + MSA + English with claimed 45%+ higher BLEU
/// scores than competitors for Arabic dialect translation.
final class HamsaTranslationService: TranslationProvider, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "HamsaTranslation")
    private let session: URLSession

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - TranslationProvider

    func translate(
        _ text: String,
        from source: LanguageCode,
        to target: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> TranslationResult {
        logger.info("Translating via Hamsa Faseeh: \(source.id) → \(target.id)")

        var requestBody: [String: Any] = [
            "text": text,
            "source_language": source.id,
            "target_language": target.id
        ]

        if let dialect = dialect {
            requestBody["dialect"] = HamsaConfig.hamsaDialectCode(for: dialect)
        }

        var request = URLRequest(url: URL(string: HamsaConfig.translationEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(HamsaConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = HamsaConfig.requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxTranslateError.invalidAPIResponse(service: "Hamsa", details: "Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            throw VoxTranslateError.apiError(
                service: "Hamsa",
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translatedText = json["translated_text"] as? String else {
            throw VoxTranslateError.invalidAPIResponse(
                service: "Hamsa",
                details: "Could not parse translation from response"
            )
        }

        let confidence = json["confidence"] as? Double

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText,
            detectedSourceLanguage: nil,
            targetLanguage: target,
            dialect: dialect,
            confidence: confidence,
            engineTier: .hamsa
        )
    }
}

// GeminiTranslationService.swift
// VoxTranslate
//
// REST API implementation for text translation using Gemini 2.5 Flash.

import Foundation
import os.log

// MARK: - Gemini Translation Service

/// Text translation using the Gemini 2.5 Flash REST API.
///
/// Used in parallel with the Live API to get on-screen text translation,
/// and as a fallback translation engine for the Tier 2 (Hamsa STT) pipeline.
final class GeminiTranslationService: TranslationProvider, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "GeminiTranslation")
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
        logger.info("Translating '\(text.prefix(50))...' from \(source.id) to \(target.id)")

        let prompt = buildTranslationPrompt(text: text, source: source, target: target, dialect: dialect)
        let requestBody = buildRequestBody(prompt: prompt)

        let url = GeminiConfig.restURL(for: GeminiConfig.restAPIEndpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = GeminiConfig.requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxTranslateError.invalidAPIResponse(service: "Gemini", details: "Invalid HTTP response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init)
            throw VoxTranslateError.apiRateLimited(retryAfter: retryAfter)
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            logger.error("Gemini API error \(httpResponse.statusCode): \(errorBody)")
            throw VoxTranslateError.apiError(
                service: "Gemini",
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        let translatedText = try parseTranslationResponse(data)

        return TranslationResult(
            sourceText: text,
            translatedText: translatedText,
            detectedSourceLanguage: source.id == "auto" ? nil : source,
            targetLanguage: target,
            dialect: dialect,
            confidence: nil,
            engineTier: .geminiText
        )
    }
}

// MARK: - Request Building

private extension GeminiTranslationService {
    func buildTranslationPrompt(
        text: String,
        source: LanguageCode,
        target: LanguageCode,
        dialect: ArabicDialect?
    ) -> String {
        var prompt = "Translate the following text"

        if source.id != "auto" {
            prompt += " from \(source.englishName)"
        }

        prompt += " to \(target.englishName)"

        if target.id == "ar", let dialect = dialect {
            prompt += ".\n\n\(dialect.geminiPromptFragment)"
        }

        prompt += """


        IMPORTANT: Output ONLY the translation. No explanations, no notes, no alternatives.

        Text to translate:
        \(text)
        """

        return prompt
    }

    func buildRequestBody(prompt: String) -> [String: Any] {
        [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 1024
            ]
        ]
    }
}

// MARK: - Response Parsing

private extension GeminiTranslationService {
    func parseTranslationResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw VoxTranslateError.invalidAPIResponse(
                service: "Gemini",
                details: "Could not parse translation from response"
            )
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// GeminiTTSService.swift
// VoxTranslate
//
// REST API implementation for text-to-speech using Gemini 2.5 Flash TTS.

import Foundation
import os.log

// MARK: - Gemini TTS Service

/// Text-to-speech synthesis using the Gemini 2.5 Flash TTS REST API.
///
/// Used as a fallback when the Gemini Live API session fails, or in the
/// Tier 2 chained pipeline (Hamsa STT -> Gemini Translation -> Gemini TTS).
final class GeminiTTSService: SpeechSynthesisProvider, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "GeminiTTS")
    private let session: URLSession

    // MARK: - Initialization

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - SpeechSynthesisProvider

    func synthesize(
        _ text: String,
        language: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> AudioData {
        logger.info("Synthesizing speech for '\(text.prefix(50))...' in \(language.id)")

        let requestBody = buildTTSRequestBody(text: text, language: language, dialect: dialect)

        let url = GeminiConfig.restURL(for: GeminiConfig.ttsEndpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = GeminiConfig.requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxTranslateError.invalidAPIResponse(service: "Gemini TTS", details: "Invalid HTTP response")
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
            logger.error("Gemini TTS API error \(httpResponse.statusCode): \(errorBody)")
            throw VoxTranslateError.apiError(
                service: "Gemini TTS",
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        return try parseTTSResponse(data)
    }
}

// MARK: - Request Building

private extension GeminiTTSService {
    func buildTTSRequestBody(
        text: String,
        language: LanguageCode,
        dialect: ArabicDialect?
    ) -> [String: Any] {
        var speechText = text

        // For Arabic with a dialect, prepend a style prompt
        if language.id == "ar", let dialect = dialect {
            speechText = dialect.ttsStylePrompt + "\n\nText to speak: " + text
        }

        return [
            "contents": [
                [
                    "parts": [
                        ["text": speechText]
                    ]
                ]
            ],
            "generationConfig": [
                "responseModalities": ["AUDIO"],
                "speechConfig": [
                    "voiceConfig": [
                        "prebuiltVoiceConfig": [
                            "voiceName": voiceForLanguage(language)
                        ]
                    ]
                ]
            ]
        ]
    }

    /// Selects an appropriate voice name based on the target language.
    func voiceForLanguage(_ language: LanguageCode) -> String {
        switch language.id {
        case "ar": return "Orus"
        case "en": return "Kore"
        case "fr": return "Leda"
        case "es": return "Zephyr"
        case "de": return "Puck"
        case "ja": return "Kore"
        case "zh": return "Kore"
        default: return "Kore"
        }
    }
}

// MARK: - Response Parsing

private extension GeminiTTSService {
    func parseTTSResponse(_ data: Data) throws -> AudioData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let inlineData = firstPart["inlineData"] as? [String: Any],
              let base64String = inlineData["data"] as? String,
              let audioBytes = Data(base64Encoded: base64String) else {
            throw VoxTranslateError.invalidAPIResponse(
                service: "Gemini TTS",
                details: "Could not parse audio data from response"
            )
        }

        return AudioData(
            data: audioBytes,
            sampleRate: GeminiConfig.OutputAudio.sampleRate,
            channelCount: GeminiConfig.OutputAudio.channelCount,
            bitsPerSample: GeminiConfig.OutputAudio.bitsPerSample
        )
    }
}

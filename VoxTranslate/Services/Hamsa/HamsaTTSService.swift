// HamsaTTSService.swift
// VoxTranslate
//
// Hamsa text-to-speech implementation — natural Arabic dialect pronunciation.

import Foundation
import os.log

// MARK: - Hamsa TTS Service

/// Arabic dialect text-to-speech using the Hamsa API.
///
/// Purpose-built for natural Arabic pronunciation with dialect and intonation support.
final class HamsaTTSService: SpeechSynthesisProvider, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "HamsaTTS")
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
        logger.info("Synthesizing via Hamsa TTS: '\(text.prefix(50))...'")

        var requestBody: [String: Any] = [
            "text": text,
            "language": language.id,
            "format": "pcm",
            "sample_rate": 24000
        ]

        if let dialect = dialect {
            requestBody["dialect"] = HamsaConfig.hamsaDialectCode(for: dialect)
        }

        var request = URLRequest(url: URL(string: HamsaConfig.ttsEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(HamsaConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = HamsaConfig.requestTimeout
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxTranslateError.invalidAPIResponse(service: "Hamsa TTS", details: "Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            throw VoxTranslateError.apiError(
                service: "Hamsa TTS",
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        // Hamsa returns raw audio data directly
        guard !data.isEmpty else {
            throw VoxTranslateError.invalidAPIResponse(
                service: "Hamsa TTS",
                details: "Empty audio response"
            )
        }

        return AudioData(
            data: data,
            sampleRate: 24000,
            channelCount: 1,
            bitsPerSample: 16
        )
    }
}

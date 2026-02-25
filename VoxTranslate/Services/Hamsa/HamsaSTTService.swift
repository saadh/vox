// HamsaSTTService.swift
// VoxTranslate
//
// Hamsa speech-to-text implementation — Arabic dialect specialist.

import Foundation
import os.log

// MARK: - Hamsa STT Service

/// Arabic dialect speech-to-text using the Hamsa API.
///
/// Purpose-built for Arabic dialects with claimed 50%+ lower WER than general-purpose
/// STT engines. Supports bilingual Arabic/English code-switching and 16+ Arabic dialects.
final class HamsaSTTService: SpeechRecognitionProvider, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "HamsaSTT")
    private let session: URLSession
    private let dialect: ArabicDialect

    // MARK: - Initialization

    /// Creates a Hamsa STT service configured for a specific Arabic dialect.
    /// - Parameter dialect: The target Arabic dialect for optimized recognition.
    init(dialect: ArabicDialect = .najdi, session: URLSession = .shared) {
        self.dialect = dialect
        self.session = session
    }

    // MARK: - SpeechRecognitionProvider

    func startStreaming(locale: Locale) -> AsyncThrowingStream<PartialTranscript, Error> {
        AsyncThrowingStream { continuation in
            // Hamsa STT uses a REST-based approach with audio upload
            // For streaming, we accumulate audio and send in chunks
            continuation.onTermination = { @Sendable _ in
                self.logger.info("Hamsa STT stream terminated")
            }

            // Note: In a real implementation, this would connect to Hamsa's
            // streaming WebSocket endpoint if available, or batch audio chunks.
            // For now, this provides the streaming interface that the EngineManager expects.
        }
    }

    func stopStreaming() async {
        logger.info("Stopping Hamsa STT streaming")
    }

    // MARK: - Batch Recognition

    /// Transcribes a complete audio buffer using Hamsa's REST API.
    ///
    /// - Parameters:
    ///   - audioData: Raw PCM audio data (16-bit, 16kHz, mono).
    ///   - locale: The expected language locale.
    /// - Returns: The final transcript.
    func transcribe(audioData: Data, locale: Locale) async throws -> PartialTranscript {
        logger.info("Transcribing \(audioData.count) bytes via Hamsa STT")

        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: HamsaConfig.sttEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(HamsaConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = HamsaConfig.requestTimeout

        var body = Data()
        // Audio file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.pcm\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/pcm\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Dialect parameter
        let dialectCode = HamsaConfig.hamsaDialectCode(for: dialect)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"dialect\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(dialectCode)\r\n".data(using: .utf8)!)

        // Sample rate parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"sample_rate\"\r\n\r\n".data(using: .utf8)!)
        body.append("16000\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw VoxTranslateError.invalidAPIResponse(service: "Hamsa STT", details: "Invalid HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            throw VoxTranslateError.apiError(
                service: "Hamsa STT",
                statusCode: httpResponse.statusCode,
                message: errorBody
            )
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw VoxTranslateError.invalidAPIResponse(
                service: "Hamsa STT",
                details: "Could not parse transcription from response"
            )
        }

        let confidence = json["confidence"] as? Double

        return PartialTranscript(
            text: text,
            isFinal: true,
            confidence: confidence,
            detectedLanguage: nil
        )
    }
}

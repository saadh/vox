// TranslationResult.swift
// VoxTranslate
//
// Result type returned by the text translation pipeline.

import Foundation

// MARK: - Translation Result

/// The result of a text translation operation.
struct TranslationResult: Sendable {
    /// The original source text that was translated.
    let sourceText: String

    /// The translated text in the target language.
    let translatedText: String

    /// The source language code (may differ from requested if auto-detected).
    let detectedSourceLanguage: LanguageCode?

    /// The target language code.
    let targetLanguage: LanguageCode

    /// The Arabic dialect used, if applicable.
    let dialect: ArabicDialect?

    /// Confidence score from 0.0 to 1.0, if provided by the engine.
    let confidence: Double?

    /// Which engine tier produced this result.
    let engineTier: EngineTier
}

// MARK: - Engine Tier

/// Identifies which translation engine tier produced a result.
enum EngineTier: String, Codable, Sendable {
    case geminiLive = "gemini_live"
    case geminiText = "gemini_text"
    case hamsa = "hamsa"
    case apple = "apple"
    case allam = "allam"

    /// Human-readable display name for the engine tier.
    var displayName: String {
        switch self {
        case .geminiLive: return String(localized: "Gemini Live", comment: "Engine tier name")
        case .geminiText: return String(localized: "Gemini", comment: "Engine tier name")
        case .hamsa: return String(localized: "Hamsa", comment: "Engine tier name")
        case .apple: return String(localized: "Offline", comment: "Engine tier name for Apple on-device")
        case .allam: return String(localized: "ALLaM", comment: "Engine tier name")
        }
    }
}

// MARK: - Audio Data

/// Container for synthesized audio data with format metadata.
struct AudioData: Sendable {
    /// Raw audio bytes.
    let data: Data

    /// Sample rate in Hz (e.g., 24000 for Gemini output, 16000 for input).
    let sampleRate: Double

    /// Number of audio channels (typically 1 for mono).
    let channelCount: Int

    /// Bits per sample (typically 16).
    let bitsPerSample: Int

    /// Duration of the audio in seconds.
    var duration: TimeInterval {
        let bytesPerSample = bitsPerSample / 8
        let totalSamples = data.count / (bytesPerSample * channelCount)
        return Double(totalSamples) / sampleRate
    }
}

// MARK: - Partial Transcript

/// A partial or final speech-to-text transcript from a streaming recognizer.
struct PartialTranscript: Sendable {
    /// The recognized text so far.
    let text: String

    /// Whether this transcript is final (no more updates expected for this segment).
    let isFinal: Bool

    /// Confidence score from 0.0 to 1.0, if available.
    let confidence: Double?

    /// The detected language, if auto-detection is enabled.
    let detectedLanguage: LanguageCode?
}

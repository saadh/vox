// TranslationEvent.swift
// VoxTranslate
//
// Events emitted by the VoiceTranslationProvider during a live translation session.

import Foundation

// MARK: - Translation Event

/// Events emitted by the Gemini Live API during a streaming translation session.
/// These events are interleaved — audio, transcription, and translation can arrive simultaneously.
enum TranslationEvent: Sendable {
    /// A partial transcription of the source speech (updates as more audio is processed).
    case partialTranscription(text: String)

    /// The final transcription of the source speech.
    case finalTranscription(text: String)

    /// A partial translation of the source speech.
    case partialTranslation(text: String)

    /// The final translated text.
    case finalTranslation(text: String)

    /// A chunk of translated audio data ready for playback.
    case audioChunk(data: Data)

    /// All audio for the current response has been sent.
    case audioComplete

    /// The detected language of the source speech.
    case languageDetected(language: LanguageCode, dialect: ArabicDialect?)

    /// The session has been established successfully.
    case sessionStarted

    /// The model has finished processing the current input turn.
    case turnComplete

    /// An error occurred during the session.
    case error(VoxTranslateError)
}

// MARK: - VoxTranslate Error

/// Typed error enum for all VoxTranslate operations.
enum VoxTranslateError: Error, Sendable {
    // MARK: Network
    case networkUnavailable
    case connectionTimeout
    case webSocketDisconnected(reason: String)
    case webSocketError(underlying: String)

    // MARK: API
    case apiKeyMissing(service: String)
    case apiRateLimited(retryAfter: TimeInterval?)
    case apiError(service: String, statusCode: Int, message: String)
    case invalidAPIResponse(service: String, details: String)

    // MARK: Audio
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case audioSessionSetupFailed(underlying: String)
    case audioEngineFailed(underlying: String)
    case noSpeechDetected

    // MARK: Translation
    case translationFailed(underlying: String)
    case unsupportedLanguagePair(source: String, target: String)
    case dialectNotSupported(dialect: String)

    // MARK: General
    case tierUnavailable(tier: String)
    case unknown(underlying: String)
}

// MARK: - LocalizedError Conformance

extension VoxTranslateError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "No internet connection. Switching to offline mode.", comment: "Network error")
        case .connectionTimeout:
            return String(localized: "Connection timed out. Please try again.", comment: "Timeout error")
        case .webSocketDisconnected(let reason):
            return String(localized: "Live connection lost: \(reason)", comment: "WebSocket disconnect")
        case .webSocketError(let underlying):
            return String(localized: "Connection error: \(underlying)", comment: "WebSocket error")
        case .apiKeyMissing(let service):
            return String(localized: "API key not configured for \(service).", comment: "API key error")
        case .apiRateLimited:
            return String(localized: "Too many requests. Please wait a moment.", comment: "Rate limit error")
        case .apiError(let service, let statusCode, let message):
            return String(localized: "\(service) error (\(statusCode)): \(message)", comment: "API error")
        case .invalidAPIResponse(let service, let details):
            return String(localized: "Invalid response from \(service): \(details)", comment: "Invalid response")
        case .microphonePermissionDenied:
            return String(localized: "Microphone access is required to translate speech.", comment: "Mic permission")
        case .speechRecognitionPermissionDenied:
            return String(localized: "Speech recognition permission is required for offline mode.", comment: "Speech permission")
        case .audioSessionSetupFailed(let underlying):
            return String(localized: "Audio setup failed: \(underlying)", comment: "Audio session error")
        case .audioEngineFailed(let underlying):
            return String(localized: "Audio engine error: \(underlying)", comment: "Audio engine error")
        case .noSpeechDetected:
            return String(localized: "I didn't catch that — try again.", comment: "No speech detected")
        case .translationFailed(let underlying):
            return String(localized: "Translation failed: \(underlying)", comment: "Translation error")
        case .unsupportedLanguagePair(let source, let target):
            return String(localized: "Translation from \(source) to \(target) is not supported.", comment: "Unsupported pair")
        case .dialectNotSupported(let dialect):
            return String(localized: "The \(dialect) dialect is not supported by the current engine.", comment: "Unsupported dialect")
        case .tierUnavailable(let tier):
            return String(localized: "\(tier) is currently unavailable.", comment: "Tier unavailable")
        case .unknown(let underlying):
            return String(localized: "An unexpected error occurred: \(underlying)", comment: "Unknown error")
        }
    }
}

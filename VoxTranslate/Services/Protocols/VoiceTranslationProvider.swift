// VoiceTranslationProvider.swift
// VoxTranslate
//
// Protocol for end-to-end voice-in to voice-out translation (Gemini Live API).

import Foundation

// MARK: - Voice Translation Provider

/// Handles the full end-to-end voice-in to voice-out pipeline.
///
/// This protocol abstracts the Gemini Live API's streaming bidirectional audio capability.
/// Audio is streamed in from the microphone, and translated audio + text events are
/// streamed back simultaneously. This eliminates the multi-hop latency of chained
/// STT -> Translation -> TTS pipelines.
protocol VoiceTranslationProvider: Sendable {
    /// Starts a new live translation session.
    ///
    /// Establishes a WebSocket connection and configures the session with the appropriate
    /// source/target languages and dialect preferences.
    ///
    /// - Parameters:
    ///   - sourceLanguage: The expected spoken language. Use `LanguageCode.autoDetect` for auto-detection.
    ///   - targetLanguage: The language to translate into.
    ///   - dialect: The target Arabic dialect, if translating to Arabic.
    /// - Throws: `VoxTranslateError` if the connection cannot be established.
    func startSession(
        sourceLanguage: LanguageCode,
        targetLanguage: LanguageCode,
        dialect: ArabicDialect?
    ) async throws

    /// Streams a chunk of raw audio data to the live translation session.
    ///
    /// Audio should be PCM 16-bit signed integer, 16kHz mono. Chunks should be approximately
    /// 100ms in duration (~3200 bytes per chunk).
    ///
    /// - Parameter audioChunk: Raw PCM audio data from the microphone.
    /// - Throws: `VoxTranslateError` if the session is not active or the send fails.
    func streamAudio(_ audioChunk: Data) async throws

    /// Returns an async stream of translation events from the live session.
    ///
    /// Events include partial transcription, final transcription, partial translation,
    /// final translation, audio chunks for playback, and session lifecycle events.
    ///
    /// - Returns: An `AsyncThrowingStream` of `TranslationEvent`s.
    func receiveResults() -> AsyncThrowingStream<TranslationEvent, Error>

    /// Signals the end of the user's speech input for the current turn.
    ///
    /// This tells the model that the user has finished speaking, allowing it to
    /// finalize the translation. The session remains open for the next turn.
    func endAudioInput() async throws

    /// Ends the live translation session and closes the WebSocket connection.
    ///
    /// Any pending results may still be delivered through the `receiveResults()` stream
    /// before it terminates.
    func endSession() async
}

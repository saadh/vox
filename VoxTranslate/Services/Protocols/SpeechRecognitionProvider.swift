// SpeechRecognitionProvider.swift
// VoxTranslate
//
// Protocol for speech-to-text providers that stream partial transcripts.

import Foundation

// MARK: - Speech Recognition Provider

/// Handles the voice-in to text pipeline via streaming speech recognition.
///
/// Conforming types provide real-time partial transcription from microphone audio.
/// The streaming nature allows live display of partial results as the user speaks.
protocol SpeechRecognitionProvider: Sendable {
    /// Starts streaming speech recognition for the given locale.
    ///
    /// - Parameter locale: The expected spoken language locale.
    /// - Returns: An async stream of partial transcripts. Partial results have `isFinal == false`;
    ///   the final recognized text has `isFinal == true`.
    /// - Note: Only one streaming session can be active at a time. Starting a new stream
    ///   implicitly cancels any existing session.
    func startStreaming(locale: Locale) -> AsyncThrowingStream<PartialTranscript, Error>

    /// Stops the current streaming recognition session.
    ///
    /// Any pending partial results may be finalized before the stream terminates.
    func stopStreaming() async
}

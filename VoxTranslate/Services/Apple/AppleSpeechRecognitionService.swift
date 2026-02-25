// AppleSpeechRecognitionService.swift
// VoxTranslate
//
// On-device speech recognition fallback using Apple's Speech framework.

import Foundation
import Speech
import os.log

// MARK: - Apple Speech Recognition Service

/// On-device speech recognition using `SFSpeechRecognizer` as the Tier 3 offline fallback.
///
/// Limitations: MSA only for Arabic (no Saudi dialect awareness), limited language support.
final class AppleSpeechRecognitionService: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "AppleSTT")
    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: AsyncThrowingStream<PartialTranscript, Error>.Continuation?
}

// MARK: - SpeechRecognitionProvider

extension AppleSpeechRecognitionService: SpeechRecognitionProvider {
    func startStreaming(locale: Locale) -> AsyncThrowingStream<PartialTranscript, Error> {
        logger.info("Starting Apple on-device STT for locale: \(locale.identifier)")

        return AsyncThrowingStream { continuation in
            self.continuation = continuation

            continuation.onTermination = { @Sendable _ in
                self.logger.info("Apple STT stream terminated")
                self.cleanUp()
            }

            guard let recognizer = SFSpeechRecognizer(locale: locale) else {
                continuation.finish(throwing: VoxTranslateError.translationFailed(
                    underlying: "Speech recognizer not available for locale \(locale.identifier)"
                ))
                return
            }

            guard recognizer.isAvailable else {
                continuation.finish(throwing: VoxTranslateError.translationFailed(
                    underlying: "Speech recognizer is not available"
                ))
                return
            }

            self.recognizer = recognizer

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true

            if #available(iOS 17.0, *) {
                request.addsPunctuation = true
            }

            self.recognitionRequest = request

            self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result = result {
                    let transcript = PartialTranscript(
                        text: result.bestTranscription.formattedString,
                        isFinal: result.isFinal,
                        confidence: result.bestTranscription.segments.last.map {
                            Double($0.confidence)
                        },
                        detectedLanguage: nil
                    )
                    continuation.yield(transcript)

                    if result.isFinal {
                        continuation.finish()
                    }
                }

                if let error = error {
                    self.logger.error("Apple STT error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func stopStreaming() async {
        logger.info("Stopping Apple on-device STT")
        recognitionRequest?.endAudio()
        recognitionTask?.finish()
        cleanUp()
    }
}

// MARK: - Audio Buffer Input

extension AppleSpeechRecognitionService {
    /// Appends an audio buffer from AVAudioEngine to the recognition request.
    ///
    /// - Parameter buffer: The audio buffer from the microphone tap.
    func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
}

// MARK: - Permissions

extension AppleSpeechRecognitionService {
    /// Requests speech recognition authorization from the user.
    /// - Returns: `true` if authorized, `false` otherwise.
    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// The current authorization status for speech recognition.
    static var authorizationStatus: SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }
}

// MARK: - Private

private extension AppleSpeechRecognitionService {
    func cleanUp() {
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil
        continuation = nil
    }
}

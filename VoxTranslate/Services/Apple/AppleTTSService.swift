// AppleTTSService.swift
// VoxTranslate
//
// On-device text-to-speech fallback using AVSpeechSynthesizer.

import AVFoundation
import Foundation
import os.log

// MARK: - Apple TTS Service

/// On-device text-to-speech using `AVSpeechSynthesizer` as the Tier 3 offline fallback.
///
/// Limitations: MSA pronunciation only for Arabic, robotic quality compared to
/// Gemini or Hamsa TTS.
final class AppleTTSService: NSObject, @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "AppleTTS")
    private let synthesizer = AVSpeechSynthesizer()
    private var speechContinuation: CheckedContinuation<Void, Error>?
}

// MARK: - SpeechSynthesisProvider

extension AppleTTSService: SpeechSynthesisProvider {
    func synthesize(
        _ text: String,
        language: LanguageCode,
        dialect: ArabicDialect?
    ) async throws -> AudioData {
        logger.info("Synthesizing via Apple TTS for language: \(language.id)")

        // Apple TTS plays directly through the audio session rather than returning raw audio data.
        // We use the write-to-buffer approach where available, but fall back to direct playback.
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        // Select the best available voice for the language
        if let voice = bestVoice(for: language, dialect: dialect) {
            utterance.voice = voice
        } else {
            logger.warning("No voice found for \(language.id), using default")
        }

        // Use the buffer-based approach to capture audio data
        var audioBuffers: [AVAudioBuffer] = []
        synthesizer.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.speechContinuation = continuation

            synthesizer.write(utterance) { buffer in
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                    // Empty buffer signals completion
                    let combinedData = self.combineBuffers(audioBuffers)
                    let audioData = AudioData(
                        data: combinedData,
                        sampleRate: 22050, // AVSpeechSynthesizer default
                        channelCount: 1,
                        bitsPerSample: 16
                    )
                    self.speechContinuation = nil
                    continuation.resume(returning: audioData)
                    return
                }
                audioBuffers.append(pcmBuffer)
            }
        }
    }
}

// MARK: - Voice Selection

private extension AppleTTSService {
    func bestVoice(for language: LanguageCode, dialect: ArabicDialect?) -> AVSpeechSynthesisVoice? {
        let languageCode: String
        switch language.id {
        case "ar":
            // Use Saudi Arabic locale for Saudi dialects
            if let dialect = dialect, dialect.isSaudi {
                languageCode = "ar-SA"
            } else {
                languageCode = "ar-001" // Generic Arabic
            }
        default:
            languageCode = language.id
        }

        // Prefer enhanced/premium quality voices
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(languageCode.components(separatedBy: "-").first ?? languageCode) }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        return voices.first ?? AVSpeechSynthesisVoice(language: languageCode)
    }

    func combineBuffers(_ buffers: [AVAudioBuffer]) -> Data {
        var combined = Data()
        for buffer in buffers {
            guard let pcmBuffer = buffer as? AVAudioPCMBuffer,
                  let channelData = pcmBuffer.int16ChannelData else { continue }

            let frameCount = Int(pcmBuffer.frameLength)
            let data = Data(bytes: channelData[0], count: frameCount * 2)
            combined.append(data)
        }
        return combined
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AppleTTSService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        logger.info("Apple TTS finished speaking")
    }

    func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        logger.info("Apple TTS cancelled")
        speechContinuation?.resume(throwing: VoxTranslateError.translationFailed(underlying: "TTS cancelled"))
        speechContinuation = nil
    }
}

// MARK: - Direct Playback

extension AppleTTSService {
    /// Speaks text directly through the device speaker without returning audio data.
    /// Useful for quick phrase playback in the phrasebook.
    func speakDirectly(
        _ text: String,
        language: LanguageCode,
        dialect: ArabicDialect?,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate
    ) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.volume = 1.0

        if let voice = bestVoice(for: language, dialect: dialect) {
            utterance.voice = voice
        }

        synthesizer.speak(utterance)
    }

    /// Stops any ongoing speech synthesis.
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

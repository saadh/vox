// ConversationEntry.swift
// VoxTranslate
//
// Model for a single translation exchange in the conversation history.

import Foundation

// MARK: - Conversation Entry

/// A single translation exchange in the conversation history.
struct ConversationEntry: Identifiable, Sendable {
    /// Unique identifier for this entry.
    let id: UUID

    /// Timestamp when the translation was performed.
    let timestamp: Date

    /// The original spoken text.
    let sourceText: String

    /// The source language.
    let sourceLanguage: LanguageCode

    /// The translated text.
    let translatedText: String

    /// The target language.
    let targetLanguage: LanguageCode

    /// The Arabic dialect used, if applicable.
    let dialect: ArabicDialect?

    /// Which engine tier produced this translation.
    let engineTier: EngineTier

    /// Cached audio data for replay, if available.
    var cachedAudio: AudioData?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sourceText: String,
        sourceLanguage: LanguageCode,
        translatedText: String,
        targetLanguage: LanguageCode,
        dialect: ArabicDialect? = nil,
        engineTier: EngineTier,
        cachedAudio: AudioData? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sourceText = sourceText
        self.sourceLanguage = sourceLanguage
        self.translatedText = translatedText
        self.targetLanguage = targetLanguage
        self.dialect = dialect
        self.engineTier = engineTier
        self.cachedAudio = cachedAudio
    }
}

// MARK: - Formatting

extension ConversationEntry {
    /// Formatted timestamp for display (e.g., "2:34 PM").
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }

    /// Whether the source text should render right-to-left.
    var isSourceRTL: Bool {
        sourceLanguage.isRTL
    }

    /// Whether the translated text should render right-to-left.
    var isTargetRTL: Bool {
        targetLanguage.isRTL
    }

    /// Shareable text representation combining source and translated text.
    var shareableText: String {
        "\(sourceLanguage.flagEmoji) \(sourceText)\n\(targetLanguage.flagEmoji) \(translatedText)"
    }
}

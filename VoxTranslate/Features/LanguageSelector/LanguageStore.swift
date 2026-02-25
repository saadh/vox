// LanguageStore.swift
// VoxTranslate
//
// Persistent storage for language preferences and recently used languages.

import Foundation
import SwiftUI

// MARK: - Language Store

/// Manages persisted language preferences including the selected language pair,
/// Arabic dialect, and recently used languages.
@Observable
final class LanguageStore {
    // MARK: - Persisted Properties

    /// The source language code (persisted via AppStorage).
    var sourceLanguageCode: String {
        didSet { UserDefaults.standard.set(sourceLanguageCode, forKey: "sourceLanguageCode") }
    }

    /// The target language code (persisted via AppStorage).
    var targetLanguageCode: String {
        didSet { UserDefaults.standard.set(targetLanguageCode, forKey: "targetLanguageCode") }
    }

    /// The selected Arabic dialect raw value (persisted via AppStorage).
    var selectedDialectRaw: String {
        didSet { UserDefaults.standard.set(selectedDialectRaw, forKey: "selectedDialect") }
    }

    /// Recently used language codes (persisted via AppStorage).
    var recentLanguageCodes: [String] {
        didSet { UserDefaults.standard.set(recentLanguageCodes, forKey: "recentLanguages") }
    }

    // MARK: - Computed Properties

    /// The current source language.
    var sourceLanguage: LanguageCode {
        LanguageCode.allWithAutoDetect.first { $0.id == sourceLanguageCode } ?? .english
    }

    /// The current target language.
    var targetLanguage: LanguageCode {
        LanguageCode.allWithAutoDetect.first { $0.id == targetLanguageCode } ?? .arabic
    }

    /// The selected Arabic dialect.
    var selectedDialect: ArabicDialect {
        ArabicDialect(rawValue: selectedDialectRaw) ?? .najdi
    }

    /// Whether the target language is Arabic.
    var isTargetArabic: Bool {
        targetLanguageCode == "ar"
    }

    /// Whether the source language is Arabic.
    var isSourceArabic: Bool {
        sourceLanguageCode == "ar"
    }

    /// Recently used languages (max 5, most recent first).
    var recentLanguages: [LanguageCode] {
        recentLanguageCodes.compactMap { code in
            LanguageCode.allSupported.first { $0.id == code }
        }
    }

    // MARK: - Initialization

    init() {
        self.sourceLanguageCode = UserDefaults.standard.string(forKey: "sourceLanguageCode") ?? "en"
        self.targetLanguageCode = UserDefaults.standard.string(forKey: "targetLanguageCode") ?? "ar"
        self.selectedDialectRaw = UserDefaults.standard.string(forKey: "selectedDialect") ?? ArabicDialect.najdi.rawValue
        self.recentLanguageCodes = UserDefaults.standard.stringArray(forKey: "recentLanguages") ?? ["en", "ar"]
    }

    // MARK: - Actions

    /// Swaps the source and target languages.
    func swapLanguages() {
        let temp = sourceLanguageCode
        sourceLanguageCode = targetLanguageCode
        targetLanguageCode = temp
    }

    /// Sets the source language and adds it to recent history.
    func setSourceLanguage(_ language: LanguageCode) {
        sourceLanguageCode = language.id
        addToRecent(language)
    }

    /// Sets the target language and adds it to recent history.
    func setTargetLanguage(_ language: LanguageCode) {
        targetLanguageCode = language.id
        addToRecent(language)
    }

    /// Sets the Arabic dialect.
    func setDialect(_ dialect: ArabicDialect) {
        selectedDialectRaw = dialect.rawValue
    }

    /// Adds a language to the recent history.
    private func addToRecent(_ language: LanguageCode) {
        guard language.id != "auto" else { return }
        var recent = recentLanguageCodes.filter { $0 != language.id }
        recent.insert(language.id, at: 0)
        recentLanguageCodes = Array(recent.prefix(5))
    }
}

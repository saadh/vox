// Language.swift
// VoxTranslate
//
// Language model with all supported languages, display names, and locale mappings.

import Foundation

// MARK: - Language Code

/// ISO 639-1 language code wrapper with display metadata.
struct LanguageCode: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let englishName: String
    let nativeName: String
    let flagEmoji: String
    let isRTL: Bool
    let locale: Locale

    init(
        code: String,
        englishName: String,
        nativeName: String,
        flagEmoji: String,
        isRTL: Bool = false
    ) {
        self.id = code
        self.englishName = englishName
        self.nativeName = nativeName
        self.flagEmoji = flagEmoji
        self.isRTL = isRTL
        self.locale = Locale(identifier: code)
    }
}

// MARK: - Supported Languages

extension LanguageCode {
    /// Auto-detect placeholder — the model determines the spoken language automatically.
    static let autoDetect = LanguageCode(
        code: "auto",
        englishName: "Auto-Detect",
        nativeName: "Auto-Detect",
        flagEmoji: "🌐"
    )

    static let arabic = LanguageCode(
        code: "ar",
        englishName: "Arabic",
        nativeName: "العربية",
        flagEmoji: "🇸🇦",
        isRTL: true
    )

    static let english = LanguageCode(
        code: "en",
        englishName: "English",
        nativeName: "English",
        flagEmoji: "🇺🇸"
    )

    static let french = LanguageCode(
        code: "fr",
        englishName: "French",
        nativeName: "Français",
        flagEmoji: "🇫🇷"
    )

    static let spanish = LanguageCode(
        code: "es",
        englishName: "Spanish",
        nativeName: "Español",
        flagEmoji: "🇪🇸"
    )

    static let german = LanguageCode(
        code: "de",
        englishName: "German",
        nativeName: "Deutsch",
        flagEmoji: "🇩🇪"
    )

    static let turkish = LanguageCode(
        code: "tr",
        englishName: "Turkish",
        nativeName: "Türkçe",
        flagEmoji: "🇹🇷"
    )

    static let urdu = LanguageCode(
        code: "ur",
        englishName: "Urdu",
        nativeName: "اردو",
        flagEmoji: "🇵🇰",
        isRTL: true
    )

    static let hindi = LanguageCode(
        code: "hi",
        englishName: "Hindi",
        nativeName: "हिन्दी",
        flagEmoji: "🇮🇳"
    )

    static let chinese = LanguageCode(
        code: "zh",
        englishName: "Chinese",
        nativeName: "中文",
        flagEmoji: "🇨🇳"
    )

    static let japanese = LanguageCode(
        code: "ja",
        englishName: "Japanese",
        nativeName: "日本語",
        flagEmoji: "🇯🇵"
    )

    static let korean = LanguageCode(
        code: "ko",
        englishName: "Korean",
        nativeName: "한국어",
        flagEmoji: "🇰🇷"
    )

    static let russian = LanguageCode(
        code: "ru",
        englishName: "Russian",
        nativeName: "Русский",
        flagEmoji: "🇷🇺"
    )

    static let portuguese = LanguageCode(
        code: "pt",
        englishName: "Portuguese",
        nativeName: "Português",
        flagEmoji: "🇧🇷"
    )

    static let italian = LanguageCode(
        code: "it",
        englishName: "Italian",
        nativeName: "Italiano",
        flagEmoji: "🇮🇹"
    )

    static let indonesian = LanguageCode(
        code: "id",
        englishName: "Indonesian",
        nativeName: "Bahasa Indonesia",
        flagEmoji: "🇮🇩"
    )

    static let malay = LanguageCode(
        code: "ms",
        englishName: "Malay",
        nativeName: "Bahasa Melayu",
        flagEmoji: "🇲🇾"
    )

    static let thai = LanguageCode(
        code: "th",
        englishName: "Thai",
        nativeName: "ไทย",
        flagEmoji: "🇹🇭"
    )

    static let filipino = LanguageCode(
        code: "tl",
        englishName: "Filipino",
        nativeName: "Filipino",
        flagEmoji: "🇵🇭"
    )

    static let bengali = LanguageCode(
        code: "bn",
        englishName: "Bengali",
        nativeName: "বাংলা",
        flagEmoji: "🇧🇩"
    )

    // MARK: - All Supported Languages

    /// All selectable languages, sorted alphabetically by English name.
    static let allSupported: [LanguageCode] = [
        .arabic, .bengali, .chinese, .english, .filipino, .french,
        .german, .hindi, .indonesian, .italian, .japanese, .korean,
        .malay, .portuguese, .russian, .spanish, .thai, .turkish, .urdu
    ].sorted { $0.englishName < $1.englishName }

    /// Languages including the auto-detect option.
    static let allWithAutoDetect: [LanguageCode] = [.autoDetect] + allSupported
}

// MARK: - Language Pair

/// Represents a source-target language pair for translation.
struct LanguagePair: Codable, Hashable, Sendable {
    let source: LanguageCode
    let target: LanguageCode

    /// Returns a new pair with source and target swapped.
    var swapped: LanguagePair {
        LanguagePair(source: target, target: source)
    }
}

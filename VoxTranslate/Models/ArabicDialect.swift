// ArabicDialect.swift
// VoxTranslate
//
// Arabic dialect enum with display names, flag emojis, and Gemini prompt fragments.

import Foundation

// MARK: - Arabic Dialect

/// Represents a specific Arabic dialect for translation targeting.
enum ArabicDialect: String, Codable, CaseIterable, Identifiable, Sendable {
    case najdi = "najdi"
    case hijazi = "hijazi"
    case gulf = "gulf"
    case egyptian = "egyptian"
    case levantine = "levantine"
    case moroccan = "moroccan"
    case msa = "msa"

    var id: String { rawValue }
}

// MARK: - Display Metadata

extension ArabicDialect {
    /// Flag emoji for this dialect's primary region.
    var flagEmoji: String {
        switch self {
        case .najdi, .hijazi: return "\u{1F1F8}\u{1F1E6}"
        case .gulf: return "\u{1F1F8}\u{1F1E6}"
        case .egyptian: return "\u{1F1EA}\u{1F1EC}"
        case .levantine: return "\u{1F1F1}\u{1F1E7}"
        case .moroccan: return "\u{1F1F2}\u{1F1E6}"
        case .msa: return "\u{1F4D6}"
        }
    }

    /// English display name.
    var englishName: String {
        switch self {
        case .najdi: return "Saudi — Najdi"
        case .hijazi: return "Saudi — Hijazi"
        case .gulf: return "Gulf"
        case .egyptian: return "Egyptian"
        case .levantine: return "Levantine"
        case .moroccan: return "Moroccan"
        case .msa: return "Modern Standard Arabic"
        }
    }

    /// Arabic display name.
    var arabicName: String {
        switch self {
        case .najdi: return "الرياض، نجد"
        case .hijazi: return "جدة، مكة"
        case .gulf: return "الخليج"
        case .egyptian: return "مصري"
        case .levantine: return "شامي"
        case .moroccan: return "مغربي"
        case .msa: return "فصحى"
        }
    }

    /// Short label for the dialect badge shown in the translation panel.
    var badgeLabel: String {
        switch self {
        case .najdi: return "نجدي"
        case .hijazi: return "حجازي"
        case .gulf: return "خليجي"
        case .egyptian: return "مصري"
        case .levantine: return "شامي"
        case .moroccan: return "مغربي"
        case .msa: return "فصحى"
        }
    }

    /// Whether this is a Saudi Arabian dialect.
    var isSaudi: Bool {
        switch self {
        case .najdi, .hijazi, .gulf: return true
        default: return false
        }
    }

    /// The default dialect for new users (Najdi — most common for Riyadh visitors).
    static let `default`: ArabicDialect = .najdi
}

// MARK: - Gemini Prompt Generation

extension ArabicDialect {
    /// Generates the dialect-specific portion of the Gemini system prompt.
    var geminiPromptFragment: String {
        switch self {
        case .najdi:
            return """
            When translating TO Arabic, ALWAYS use Saudi Najdi dialect (لهجة نجدية سعودية), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing that a local in Riyadh would use.
              - Use "وش" not "ماذا" for "what"
              - Use "أبي/أبغى" not "أريد" for "I want"
              - Use "وين" not "أين" for "where"
              - Use "حيل/مرة" not "كثيراً" for "very/a lot"
              - Use "يالله" not "هيا" for "let's go"
              - Use "إيه" not "نعم" for "yes"
              - Use "كيف حالك" with Najdi pronunciation cues, not formal MSA
            """
        case .hijazi:
            return """
            When translating TO Arabic, ALWAYS use Saudi Hijazi dialect (لهجة حجازية), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing that a local in Jeddah or Mecca would use.
              - Use "إيش" not "ماذا" for "what"
              - Use "أبغى/أبا" not "أريد" for "I want"
              - Use "فين" not "أين" for "where"
              - Use "كتير/مرة" not "كثيراً" for "very/a lot"
              - Use "يلا" not "هيا" for "let's go"
              - Use "أيوه" not "نعم" for "yes"
            """
        case .gulf:
            return """
            When translating TO Arabic, ALWAYS use Gulf Arabic dialect (لهجة خليجية), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing common across the Gulf region (Saudi Eastern Province, UAE, Kuwait, Qatar, Bahrain).
              - Use "شنو" not "ماذا" for "what"
              - Use "أبي" not "أريد" for "I want"
              - Use "وين" not "أين" for "where"
              - Use "واجد" not "كثيراً" for "very/a lot"
              - Use "يالله" not "هيا" for "let's go"
            """
        case .egyptian:
            return """
            When translating TO Arabic, ALWAYS use Egyptian Arabic dialect (لهجة مصرية), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing that a local in Cairo would use.
              - Use "إيه" not "ماذا" for "what"
              - Use "عايز/عاوز" not "أريد" for "I want"
              - Use "فين" not "أين" for "where"
              - Use "أوي/قوي" not "كثيراً" for "very/a lot"
              - Use "يلا" not "هيا" for "let's go"
            """
        case .levantine:
            return """
            When translating TO Arabic, ALWAYS use Levantine Arabic dialect (لهجة شامية), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing common in Lebanon, Syria, Jordan, and Palestine.
              - Use "شو" not "ماذا" for "what"
              - Use "بدي" not "أريد" for "I want"
              - Use "وين" not "أين" for "where"
              - Use "كتير" not "كثيراً" for "very/a lot"
              - Use "يلا" not "هيا" for "let's go"
            """
        case .moroccan:
            return """
            When translating TO Arabic, ALWAYS use Moroccan Arabic dialect (لهجة مغربية / الدارجة), NOT Modern Standard Arabic (فصحى). Use natural conversational phrasing that a local in Casablanca or Rabat would use.
              - Use "أشنو/شنو" not "ماذا" for "what"
              - Use "بغيت" not "أريد" for "I want"
              - Use "فين" not "أين" for "where"
              - Use "بزاف" not "كثيراً" for "very/a lot"
              - Use "يالاه" not "هيا" for "let's go"
            """
        case .msa:
            return """
            When translating TO Arabic, use Modern Standard Arabic (الفصحى). Use clear, formal Arabic suitable for educated readers across the Arab world.
            """
        }
    }

    /// Generates the complete Gemini system prompt for voice translation.
    func geminiSystemPrompt(targetLanguage: String) -> String {
        return """
        You are a real-time voice translator. Your ONLY job is to translate speech.

        RULES:
        1. Listen to the incoming speech and translate it to \(targetLanguage).
        2. \(geminiPromptFragment)
        3. When translating FROM Arabic, recognize dialect vocabulary and pronunciation patterns. Do not be confused by dialectal forms.
        4. Do NOT add any commentary, notes, or explanations. Output ONLY the translation.
        5. Keep translations concise and natural for spoken conversation.
        6. If the speaker code-switches between Arabic and English, handle it naturally.
        """
    }

    /// Generates a TTS style prompt for natural dialect pronunciation.
    var ttsStylePrompt: String {
        switch self {
        case .najdi:
            return "Speak in a natural Saudi Najdi Arabic voice. Use conversational Gulf dialect pronunciation typical of Riyadh. Pace: natural, not rushed."
        case .hijazi:
            return "Speak in a natural Saudi Hijazi Arabic voice. Use conversational dialect pronunciation typical of Jeddah. Pace: natural, not rushed."
        case .gulf:
            return "Speak in a natural Gulf Arabic voice. Use conversational pronunciation common in the Arabian Gulf region. Pace: natural, not rushed."
        case .egyptian:
            return "Speak in a natural Egyptian Arabic voice. Use conversational Cairo dialect pronunciation. Pace: natural, not rushed."
        case .levantine:
            return "Speak in a natural Levantine Arabic voice. Use conversational dialect pronunciation. Pace: natural, not rushed."
        case .moroccan:
            return "Speak in a natural Moroccan Arabic voice. Use conversational Darija pronunciation. Pace: natural, not rushed."
        case .msa:
            return "Speak in a clear Modern Standard Arabic voice. Use formal pronunciation suitable for news broadcasting. Pace: moderate and clear."
        }
    }
}

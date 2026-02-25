// PhraseCategory.swift
// VoxTranslate
//
// Data model for the Saudi travel phrasebook.

import Foundation

// MARK: - Phrase Category

/// A category of common phrases for the Saudi travel phrasebook.
struct PhraseCategory: Identifiable, Codable, Sendable {
    let id: String
    let nameEn: String
    let nameAr: String
    let icon: String
    let phrases: [Phrase]
}

// MARK: - Phrase

/// A single phrase with English text and Saudi Arabic translation.
struct Phrase: Identifiable, Codable, Sendable {
    let id: String
    let english: String
    let arabic: String
    let transliteration: String

    init(id: String = UUID().uuidString, english: String, arabic: String, transliteration: String = "") {
        self.id = id
        self.english = english
        self.arabic = arabic
        self.transliteration = transliteration
    }
}

// MARK: - Phrasebook Data

/// Pre-loaded Saudi travel phrasebook data.
enum PhrasebookData {
    /// Loads phrase categories from the bundled Phrasebook.json resource.
    static func loadFromBundle() -> [PhraseCategory] {
        guard let url = Bundle.main.url(forResource: "Phrasebook", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let categories = try? JSONDecoder().decode([PhraseCategory].self, from: data) else {
            // Fallback to hardcoded data if JSON fails to load
            return defaultCategories
        }
        return categories
    }

    /// Default hardcoded phrasebook data (fallback if JSON not bundled).
    static let defaultCategories: [PhraseCategory] = [
        PhraseCategory(
            id: "greetings",
            nameEn: "Greetings",
            nameAr: "تحيات",
            icon: "hand.wave.fill",
            phrases: [
                Phrase(english: "Peace be upon you", arabic: "السلام عليكم", transliteration: "as-salaam alaykum"),
                Phrase(english: "Hello", arabic: "هلا", transliteration: "hala"),
                Phrase(english: "Good morning", arabic: "صباح الخير", transliteration: "sabah al-khayr"),
                Phrase(english: "Good evening", arabic: "مساء الخير", transliteration: "masa al-khayr"),
                Phrase(english: "How are you?", arabic: "كيف حالك؟", transliteration: "kayf halak?"),
                Phrase(english: "Thank you", arabic: "يعطيك العافية", transliteration: "yaateek al-aafiya"),
                Phrase(english: "Goodbye", arabic: "مع السلامة", transliteration: "ma'a as-salama")
            ]
        ),
        PhraseCategory(
            id: "directions",
            nameEn: "Directions",
            nameAr: "اتجاهات",
            icon: "location.fill",
            phrases: [
                Phrase(english: "Where is...?", arabic: "وين...؟", transliteration: "wayn...?"),
                Phrase(english: "Where is the bathroom?", arabic: "وين دورة المياه؟", transliteration: "wayn dawrat al-miyah?"),
                Phrase(english: "Where is the nearest restaurant?", arabic: "وين أقرب مطعم؟", transliteration: "wayn aqrab mat'am?"),
                Phrase(english: "How do I get to...?", arabic: "كيف أوصل لـ...؟", transliteration: "kayf awsal la...?"),
                Phrase(english: "Is it far?", arabic: "بعيد؟", transliteration: "ba'eed?"),
                Phrase(english: "Left", arabic: "يسار", transliteration: "yasar"),
                Phrase(english: "Right", arabic: "يمين", transliteration: "yameen"),
                Phrase(english: "Straight ahead", arabic: "على طول", transliteration: "ala tool")
            ]
        ),
        PhraseCategory(
            id: "food",
            nameEn: "Food & Dining",
            nameAr: "أكل ومطاعم",
            icon: "fork.knife",
            phrases: [
                Phrase(english: "I'm hungry", arabic: "أنا جوعان", transliteration: "ana jo'aan"),
                Phrase(english: "The bill please", arabic: "الحساب لو سمحت", transliteration: "al-hisab law samaht"),
                Phrase(english: "This is delicious", arabic: "هذا لذيذ", transliteration: "hatha latheeth"),
                Phrase(english: "Water please", arabic: "ماء لو سمحت", transliteration: "maa law samaht"),
                Phrase(english: "Coffee", arabic: "قهوة", transliteration: "qahwa"),
                Phrase(english: "Tea", arabic: "شاي", transliteration: "shay")
            ]
        ),
        PhraseCategory(
            id: "shopping",
            nameEn: "Shopping",
            nameAr: "تسوق",
            icon: "bag.fill",
            phrases: [
                Phrase(english: "How much is this?", arabic: "بكم هذا؟", transliteration: "bikam hatha?"),
                Phrase(english: "Too expensive", arabic: "غالي مرة", transliteration: "ghali marra"),
                Phrase(english: "Can you give a discount?", arabic: "تقدر تنزل شوي؟", transliteration: "tiqdar tinazzil shway?"),
                Phrase(english: "I want this", arabic: "أبغى هذا", transliteration: "abgha hatha"),
                Phrase(english: "I'm just looking", arabic: "بس أتفرج", transliteration: "bas atfarraj")
            ]
        ),
        PhraseCategory(
            id: "emergency",
            nameEn: "Emergency",
            nameAr: "طوارئ",
            icon: "exclamationmark.triangle.fill",
            phrases: [
                Phrase(english: "Help!", arabic: "ساعدوني!", transliteration: "sa'adooni!"),
                Phrase(english: "I need a doctor", arabic: "أحتاج دكتور", transliteration: "ahtaj doktoor"),
                Phrase(english: "Call the police", arabic: "اتصل بالشرطة", transliteration: "ittisal bish-shurta"),
                Phrase(english: "I'm lost", arabic: "أنا ضايع", transliteration: "ana dhay'"),
                Phrase(english: "Can you help me?", arabic: "تقدر تساعدني؟", transliteration: "tiqdar tisa'adni?"),
                Phrase(english: "I don't speak Arabic", arabic: "ما أعرف أتكلم عربي", transliteration: "ma a'rif atkallam arabi")
            ]
        ),
        PhraseCategory(
            id: "numbers",
            nameEn: "Numbers",
            nameAr: "أرقام",
            icon: "number",
            phrases: [
                Phrase(english: "One", arabic: "واحد", transliteration: "wahid"),
                Phrase(english: "Two", arabic: "اثنين", transliteration: "ithneen"),
                Phrase(english: "Three", arabic: "ثلاثة", transliteration: "thalatha"),
                Phrase(english: "Five", arabic: "خمسة", transliteration: "khamsa"),
                Phrase(english: "Ten", arabic: "عشرة", transliteration: "ashara"),
                Phrase(english: "Hundred", arabic: "مية", transliteration: "miya"),
                Phrase(english: "Thousand", arabic: "ألف", transliteration: "alf")
            ]
        )
    ]
}

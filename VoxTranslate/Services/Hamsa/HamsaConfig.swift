// HamsaConfig.swift
// VoxTranslate
//
// Hamsa API configuration and key management.

import Foundation
import os.log

// MARK: - Hamsa Configuration

/// Configuration for the Hamsa API endpoints (Arabic dialect specialist).
enum HamsaConfig {
    private static let logger = Logger(subsystem: "com.voxtranslate", category: "HamsaConfig")

    /// Hamsa Speech-to-Text API endpoint.
    static let sttEndpoint = "https://api.tryhamsa.com/v1/speech-to-text"

    /// Hamsa Faseeh Translation API endpoint.
    static let translationEndpoint = "https://api.tryhamsa.com/v1/translate"

    /// Hamsa Text-to-Speech API endpoint.
    static let ttsEndpoint = "https://api.tryhamsa.com/v1/text-to-speech"

    /// API key loaded from Info.plist (injected via .xcconfig). Never hardcoded.
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["HAMSA_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_HAMSA_API_KEY_HERE" else {
            logger.fault("HAMSA_API_KEY not found or not configured in Info.plist. Add it via .xcconfig.")
            fatalError("HAMSA_API_KEY not found in Info.plist. Add it via .xcconfig.")
        }
        return key
    }

    // TODO: Production — replace direct API calls with proxy server

    /// Default request timeout for Hamsa API calls.
    static let requestTimeout: TimeInterval = 20

    /// Maps ArabicDialect to Hamsa's dialect code format.
    static func hamsaDialectCode(for dialect: ArabicDialect) -> String {
        switch dialect {
        case .najdi: return "ar-SA-najdi"
        case .hijazi: return "ar-SA-hijazi"
        case .gulf: return "ar-gulf"
        case .egyptian: return "ar-EG"
        case .levantine: return "ar-LB"
        case .moroccan: return "ar-MA"
        case .msa: return "ar-MSA"
        }
    }
}

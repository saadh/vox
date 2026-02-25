// EngineManager.swift
// VoxTranslate
//
// Tier selection and automatic failover logic for the translation engine stack.

import Foundation
import os.log

// MARK: - Engine Tier Level

/// The active translation engine tier, ordered by preference.
enum EngineTierLevel: Int, Comparable, Sendable {
    case tier1GeminiLive = 1
    case tier2Hamsa = 2
    case tier3Apple = 3

    static func < (lhs: EngineTierLevel, rhs: EngineTierLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .tier1GeminiLive: return String(localized: "Gemini Live", comment: "Engine tier")
        case .tier2Hamsa: return String(localized: "Enhanced Arabic", comment: "Engine tier")
        case .tier3Apple: return String(localized: "Offline Mode", comment: "Engine tier")
        }
    }

    var isOnline: Bool {
        self != .tier3Apple
    }
}

// MARK: - Engine Manager

/// Manages engine tier selection and automatic failover between translation providers.
///
/// The EngineManager observes network connectivity and user preferences to determine
/// the best available translation engine tier. It automatically fails over to lower
/// tiers when higher tiers are unavailable.
@Observable
final class EngineManager: @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "EngineManager")

    /// The currently active engine tier.
    private(set) var activeTier: EngineTierLevel = .tier1GeminiLive

    /// Whether enhanced Arabic mode (Hamsa) is enabled by the user.
    var isEnhancedArabicEnabled: Bool = false {
        didSet { reevaluateTier() }
    }

    /// Whether the network is currently available.
    private(set) var isNetworkAvailable: Bool = true

    /// Whether the Gemini Live API session is currently healthy.
    private(set) var isGeminiLiveHealthy: Bool = true

    /// The currently selected Arabic dialect.
    var selectedDialect: ArabicDialect = .najdi

    /// Whether the target language is Arabic.
    var isTargetArabic: Bool = false

    // MARK: - Services (lazy-initialized)

    let geminiLiveService = GeminiLiveAPIService()
    let geminiTranslationService = GeminiTranslationService()
    let geminiTTSService = GeminiTTSService()
    private(set) lazy var hamsaSTTService = HamsaSTTService(dialect: selectedDialect)
    let hamsaTranslationService = HamsaTranslationService()
    let hamsaTTSService = HamsaTTSService()
    let appleSpeechService = AppleSpeechRecognitionService()
    let appleTTSService = AppleTTSService()
    let allamService = ALLaMTranslationService()

    // MARK: - Initialization

    init() {
        logger.info("EngineManager initialized with Tier 1 (Gemini Live)")
    }

    // MARK: - Network State

    /// Updates the network availability state and reevaluates the active tier.
    /// Called by `NetworkMonitor`.
    func updateNetworkAvailability(_ isAvailable: Bool) {
        guard isNetworkAvailable != isAvailable else { return }
        isNetworkAvailable = isAvailable
        logger.info("Network availability changed: \(isAvailable)")
        reevaluateTier()
    }

    // MARK: - Gemini Health

    /// Reports a Gemini Live API failure, triggering potential tier demotion.
    func reportGeminiLiveFailure() {
        guard isGeminiLiveHealthy else { return }
        isGeminiLiveHealthy = false
        logger.warning("Gemini Live API marked as unhealthy")
        reevaluateTier()
    }

    /// Reports that Gemini Live API has recovered.
    func reportGeminiLiveRecovery() {
        guard !isGeminiLiveHealthy else { return }
        isGeminiLiveHealthy = true
        logger.info("Gemini Live API marked as healthy")
        reevaluateTier()
    }

    // MARK: - Tier Evaluation

    /// Reevaluates the best available tier based on current conditions.
    func reevaluateTier() {
        let previousTier = activeTier
        activeTier = determineBestTier()

        if activeTier != previousTier {
            logger.info("Engine tier changed: \(previousTier.displayName) → \(self.activeTier.displayName)")
        }
    }

    /// Determines the best available engine tier based on current conditions.
    func determineBestTier() -> EngineTierLevel {
        // No network → Tier 3 (Apple offline)
        guard isNetworkAvailable else {
            return .tier3Apple
        }

        // User enabled Enhanced Arabic mode for Arabic target → Tier 2 (Hamsa)
        if isEnhancedArabicEnabled && isTargetArabic && selectedDialect.isSaudi {
            return .tier2Hamsa
        }

        // Gemini Live API healthy → Tier 1
        if isGeminiLiveHealthy {
            return .tier1GeminiLive
        }

        // Gemini Live unhealthy but online → fall back to Tier 2 if Arabic, Tier 1 text otherwise
        if isTargetArabic {
            return .tier2Hamsa
        }

        // Gemini REST is still usable as a degraded Tier 1
        return .tier1GeminiLive
    }
}

// MARK: - Provider Access

extension EngineManager {
    /// Returns the active voice translation provider, or nil if using a chained pipeline.
    var voiceTranslationProvider: VoiceTranslationProvider? {
        switch activeTier {
        case .tier1GeminiLive:
            return geminiLiveService
        case .tier2Hamsa, .tier3Apple:
            return nil // These tiers use chained STT → Translation → TTS
        }
    }

    /// Returns the active speech recognition provider for chained pipelines.
    var speechRecognitionProvider: SpeechRecognitionProvider {
        switch activeTier {
        case .tier1GeminiLive:
            return appleSpeechService // Fallback; Tier 1 uses voice pipeline
        case .tier2Hamsa:
            return hamsaSTTService
        case .tier3Apple:
            return appleSpeechService
        }
    }

    /// Returns the active text translation provider.
    var translationProvider: TranslationProvider {
        switch activeTier {
        case .tier1GeminiLive, .tier2Hamsa:
            return geminiTranslationService
        case .tier3Apple:
            if #available(iOS 17.4, *) {
                return AppleTranslationService()
            }
            return geminiTranslationService // This will fail offline, but is the only option
        }
    }

    /// Returns the active speech synthesis provider.
    var speechSynthesisProvider: SpeechSynthesisProvider {
        switch activeTier {
        case .tier1GeminiLive:
            return geminiTTSService
        case .tier2Hamsa:
            return isTargetArabic ? hamsaTTSService : geminiTTSService
        case .tier3Apple:
            return appleTTSService
        }
    }
}

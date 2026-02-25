// EngineManagerTests.swift
// VoxTranslateTests
//
// Unit tests for EngineManager tier switching logic.

import XCTest
@testable import VoxTranslate

final class EngineManagerTests: XCTestCase {

    var sut: EngineManager!

    override func setUp() {
        super.setUp()
        sut = EngineManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Default State

    func testDefaultTierIsGeminiLive() {
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testDefaultNetworkIsAvailable() {
        XCTAssertTrue(sut.isNetworkAvailable)
    }

    func testDefaultGeminiLiveIsHealthy() {
        XCTAssertTrue(sut.isGeminiLiveHealthy)
    }

    func testDefaultEnhancedArabicIsDisabled() {
        XCTAssertFalse(sut.isEnhancedArabicEnabled)
    }

    // MARK: - Network Tier Switching

    func testNetworkLostSwitchesToTier3() {
        sut.updateNetworkAvailability(false)
        XCTAssertEqual(sut.activeTier, .tier3Apple)
    }

    func testNetworkRestoredSwitchesBackToTier1() {
        sut.updateNetworkAvailability(false)
        XCTAssertEqual(sut.activeTier, .tier3Apple)

        sut.updateNetworkAvailability(true)
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testDuplicateNetworkUpdateDoesNotRetrigger() {
        // Network is already available — setting to true again should be a no-op
        sut.updateNetworkAvailability(true)
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    // MARK: - Enhanced Arabic Mode

    func testEnhancedArabicWithSaudiDialectActivatesTier2() {
        sut.isTargetArabic = true
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true

        XCTAssertEqual(sut.activeTier, .tier2Hamsa)
    }

    func testEnhancedArabicWithHijaziDialectActivatesTier2() {
        sut.isTargetArabic = true
        sut.selectedDialect = .hijazi
        sut.isEnhancedArabicEnabled = true

        XCTAssertEqual(sut.activeTier, .tier2Hamsa)
    }

    func testEnhancedArabicWithGulfDialectActivatesTier2() {
        sut.isTargetArabic = true
        sut.selectedDialect = .gulf
        sut.isEnhancedArabicEnabled = true

        XCTAssertEqual(sut.activeTier, .tier2Hamsa)
    }

    func testEnhancedArabicWithNonSaudiDialectStaysTier1() {
        sut.isTargetArabic = true
        sut.selectedDialect = .egyptian
        sut.isEnhancedArabicEnabled = true

        // Egyptian is not a Saudi dialect, so Hamsa should not activate
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testEnhancedArabicWithNonArabicTargetStaysTier1() {
        sut.isTargetArabic = false
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true

        // Target is not Arabic, so Hamsa should not activate
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testDisablingEnhancedArabicReturnToTier1() {
        sut.isTargetArabic = true
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true
        XCTAssertEqual(sut.activeTier, .tier2Hamsa)

        sut.isEnhancedArabicEnabled = false
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    // MARK: - Gemini Health

    func testGeminiLiveFailureDemotesToTier2ForArabic() {
        sut.isTargetArabic = true
        sut.reportGeminiLiveFailure()

        XCTAssertEqual(sut.activeTier, .tier2Hamsa)
    }

    func testGeminiLiveFailureStaysTier1ForNonArabic() {
        sut.isTargetArabic = false
        sut.reportGeminiLiveFailure()

        // Non-Arabic target still uses Gemini REST as degraded Tier 1
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testGeminiLiveRecoveryPromotesBackToTier1() {
        sut.isTargetArabic = true
        sut.reportGeminiLiveFailure()
        XCTAssertEqual(sut.activeTier, .tier2Hamsa)

        sut.reportGeminiLiveRecovery()
        XCTAssertEqual(sut.activeTier, .tier1GeminiLive)
    }

    func testDuplicateGeminiFailureDoesNotRetrigger() {
        sut.reportGeminiLiveFailure()
        // Second failure should be a no-op
        sut.reportGeminiLiveFailure()
        XCTAssertFalse(sut.isGeminiLiveHealthy)
    }

    // MARK: - Combined Conditions

    func testNetworkLostOverridesEnhancedArabic() {
        sut.isTargetArabic = true
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true
        XCTAssertEqual(sut.activeTier, .tier2Hamsa)

        sut.updateNetworkAvailability(false)
        XCTAssertEqual(sut.activeTier, .tier3Apple)
    }

    func testNetworkRestoredWithEnhancedArabicReturnsTier2() {
        sut.isTargetArabic = true
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true

        sut.updateNetworkAvailability(false)
        XCTAssertEqual(sut.activeTier, .tier3Apple)

        sut.updateNetworkAvailability(true)
        XCTAssertEqual(sut.activeTier, .tier2Hamsa)
    }

    // MARK: - determineBestTier() Direct Testing

    func testDetermineBestTierWithAllDefaults() {
        XCTAssertEqual(sut.determineBestTier(), .tier1GeminiLive)
    }

    func testDetermineBestTierOffline() {
        sut.updateNetworkAvailability(false)
        XCTAssertEqual(sut.determineBestTier(), .tier3Apple)
    }

    // MARK: - EngineTierLevel Comparable

    func testTierLevelOrdering() {
        XCTAssertTrue(EngineTierLevel.tier1GeminiLive < .tier2Hamsa)
        XCTAssertTrue(EngineTierLevel.tier2Hamsa < .tier3Apple)
        XCTAssertTrue(EngineTierLevel.tier1GeminiLive < .tier3Apple)
    }

    func testTierLevelDisplayNames() {
        XCTAssertFalse(EngineTierLevel.tier1GeminiLive.displayName.isEmpty)
        XCTAssertFalse(EngineTierLevel.tier2Hamsa.displayName.isEmpty)
        XCTAssertFalse(EngineTierLevel.tier3Apple.displayName.isEmpty)
    }

    func testTierLevelOnlineStatus() {
        XCTAssertTrue(EngineTierLevel.tier1GeminiLive.isOnline)
        XCTAssertTrue(EngineTierLevel.tier2Hamsa.isOnline)
        XCTAssertFalse(EngineTierLevel.tier3Apple.isOnline)
    }

    // MARK: - Provider Access

    func testVoiceTranslationProviderForTier1() {
        XCTAssertNotNil(sut.voiceTranslationProvider)
    }

    func testVoiceTranslationProviderForTier2IsNil() {
        sut.isTargetArabic = true
        sut.selectedDialect = .najdi
        sut.isEnhancedArabicEnabled = true

        XCTAssertNil(sut.voiceTranslationProvider)
    }

    func testVoiceTranslationProviderForTier3IsNil() {
        sut.updateNetworkAvailability(false)
        XCTAssertNil(sut.voiceTranslationProvider)
    }
}

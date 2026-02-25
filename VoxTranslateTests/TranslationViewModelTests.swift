// TranslationViewModelTests.swift
// VoxTranslateTests
//
// Unit tests for TranslationViewModel state transitions.

import XCTest
@testable import VoxTranslate

@MainActor
final class TranslationViewModelTests: XCTestCase {

    var sut: TranslationViewModel!

    override func setUp() {
        super.setUp()
        sut = TranslationViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStateIsIdle() {
        XCTAssertTrue(sut.state.isIdle)
    }

    func testInitialSourceTextIsEmpty() {
        XCTAssertTrue(sut.sourceText.isEmpty)
    }

    func testInitialTranslatedTextIsEmpty() {
        XCTAssertTrue(sut.translatedText.isEmpty)
    }

    func testInitialActivePanelIsNil() {
        XCTAssertNil(sut.activePanel)
    }

    func testInitialHistoryIsEmpty() {
        XCTAssertTrue(sut.conversationHistory.isEmpty)
    }

    func testInitialErrorMessageIsNil() {
        XCTAssertNil(sut.errorMessage)
    }

    func testInitialPlaybackSpeedIsDefault() {
        XCTAssertEqual(sut.playbackSpeed, 1.0)
    }

    // MARK: - TranslationState Properties

    func testIdleStateProperties() {
        let state = TranslationState.idle
        XCTAssertTrue(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertFalse(state.isSpeaking)
    }

    func testRecordingStateProperties() {
        let state = TranslationState.recording
        XCTAssertFalse(state.isIdle)
        XCTAssertTrue(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertFalse(state.isSpeaking)
    }

    func testProcessingStateProperties() {
        let state = TranslationState.processing
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isProcessing)
        XCTAssertFalse(state.isSpeaking)
    }

    func testTranslatingStateProperties() {
        let state = TranslationState.translating
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertTrue(state.isProcessing)
        XCTAssertFalse(state.isSpeaking)
    }

    func testSpeakingStateProperties() {
        let state = TranslationState.speaking
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertTrue(state.isSpeaking)
    }

    func testErrorStateProperties() {
        let state = TranslationState.error("test error")
        XCTAssertFalse(state.isIdle)
        XCTAssertFalse(state.isRecording)
        XCTAssertFalse(state.isProcessing)
        XCTAssertFalse(state.isSpeaking)
    }

    // MARK: - Language Management

    func testSwapLanguagesCallsLanguageStore() {
        let originalSource = sut.languageStore.sourceLanguageCode
        let originalTarget = sut.languageStore.targetLanguageCode

        sut.swapLanguages()

        XCTAssertEqual(sut.languageStore.sourceLanguageCode, originalTarget)
        XCTAssertEqual(sut.languageStore.targetLanguageCode, originalSource)
    }

    func testCurrentSourceLanguageForTopPanel() {
        // When no active panel, source is the languageStore's source
        XCTAssertEqual(sut.currentSourceLanguage.id, sut.languageStore.sourceLanguage.id)
    }

    func testCurrentTargetLanguageForTopPanel() {
        XCTAssertEqual(sut.currentTargetLanguage.id, sut.languageStore.targetLanguage.id)
    }

    func testDefaultLanguagePairIsEnglishToArabic() {
        XCTAssertEqual(sut.languageStore.sourceLanguageCode, "en")
        XCTAssertEqual(sut.languageStore.targetLanguageCode, "ar")
    }

    // MARK: - History Management

    func testClearHistoryRemovesAllEntries() {
        // Add a fake entry
        sut.conversationHistory.append(
            ConversationEntry(
                sourceText: "Hello",
                sourceLanguage: .english,
                translatedText: "هلا",
                targetLanguage: .arabic,
                engineTier: .geminiLive
            )
        )

        XCTAssertFalse(sut.conversationHistory.isEmpty)

        sut.clearHistory()
        XCTAssertTrue(sut.conversationHistory.isEmpty)
    }

    // MARK: - Engine Tier

    func testCurrentTierReflectsEngineManager() {
        XCTAssertEqual(sut.currentTier, sut.engineManager.activeTier)
    }

    func testTierChangesWhenNetworkChanges() {
        sut.engineManager.updateNetworkAvailability(false)
        XCTAssertEqual(sut.currentTier, .tier3Apple)
    }

    // MARK: - Playback Speed

    func testPlaybackSpeedCanBeChanged() {
        sut.playbackSpeed = 0.75
        XCTAssertEqual(sut.playbackSpeed, 0.75)

        sut.playbackSpeed = 1.25
        XCTAssertEqual(sut.playbackSpeed, 1.25)
    }

    // MARK: - State Equality

    func testTranslationStateEquality() {
        XCTAssertEqual(TranslationState.idle, TranslationState.idle)
        XCTAssertEqual(TranslationState.recording, TranslationState.recording)
        XCTAssertEqual(TranslationState.processing, TranslationState.processing)
        XCTAssertEqual(TranslationState.translating, TranslationState.translating)
        XCTAssertEqual(TranslationState.speaking, TranslationState.speaking)
        XCTAssertEqual(TranslationState.error("a"), TranslationState.error("a"))

        XCTAssertNotEqual(TranslationState.idle, TranslationState.recording)
        XCTAssertNotEqual(TranslationState.error("a"), TranslationState.error("b"))
    }
}

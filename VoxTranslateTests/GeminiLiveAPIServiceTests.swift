// GeminiLiveAPIServiceTests.swift
// VoxTranslateTests
//
// Unit tests for GeminiLiveAPIService WebSocket message parsing.

import XCTest
@testable import VoxTranslate

final class GeminiLiveAPIServiceTests: XCTestCase {

    // MARK: - Setup Complete Parsing

    func testParseSetupCompleteMessage() {
        let json = """
        {
            "setupComplete": {}
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .sessionStarted = events.first {
            // Pass
        } else {
            XCTFail("Expected .sessionStarted event, got \\(String(describing: events.first))")
        }
    }

    // MARK: - Text Response Parsing

    func testParsePartialTextResponse() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "وين أقرب" }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .partialTranslation(let text) = events.first {
            XCTAssertEqual(text, "وين أقرب")
        } else {
            XCTFail("Expected .partialTranslation event")
        }
    }

    func testParseFinalTextResponse() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "وين أقرب مطعم؟" }
                    ]
                },
                "turnComplete": true
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        // Expect: finalTranslation, audioComplete, turnComplete
        XCTAssertEqual(events.count, 3)

        if case .finalTranslation(let text) = events[0] {
            XCTAssertEqual(text, "وين أقرب مطعم؟")
        } else {
            XCTFail("Expected .finalTranslation event")
        }

        if case .audioComplete = events[1] {
            // Pass
        } else {
            XCTFail("Expected .audioComplete event")
        }

        if case .turnComplete = events[2] {
            // Pass
        } else {
            XCTFail("Expected .turnComplete event")
        }
    }

    // MARK: - Audio Response Parsing

    func testParseAudioChunkResponse() {
        // Base64 for "Hello" in bytes
        let testData = Data([0x48, 0x65, 0x6C, 0x6C, 0x6F])
        let base64 = testData.base64EncodedString()

        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": "audio/pcm",
                                "data": "\(base64)"
                            }
                        }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .audioChunk(let data) = events.first {
            XCTAssertEqual(data, testData)
        } else {
            XCTFail("Expected .audioChunk event")
        }
    }

    func testParseNonAudioInlineDataIsIgnored() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": "image/png",
                                "data": "aW1hZ2VkYXRh"
                            }
                        }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertTrue(events.isEmpty, "Non-audio inline data should be ignored")
    }

    // MARK: - Mixed Content Parsing

    func testParseMixedTextAndAudioResponse() {
        let audioData = Data([0x01, 0x02, 0x03])
        let base64 = audioData.base64EncodedString()

        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "Where is the restaurant?" },
                        {
                            "inlineData": {
                                "mimeType": "audio/pcm",
                                "data": "\(base64)"
                            }
                        }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 2)

        if case .partialTranslation(let text) = events[0] {
            XCTAssertEqual(text, "Where is the restaurant?")
        } else {
            XCTFail("Expected .partialTranslation event")
        }

        if case .audioChunk(let data) = events[1] {
            XCTAssertEqual(data, audioData)
        } else {
            XCTFail("Expected .audioChunk event")
        }
    }

    // MARK: - Turn Complete

    func testParseTurnCompleteWithoutModelTurn() {
        let json = """
        {
            "serverContent": {
                "turnComplete": true
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        // Should still get audioComplete and turnComplete
        XCTAssertEqual(events.count, 2)

        if case .audioComplete = events[0] {
            // Pass
        } else {
            XCTFail("Expected .audioComplete event")
        }

        if case .turnComplete = events[1] {
            // Pass
        } else {
            XCTFail("Expected .turnComplete event")
        }
    }

    // MARK: - Invalid Input Handling

    func testParseInvalidJSON() {
        let events = GeminiLiveAPIService.parseEvents(from: "not json")
        XCTAssertTrue(events.isEmpty)
    }

    func testParseEmptyString() {
        let events = GeminiLiveAPIService.parseEvents(from: "")
        XCTAssertTrue(events.isEmpty)
    }

    func testParseEmptyObject() {
        let events = GeminiLiveAPIService.parseEvents(from: "{}")
        XCTAssertTrue(events.isEmpty)
    }

    func testParseUnknownMessageType() {
        let json = """
        {
            "unknownField": { "data": "test" }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)
        XCTAssertTrue(events.isEmpty)
    }

    // MARK: - Arabic Text Parsing

    func testParseArabicTextWithDiacritics() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ" }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .partialTranslation(let text) = events.first {
            XCTAssertEqual(text, "بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ")
        } else {
            XCTFail("Expected .partialTranslation event with Arabic diacritics")
        }
    }

    func testParseMixedArabicEnglishText() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "أبغى أروح Starbucks القريب" }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .partialTranslation(let text) = events.first {
            XCTAssertEqual(text, "أبغى أروح Starbucks القريب")
            XCTAssertTrue(text.contains("Starbucks"))
        } else {
            XCTFail("Expected .partialTranslation event with mixed Arabic/English")
        }
    }

    // MARK: - Saudi Dialect Text Parsing

    func testParseSaudiDialectText() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "وين أقرب مطعم؟" }
                    ]
                },
                "turnComplete": true
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        if case .finalTranslation(let text) = events.first {
            // Verify Saudi dialect markers
            XCTAssertTrue(text.contains("وين"), "Should use Saudi 'wayn' instead of MSA 'ayna'")
        } else {
            XCTFail("Expected .finalTranslation event")
        }
    }

    // MARK: - Edge Cases

    func testParseEmptyTextPart() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "" }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 1)
        if case .partialTranslation(let text) = events.first {
            XCTAssertEqual(text, "")
        } else {
            XCTFail("Expected .partialTranslation event with empty text")
        }
    }

    func testParseMultipleTextParts() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        { "text": "Hello " },
                        { "text": "World" }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        XCTAssertEqual(events.count, 2)
        if case .partialTranslation(let text1) = events[0],
           case .partialTranslation(let text2) = events[1] {
            XCTAssertEqual(text1, "Hello ")
            XCTAssertEqual(text2, "World")
        } else {
            XCTFail("Expected two .partialTranslation events")
        }
    }

    func testParseInvalidBase64AudioIsIgnored() {
        let json = """
        {
            "serverContent": {
                "modelTurn": {
                    "parts": [
                        {
                            "inlineData": {
                                "mimeType": "audio/pcm",
                                "data": "!!!not-base64!!!"
                            }
                        }
                    ]
                }
            }
        }
        """

        let events = GeminiLiveAPIService.parseEvents(from: json)

        // Invalid base64 should be silently ignored
        XCTAssertTrue(events.isEmpty)
    }
}

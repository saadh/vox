// GeminiConfig.swift
// VoxTranslate
//
// API configuration and key management for Gemini services.

import Foundation
import os.log

// MARK: - Gemini Configuration

/// Configuration for the Gemini API endpoints and authentication.
enum GeminiConfig {
    /// Logger for Gemini configuration events.
    private static let logger = Logger(subsystem: "com.voxtranslate", category: "GeminiConfig")

    /// Gemini Live API WebSocket endpoint for streaming bidirectional audio.
    static let liveAPIEndpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

    /// Gemini REST API endpoint for text translation using gemini-2.5-flash.
    static let restAPIEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    /// Gemini TTS endpoint using gemini-2.5-flash-tts.
    static let ttsEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-tts:generateContent"

    /// The model name for the Live API (native audio).
    static let liveModelName = "gemini-2.5-flash-exp-native-audio-thinking"

    /// API key loaded from Info.plist (injected via .xcconfig). Never hardcoded.
    ///
    /// - Note: Intentionally crashes on misconfiguration to surface setup errors immediately.
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["GEMINI_API_KEY"] as? String,
              !key.isEmpty,
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            logger.fault("GEMINI_API_KEY not found or not configured in Info.plist. Add it via .xcconfig.")
            fatalError("GEMINI_API_KEY not found in Info.plist. Add it via .xcconfig.")
        }
        return key
    }

    // TODO: Production — replace direct API calls with proxy server

    /// Constructs the Live API WebSocket URL with the API key as a query parameter.
    static var liveAPIURL: URL {
        var components = URLComponents(string: liveAPIEndpoint)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url!
    }

    /// Constructs a REST API URL with the API key as a query parameter.
    /// - Parameter endpoint: The base endpoint URL string.
    /// - Returns: A URL with the API key appended.
    static func restURL(for endpoint: String) -> URL {
        var components = URLComponents(string: endpoint)!
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        return components.url!
    }
}

// MARK: - Audio Format Constants

extension GeminiConfig {
    /// Expected input audio format for Gemini Live API.
    enum InputAudio {
        static let sampleRate: Double = 16000
        static let channelCount: Int = 1
        static let bitsPerSample: Int = 16
        static let bytesPerSample: Int = 2
        /// Duration of each audio chunk sent to the API (in seconds).
        static let chunkDuration: TimeInterval = 0.1
        /// Number of bytes in each chunk (~100ms of 16kHz 16-bit mono audio).
        static let chunkSize: Int = Int(sampleRate * chunkDuration) * bytesPerSample
    }

    /// Output audio format from Gemini Live API.
    enum OutputAudio {
        static let sampleRate: Double = 24000
        static let channelCount: Int = 1
        static let bitsPerSample: Int = 16
        static let bytesPerSample: Int = 2
    }
}

// MARK: - Session Configuration

extension GeminiConfig {
    /// The default request timeout for REST API calls.
    static let requestTimeout: TimeInterval = 30

    /// WebSocket ping interval to keep the connection alive.
    static let webSocketPingInterval: TimeInterval = 15

    /// Maximum time to wait for the WebSocket connection to establish.
    static let connectionTimeout: TimeInterval = 10

    /// Maximum number of reconnection attempts before giving up.
    static let maxReconnectAttempts = 3

    /// Base delay between reconnection attempts (doubled each attempt).
    static let reconnectBaseDelay: TimeInterval = 1.0
}

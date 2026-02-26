// ContentView.swift
// VoxTranslate
//
// Root content view with tab bar for Translation, History, and Phrasebook.

import SwiftUI

// MARK: - Content View

/// Root view containing the tab-based navigation between Translation, History, and Phrasebook.
struct ContentView: View {
    // MARK: - Properties

    @State private var viewModel = TranslationViewModel()
    @State private var selectedTab: Tab = .translate

    // MARK: - Tab

    enum Tab {
        case translate
        case history
        case phrasebook
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            // Translation tab
            NavigationStack {
                translationView
                    .navigationTitle(String(localized: "VoxTranslate", comment: "App name"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            settingsButton
                        }
                    }
            }
            .tabItem {
                Label(
                    String(localized: "Translate", comment: "Tab title"),
                    systemImage: "mic.fill"
                )
            }
            .tag(Tab.translate)

            // History tab
            HistoryView(
                entries: viewModel.conversationHistory,
                onReplay: { entry in
                    Task {
                        await viewModel.replayEntry(entry)
                    }
                },
                onClear: {
                    viewModel.clearHistory()
                }
            )
            .tabItem {
                Label(
                    String(localized: "History", comment: "Tab title"),
                    systemImage: "clock.arrow.circlepath"
                )
            }
            .tag(Tab.history)

            // Phrasebook tab
            PhrasebookView { phrase in
                // Play the Arabic phrase using TTS
                Task {
                    let tts = viewModel.engineManager.speechSynthesisProvider
                    do {
                        let audio = try await tts.synthesize(
                            phrase.arabic,
                            language: .arabic,
                            dialect: viewModel.languageStore.selectedDialect
                        )
                        try viewModel.audioStreamManager.playAudio(audio)
                    } catch {
                        // Fall back to Apple TTS for direct playback
                        viewModel.engineManager.appleTTSService.speakDirectly(
                            phrase.arabic,
                            language: .arabic,
                            dialect: viewModel.languageStore.selectedDialect
                        )
                    }
                }
            }
            .tabItem {
                Label(
                    String(localized: "Phrases", comment: "Tab title"),
                    systemImage: "book.fill"
                )
            }
            .tag(Tab.phrasebook)
        }
    }

    // MARK: - Translation View

    private var translationView: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.clearError()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Dual panel
            DualPanelView(viewModel: viewModel)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Settings Button

    private var settingsButton: some View {
        Menu {
            // Enhanced Arabic mode toggle
            Toggle(isOn: Binding(
                get: { viewModel.engineManager.isEnhancedArabicEnabled },
                set: { viewModel.engineManager.isEnhancedArabicEnabled = $0 }
            )) {
                Label(
                    String(localized: "Enhanced Arabic Mode", comment: "Settings toggle"),
                    systemImage: "waveform"
                )
            }

            Divider()

            // Playback speed
            Menu {
                Button("0.75x") { viewModel.playbackSpeed = 0.75 }
                Button("1.0x") { viewModel.playbackSpeed = 1.0 }
                Button("1.25x") { viewModel.playbackSpeed = 1.25 }
            } label: {
                Label(
                    String(localized: "Playback Speed", comment: "Settings menu"),
                    systemImage: "speedometer"
                )
            }

            Divider()

            // Engine tier info
            Section(String(localized: "Engine", comment: "Settings section")) {
                Label(
                    viewModel.currentTier.displayName,
                    systemImage: viewModel.currentTier.isOnline ? "wifi" : "wifi.slash"
                )
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
        }
        .accessibilityLabel(String(localized: "Settings", comment: "Settings button"))
    }
}

// MARK: - Preview

#Preview("Content View") {
    ContentView()
}

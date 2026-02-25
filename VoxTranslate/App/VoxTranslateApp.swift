// VoxTranslateApp.swift
// VoxTranslate
//
// App entry point with audio session setup and first-launch flow.

import SwiftUI
import os.log

// MARK: - VoxTranslate App

/// Main app entry point for VoxTranslate — a voice-first, real-time translation tool
/// designed for travelers needing instant spoken translation with Saudi Arabic dialect support.
@main
struct VoxTranslateApp: App {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voxtranslate", category: "App")

    @State private var showFirstLaunch = false
    @State private var permissionsManager = PermissionsManager()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupAudioSession()
                    checkFirstLaunch()
                }
                .sheet(isPresented: $showFirstLaunch) {
                    FirstLaunchView(permissionsManager: permissionsManager) {
                        showFirstLaunch = false
                    }
                }
        }
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            try AudioSessionManager.shared.configure()
            logger.info("Audio session configured on launch")
        } catch {
            logger.error("Failed to configure audio session on launch: \(error.localizedDescription)")
        }
    }

    private func checkFirstLaunch() {
        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        if !hasLaunched {
            showFirstLaunch = true
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }
}

// MARK: - First Launch View

/// First-launch privacy notice and permission request flow.
struct FirstLaunchView: View {
    let permissionsManager: PermissionsManager
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $currentPage) {
                // Welcome page
                welcomePage.tag(0)

                // Privacy notice page
                privacyPage.tag(1)

                // Permissions page
                permissionsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Welcome Page

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.badge.xmark")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .symbolRenderingMode(.hierarchical)

            Text("Welcome to VoxTranslate", comment: "First launch title")
                .font(.system(.largeTitle, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Voice-first translation for Saudi Arabia", comment: "First launch subtitle")
                .font(.system(.title3))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "waveform",
                    title: String(localized: "Speak naturally", comment: "Feature title"),
                    description: String(localized: "Tap, speak, and hear the translation instantly", comment: "Feature description")
                )

                featureRow(
                    icon: "globe",
                    title: String(localized: "Saudi dialect", comment: "Feature title"),
                    description: String(localized: "Natural Gulf Arabic — not formal MSA", comment: "Feature description")
                )

                featureRow(
                    icon: "bolt.fill",
                    title: String(localized: "Near-instant", comment: "Feature title"),
                    description: String(localized: "AI-powered live voice translation", comment: "Feature description")
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Continue", comment: "Continue button")
                    .font(.system(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Privacy Page

    private var privacyPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Your Privacy Matters", comment: "Privacy title")
                .font(.system(.title, weight: .bold))

            VStack(alignment: .leading, spacing: 16) {
                privacyRow(
                    icon: "waveform.slash",
                    text: String(localized: "Audio is streamed in real-time and not stored", comment: "Privacy point")
                )

                privacyRow(
                    icon: "trash.slash",
                    text: String(localized: "Conversation history is cleared when you close the app", comment: "Privacy point")
                )

                privacyRow(
                    icon: "chart.bar.xaxis",
                    text: String(localized: "No analytics or tracking — no third-party SDKs", comment: "Privacy point")
                )

                privacyRow(
                    icon: "cloud.fill",
                    text: String(localized: "Audio is processed by Google (Gemini AI) for translation", comment: "Privacy point")
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                withAnimation { currentPage = 2 }
            } label: {
                Text("I Understand", comment: "Privacy acknowledgment button")
                    .font(.system(.body, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Permissions Page

    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)

            Text("Microphone Access", comment: "Permissions title")
                .font(.system(.title, weight: .bold))

            Text("VoxTranslate needs your microphone to hear and translate speech.", comment: "Permissions description")
                .font(.system(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await permissionsManager.requestAllPermissions()
                        onComplete()
                    }
                } label: {
                    Text("Allow Microphone Access", comment: "Permission button")
                        .font(.system(.body, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    onComplete()
                } label: {
                    Text("Skip for Now", comment: "Skip permission button")
                        .font(.system(.body))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helper Views

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, weight: .semibold))
                Text(description)
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func privacyRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 24)

            Text(text)
                .font(.system(.subheadline))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Preview

#Preview("First Launch") {
    FirstLaunchView(
        permissionsManager: PermissionsManager(),
        onComplete: {}
    )
}

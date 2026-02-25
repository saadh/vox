// DualPanelView.swift
// VoxTranslate
//
// Main screen with dual language panels, swap button, and tier indicator.

import SwiftUI

// MARK: - Dual Panel View

/// The main translation screen with two language panels — one for each speaker
/// in the conversation. Supports RTL-aware rendering and tier indicator badges.
struct DualPanelView: View {
    // MARK: - Properties

    @State var viewModel: TranslationViewModel
    @State private var showLanguageSelectorForTop = false
    @State private var showLanguageSelectorForBottom = false
    @State private var showDialectSelector = false
    @State private var swapRotation: Double = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Tier indicator badge
            tierBadge

            // Top panel (Language A — default English)
            topPanel

            // Swap button
            swapButton

            // Bottom panel (Language B — default Saudi Arabic)
            bottomPanel
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .sheet(isPresented: $showLanguageSelectorForTop) {
            LanguageSelectorView(
                selectedLanguage: viewModel.languageStore.sourceLanguage,
                languages: LanguageCode.allWithAutoDetect,
                recentLanguages: viewModel.languageStore.recentLanguages,
                onSelect: { language in
                    viewModel.languageStore.setSourceLanguage(language)
                    showLanguageSelectorForTop = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showLanguageSelectorForBottom) {
            LanguageSelectorView(
                selectedLanguage: viewModel.languageStore.targetLanguage,
                languages: LanguageCode.allSupported,
                recentLanguages: viewModel.languageStore.recentLanguages,
                onSelect: { language in
                    viewModel.languageStore.setTargetLanguage(language)
                    showLanguageSelectorForBottom = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDialectSelector) {
            DialectSelectorView(
                selectedDialect: viewModel.languageStore.selectedDialect,
                onSelect: { dialect in
                    viewModel.languageStore.setDialect(dialect)
                    showDialectSelector = false
                }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - Top Panel

    private var topPanel: some View {
        TranslationPanelView(
            position: .top,
            language: viewModel.languageStore.sourceLanguage,
            dialect: viewModel.languageStore.isSourceArabic ? viewModel.languageStore.selectedDialect : nil,
            text: viewModel.activePanel == .top ? viewModel.sourceText : viewModel.translatedText,
            isPartial: viewModel.activePanel == .top ? viewModel.isSourcePartial : viewModel.isTranslationPartial,
            isRecording: viewModel.state.isRecording && viewModel.activePanel == .top,
            isSpeaking: viewModel.state.isSpeaking && viewModel.activePanel == .bottom,
            audioLevel: viewModel.audioLevel,
            onMicTap: {
                Task {
                    await viewModel.toggleRecording(for: .top)
                }
            },
            onLanguageTap: {
                showLanguageSelectorForTop = true
            },
            onDialectTap: {
                showDialectSelector = true
            },
            onTextTap: {
                Task {
                    await viewModel.replayTranslation()
                }
            }
        )
    }

    // MARK: - Swap Button

    private var swapButton: some View {
        Button {
            withAnimation(
                UIAccessibility.isReduceMotionEnabled
                    ? .none
                    : .spring(response: 0.4, dampingFraction: 0.7)
            ) {
                viewModel.swapLanguages()
                swapRotation += 180
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .rotation3DEffect(
                    .degrees(swapRotation),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .padding(.vertical, 8)
        .accessibilityLabel(String(localized: "Swap languages", comment: "Swap button label"))
        .accessibilityHint(String(localized: "Swaps source and target languages", comment: "Swap button hint"))
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        TranslationPanelView(
            position: .bottom,
            language: viewModel.languageStore.targetLanguage,
            dialect: viewModel.languageStore.isTargetArabic ? viewModel.languageStore.selectedDialect : nil,
            text: viewModel.activePanel == .bottom ? viewModel.sourceText : viewModel.translatedText,
            isPartial: viewModel.activePanel == .bottom ? viewModel.isSourcePartial : viewModel.isTranslationPartial,
            isRecording: viewModel.state.isRecording && viewModel.activePanel == .bottom,
            isSpeaking: viewModel.state.isSpeaking && viewModel.activePanel == .top,
            audioLevel: viewModel.audioLevel,
            onMicTap: {
                Task {
                    await viewModel.toggleRecording(for: .bottom)
                }
            },
            onLanguageTap: {
                showLanguageSelectorForBottom = true
            },
            onDialectTap: {
                showDialectSelector = true
            },
            onTextTap: {
                Task {
                    await viewModel.replayTranslation()
                }
            }
        )
    }

    // MARK: - Tier Badge

    @ViewBuilder
    private var tierBadge: some View {
        if viewModel.currentTier != .tier1GeminiLive {
            HStack(spacing: 6) {
                Image(systemName: viewModel.currentTier == .tier3Apple ? "wifi.slash" : "waveform")
                    .font(.caption2)

                Text(viewModel.currentTier.displayName)
                    .font(.system(.caption2, weight: .medium))
            }
            .foregroundStyle(viewModel.currentTier == .tier3Apple ? .orange : .blue)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(viewModel.currentTier == .tier3Apple
                        ? Color.orange.opacity(0.15)
                        : Color.blue.opacity(0.15)
                    )
            )
            .transition(
                UIAccessibility.isReduceMotionEnabled
                    ? .opacity
                    : .move(edge: .top).combined(with: .opacity)
            )
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Error Banner

/// Inline error banner shown when translation fails.
struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.system(.caption, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview("Dual Panel") {
    DualPanelView(viewModel: TranslationViewModel())
}

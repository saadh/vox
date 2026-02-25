// TranslationPanelView.swift
// VoxTranslate
//
// Individual panel component for one side of the dual-language translation interface.

import SwiftUI

// MARK: - Panel Position

/// Whether this panel is the top or bottom in the dual-panel layout.
enum PanelPosition {
    case top
    case bottom
}

// MARK: - Translation Panel View

/// A single language panel displaying the language label, recognized/translated text,
/// mic button, and waveform. Supports RTL rendering for Arabic text.
struct TranslationPanelView: View {
    // MARK: - Properties

    let position: PanelPosition
    let language: LanguageCode
    let dialect: ArabicDialect?
    let text: String
    let isPartial: Bool
    let isRecording: Bool
    let isSpeaking: Bool
    let audioLevel: Float
    let onMicTap: () -> Void
    let onLanguageTap: () -> Void
    let onDialectTap: () -> Void
    let onTextTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            // Language label
            languageHeader

            // Text display area
            textDisplay

            // Waveform (shown during recording)
            if isRecording {
                WaveformView(audioLevel: audioLevel, isActive: true)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }

            // Speaker animation (shown during playback)
            if isSpeaking {
                SpeakerAnimationView(isPlaying: true)
                    .transition(.opacity)
            }

            // Mic button
            micButton
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(panelBorderColor, lineWidth: 1)
        )
        .shadow(color: isRecording ? .red.opacity(0.1) : .clear, radius: 8)
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isRecording)
    }

    // MARK: - Language Header

    private var languageHeader: some View {
        HStack {
            if language.isRTL {
                Spacer()
            }

            Button(action: onLanguageTap) {
                HStack(spacing: 6) {
                    Text(language.flagEmoji)
                        .font(.title3)

                    VStack(alignment: language.isRTL ? .trailing : .leading, spacing: 2) {
                        Text(language.isRTL ? language.nativeName : language.englishName)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)

                        // Dialect badge for Arabic
                        if language.id == "ar", let dialect = dialect {
                            Button(action: onDialectTap) {
                                Text(dialect.badgeLabel)
                                    .font(.system(.caption2, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(red: 4/255, green: 120/255, blue: 87/255))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(String(localized: "\(language.englishName). Tap to change language.", comment: "Language button label"))

            if !language.isRTL {
                Spacer()
            }
        }
    }

    // MARK: - Text Display

    private var textDisplay: some View {
        Group {
            if text.isEmpty {
                Text(placeholderText)
                    .font(.system(.title3))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: language.isRTL ? .trailing : .leading)
            } else {
                Text(text)
                    .font(.system(isTranslationPanel ? .title3 : .title3, weight: isPartial ? .regular : .semibold))
                    .foregroundStyle(isTranslationPanel
                        ? Color(red: 30/255, green: 64/255, blue: 175/255)
                        : .primary
                    )
                    .opacity(isPartial ? 0.7 : 1.0)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: language.isRTL ? .trailing : .leading)
                    .multilineTextAlignment(language.isRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, language.isRTL ? .rightToLeft : .leftToRight)
                    .onTapGesture(perform: onTextTap)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .animation(reduceMotion ? .none : .spring(duration: 0.3), value: text)
                    .accessibilityLabel(text)
                    .accessibilityHint(String(localized: "Tap to replay translation", comment: "Text tap hint"))
            }
        }
    }

    // MARK: - Mic Button

    private var micButton: some View {
        Button(action: onMicTap) {
            ZStack {
                // Pulsing ring during recording
                if isRecording {
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 3)
                        .frame(width: 80, height: 80)
                        .modifier(PulseModifier(isActive: isRecording && !reduceMotion))
                }

                Circle()
                    .fill(isRecording ? Color.red : Color(red: 59/255, green: 130/255, blue: 246/255))
                    .frame(width: 72, height: 72)
                    .scaleEffect(isRecording ? 1.0 : 0.92)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.6),
                        value: isRecording
                    )

                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel(micAccessibilityLabel)
        .accessibilityHint(isRecording
            ? String(localized: "Tap to stop recording", comment: "Mic hint recording")
            : String(localized: "Tap to start recording", comment: "Mic hint idle")
        )
    }

    // MARK: - Helpers

    private var isTranslationPanel: Bool {
        (position == .top && false) || (position == .bottom && true)
    }

    private var placeholderText: String {
        isRecording
            ? String(localized: "Listening...", comment: "Recording placeholder")
            : String(localized: "Tap the mic to speak", comment: "Idle placeholder")
    }

    private var micAccessibilityLabel: String {
        let action = isRecording
            ? String(localized: "Stop recording", comment: "Mic label recording")
            : String(localized: "Record", comment: "Mic label idle")
        return "\(action) \(language.englishName)"
    }

    private var panelBackground: some View {
        Group {
            if position == .top {
                Color(colorScheme == .dark ? .secondarySystemBackground : .white)
            } else {
                Color(colorScheme == .dark ? .tertiarySystemBackground : Color(red: 240/255, green: 244/255, blue: 255/255))
            }
        }
    }

    private var panelBorderColor: Color {
        if position == .top {
            return Color(red: 229/255, green: 231/255, blue: 235/255).opacity(colorScheme == .dark ? 0.3 : 1.0)
        } else {
            return Color(red: 219/255, green: 234/255, blue: 254/255).opacity(colorScheme == .dark ? 0.3 : 1.0)
        }
    }

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - Pulse Modifier

/// Repeating pulse animation for the recording indicator ring.
struct PulseModifier: ViewModifier {
    let isActive: Bool
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(2.0 - Double(scale))
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    scale = 1.3
                }
            }
            .onChange(of: isActive) { _, newValue in
                if !newValue {
                    scale = 1.0
                }
            }
    }
}

// MARK: - Preview

#Preview("Top Panel — English") {
    TranslationPanelView(
        position: .top,
        language: .english,
        dialect: nil,
        text: "Where is the nearest restaurant?",
        isPartial: false,
        isRecording: false,
        isSpeaking: false,
        audioLevel: 0,
        onMicTap: {},
        onLanguageTap: {},
        onDialectTap: {},
        onTextTap: {}
    )
    .padding()
}

#Preview("Bottom Panel — Arabic") {
    TranslationPanelView(
        position: .bottom,
        language: .arabic,
        dialect: .najdi,
        text: "وين أقرب مطعم؟",
        isPartial: false,
        isRecording: false,
        isSpeaking: false,
        audioLevel: 0,
        onMicTap: {},
        onLanguageTap: {},
        onDialectTap: {},
        onTextTap: {}
    )
    .padding()
}

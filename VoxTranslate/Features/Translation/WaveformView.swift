// WaveformView.swift
// VoxTranslate
//
// Audio waveform visualization driven by microphone audio levels.

import SwiftUI

// MARK: - Waveform View

/// Animated waveform visualization showing live microphone audio levels.
///
/// Displays 5-7 vertical bars whose heights are driven by the current audio level,
/// creating a visual indicator that the app is "listening."
struct WaveformView: View {
    // MARK: - Properties

    /// Current audio level from 0.0 to 1.0.
    let audioLevel: Float

    /// Whether the waveform should be animating.
    let isActive: Bool

    /// Number of bars in the waveform.
    private let barCount = 7

    /// Base height of each bar when idle.
    private let baseHeight: CGFloat = 4

    /// Maximum height of each bar at full volume.
    private let maxHeight: CGFloat = 40

    /// Width of each bar.
    private let barWidth: CGFloat = 4

    /// Spacing between bars.
    private let barSpacing: CGFloat = 3

    // MARK: - Body

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(Color.red.opacity(isActive ? 0.9 : 0.3))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(
                        reduceMotion
                            ? .linear(duration: 0.1)
                            : .easeInOut(duration: 0.1),
                        value: audioLevel
                    )
            }
        }
        .frame(height: maxHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isActive
            ? String(localized: "Audio waveform — recording", comment: "Waveform VoiceOver label")
            : String(localized: "Audio waveform — idle", comment: "Waveform VoiceOver label")
        )
    }

    // MARK: - Bar Height Calculation

    /// Calculates the height of a bar based on its position and the current audio level.
    /// Center bars are taller; edge bars are shorter, creating a natural waveform shape.
    private func barHeight(for index: Int) -> CGFloat {
        guard isActive else { return baseHeight }

        let center = Double(barCount) / 2.0
        let distance = abs(Double(index) - center) / center
        let multiplier = 1.0 - (distance * 0.5) // Center bars are taller

        // Add some variation based on bar index for a more natural look
        let variation = sin(Double(index) * 1.5 + Double(audioLevel) * 10) * 0.3 + 0.7

        let level = CGFloat(audioLevel) * multiplier * variation
        return baseHeight + (maxHeight - baseHeight) * level
    }

    // MARK: - Accessibility

    private var reduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}

// MARK: - Speaker Animation View

/// Animated speaker icon shown during TTS playback.
struct SpeakerAnimationView: View {
    let isPlaying: Bool

    @State private var animationPhase = 0.0

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color("TranslatedText", bundle: nil))
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 20)
        .onAppear {
            guard isPlaying, !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationPhase = 1.0
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if !newValue {
                animationPhase = 0.0
            }
        }
        .accessibilityLabel(String(localized: "Playing translation audio", comment: "Speaker animation label"))
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard isPlaying else { return 8 }
        let offset = Double(index) * 0.3
        let height = 8.0 + sin((animationPhase + offset) * .pi) * 12.0
        return max(4, height)
    }
}

// MARK: - Preview

#Preview("Waveform Active") {
    WaveformView(audioLevel: 0.6, isActive: true)
        .padding()
}

#Preview("Waveform Idle") {
    WaveformView(audioLevel: 0.0, isActive: false)
        .padding()
}

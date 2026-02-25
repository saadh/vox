// PhrasebookView.swift
// VoxTranslate
//
// Saudi travel phrasebook with categorized common phrases and one-tap TTS playback.

import SwiftUI

// MARK: - Phrasebook View

/// Grid of common Saudi travel phrases organized by category,
/// with one-tap TTS playback for instant pronunciation.
struct PhrasebookView: View {
    // MARK: - Properties

    let onPlayPhrase: (Phrase) -> Void

    @State private var categories: [PhraseCategory] = PhrasebookData.defaultCategories
    @State private var selectedCategory: PhraseCategory?
    @State private var playingPhraseId: String?

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Category grid
                    categoryGrid

                    // Phrases for selected category
                    if let category = selectedCategory {
                        phraseList(for: category)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .navigationTitle(String(localized: "Phrasebook", comment: "Phrasebook title"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedCategory == nil, let first = categories.first {
                    selectedCategory = first
                }
            }
        }
    }

    // MARK: - Category Grid

    private var categoryGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ],
            spacing: 12
        ) {
            ForEach(categories) { category in
                Button {
                    HapticManager.shared.selectionChanged()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: category.icon)
                            .font(.system(size: 24))
                            .foregroundStyle(selectedCategory?.id == category.id ? .white : .blue)

                        Text(category.nameEn)
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(selectedCategory?.id == category.id ? .white : .primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedCategory?.id == category.id
                                ? Color.blue
                                : Color(.secondarySystemBackground)
                            )
                    )
                }
                .accessibilityLabel("\(category.nameEn), \(category.nameAr)")
                .accessibilityAddTraits(selectedCategory?.id == category.id ? .isSelected : [])
            }
        }
    }

    // MARK: - Phrase List

    private func phraseList(for category: PhraseCategory) -> some View {
        VStack(spacing: 8) {
            // Category header
            HStack {
                Text(category.nameEn)
                    .font(.system(.headline))

                Spacer()

                Text(category.nameAr)
                    .font(.system(.headline))
                    .environment(\.layoutDirection, .rightToLeft)
            }
            .padding(.top, 8)

            ForEach(category.phrases) { phrase in
                phraseRow(phrase)
            }
        }
    }

    private func phraseRow(_ phrase: Phrase) -> some View {
        Button {
            playingPhraseId = phrase.id
            onPlayPhrase(phrase)

            // Reset playing state after a delay
            Task {
                try? await Task.sleep(for: .seconds(3))
                if playingPhraseId == phrase.id {
                    playingPhraseId = nil
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.english)
                        .font(.system(.body))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    if !phrase.transliteration.isEmpty {
                        Text(phrase.transliteration)
                            .font(.system(.caption))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(phrase.arabic)
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Color(red: 30/255, green: 64/255, blue: 175/255))
                        .multilineTextAlignment(.trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                // Play icon
                Image(systemName: playingPhraseId == phrase.id ? "speaker.wave.2.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(playingPhraseId == phrase.id ? .green : .blue)
                    .symbolEffect(.pulse, isActive: playingPhraseId == phrase.id)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityLabel("\(phrase.english). \(phrase.arabic)")
        .accessibilityHint(String(localized: "Tap to hear pronunciation", comment: "Phrase play hint"))
    }
}

// MARK: - Preview

#Preview("Phrasebook") {
    PhrasebookView(onPlayPhrase: { _ in })
}

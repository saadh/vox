// HistoryView.swift
// VoxTranslate
//
// Conversation history view with RTL-aware rendering.

import SwiftUI

// MARK: - History View

/// Scrollable list of all translation exchanges in the current session.
///
/// Each entry shows source text, translated text, timestamp, and controls for
/// replay, copy, and share. Arabic entries render with proper RTL alignment.
struct HistoryView: View {
    // MARK: - Properties

    let entries: [ConversationEntry]
    let onReplay: (ConversationEntry) -> Void
    let onClear: () -> Void

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .navigationTitle(String(localized: "History", comment: "History view title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "Clear", comment: "Clear history button")) {
                            onClear()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Entry List

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(entries) { entry in
                    HistoryEntryView(
                        entry: entry,
                        onReplay: { onReplay(entry) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No translations yet", comment: "History empty state title")
                .font(.system(.headline))
                .foregroundStyle(.secondary)

            Text("Your translation history will appear here during this session.", comment: "History empty state subtitle")
                .font(.system(.subheadline))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("History — With Entries") {
    HistoryView(
        entries: [
            ConversationEntry(
                sourceText: "Where is the nearest restaurant?",
                sourceLanguage: .english,
                translatedText: "وين أقرب مطعم؟",
                targetLanguage: .arabic,
                dialect: .najdi,
                engineTier: .geminiLive
            ),
            ConversationEntry(
                sourceText: "بكم هذا؟",
                sourceLanguage: .arabic,
                translatedText: "How much is this?",
                targetLanguage: .english,
                dialect: .najdi,
                engineTier: .geminiLive
            )
        ],
        onReplay: { _ in },
        onClear: {}
    )
}

#Preview("History — Empty") {
    HistoryView(
        entries: [],
        onReplay: { _ in },
        onClear: {}
    )
}

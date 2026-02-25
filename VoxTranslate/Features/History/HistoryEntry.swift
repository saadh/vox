// HistoryEntry.swift
// VoxTranslate
//
// Note: The ConversationEntry model is defined in Models/ConversationEntry.swift.
// This file provides the history entry view component.

import SwiftUI

// MARK: - History Entry View

/// A single row in the conversation history, showing source text, translated text,
/// timestamp, and replay/copy/share controls. RTL-aware for Arabic entries.
struct HistoryEntryView: View {
    // MARK: - Properties

    let entry: ConversationEntry
    let onReplay: () -> Void

    @State private var showCopied = false

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Timestamp and engine tier
            HStack {
                Text(entry.formattedTime)
                    .font(.system(.caption2))
                    .foregroundStyle(.tertiary)

                Spacer()

                Text(entry.engineTier.displayName)
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            // Source text
            HStack {
                Text(entry.sourceLanguage.flagEmoji)
                    .font(.caption)

                Text(entry.sourceText)
                    .font(.system(.body))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(entry.isSourceRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, entry.isSourceRTL ? .rightToLeft : .leftToRight)
                    .frame(maxWidth: .infinity, alignment: entry.isSourceRTL ? .trailing : .leading)
            }

            // Translated text
            HStack {
                Text(entry.targetLanguage.flagEmoji)
                    .font(.caption)

                Text(entry.translatedText)
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color(red: 30/255, green: 64/255, blue: 175/255))
                    .multilineTextAlignment(entry.isTargetRTL ? .trailing : .leading)
                    .environment(\.layoutDirection, entry.isTargetRTL ? .rightToLeft : .leftToRight)
                    .frame(maxWidth: .infinity, alignment: entry.isTargetRTL ? .trailing : .leading)
            }

            // Dialect badge if applicable
            if let dialect = entry.dialect {
                Text("\(dialect.flagEmoji) \(dialect.badgeLabel)")
                    .font(.system(.caption2, weight: .medium))
                    .foregroundStyle(Color(red: 4/255, green: 120/255, blue: 87/255))
            }

            // Action buttons
            HStack(spacing: 16) {
                Spacer()

                // Replay button
                Button(action: onReplay) {
                    Label(
                        String(localized: "Replay", comment: "History replay button"),
                        systemImage: "play.fill"
                    )
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.blue)
                }

                // Copy button
                Button {
                    UIPasteboard.general.string = entry.translatedText
                    showCopied = true
                    HapticManager.shared.selectionChanged()

                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        showCopied = false
                    }
                } label: {
                    Label(
                        showCopied
                            ? String(localized: "Copied!", comment: "Copy confirmation")
                            : String(localized: "Copy", comment: "History copy button"),
                        systemImage: showCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(showCopied ? .green : .blue)
                }

                // Share button
                ShareLink(item: entry.shareableText) {
                    Label(
                        String(localized: "Share", comment: "History share button"),
                        systemImage: "square.and.arrow.up"
                    )
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("History Entry — English to Arabic") {
    HistoryEntryView(
        entry: ConversationEntry(
            sourceText: "Where is the nearest restaurant?",
            sourceLanguage: .english,
            translatedText: "وين أقرب مطعم؟",
            targetLanguage: .arabic,
            dialect: .najdi,
            engineTier: .geminiLive
        ),
        onReplay: {}
    )
    .padding()
}

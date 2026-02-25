// DialectSelectorView.swift
// VoxTranslate
//
// Arabic dialect picker for selecting the target dialect variant.

import SwiftUI

// MARK: - Dialect Selector View

/// Half-sheet modal for selecting an Arabic dialect variant.
///
/// Groups dialects by region with visual indicators for Saudi dialects.
struct DialectSelectorView: View {
    // MARK: - Properties

    let selectedDialect: ArabicDialect
    let onSelect: (ArabicDialect) -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Saudi dialects section
                Section {
                    ForEach(saudiDialects, id: \.self) { dialect in
                        dialectRow(dialect)
                    }
                } header: {
                    Text("Saudi Arabia", comment: "Dialect section header")
                }

                // Other Arabic dialects section
                Section {
                    ForEach(otherDialects, id: \.self) { dialect in
                        dialectRow(dialect)
                    }
                } header: {
                    Text("Other Dialects", comment: "Dialect section header")
                }

                // MSA section
                Section {
                    dialectRow(.msa)
                } header: {
                    Text("Formal", comment: "Dialect section header")
                }
            }
            .navigationTitle(String(localized: "Arabic Dialect", comment: "Dialect selector title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Dialect Row

    private func dialectRow(_ dialect: ArabicDialect) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            onSelect(dialect)
        } label: {
            HStack(spacing: 12) {
                Text(dialect.flagEmoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dialect.englishName)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(dialect.arabicName)
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                Spacer()

                if dialect == selectedDialect {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(dialect.englishName), \(dialect.arabicName)")
        .accessibilityAddTraits(dialect == selectedDialect ? .isSelected : [])
    }

    // MARK: - Dialect Grouping

    private var saudiDialects: [ArabicDialect] {
        [.najdi, .hijazi, .gulf]
    }

    private var otherDialects: [ArabicDialect] {
        [.egyptian, .levantine, .moroccan]
    }
}

// MARK: - Preview

#Preview("Dialect Selector") {
    DialectSelectorView(
        selectedDialect: .najdi,
        onSelect: { _ in }
    )
}

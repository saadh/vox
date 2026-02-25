// LanguageSelectorView.swift
// VoxTranslate
//
// Language picker half-sheet with search and dialect sub-selector.

import SwiftUI

// MARK: - Language Selector View

/// Half-sheet modal for selecting a language, with search filtering,
/// recently used section, and alphabetical listing.
struct LanguageSelectorView: View {
    // MARK: - Properties

    let selectedLanguage: LanguageCode
    let languages: [LanguageCode]
    let recentLanguages: [LanguageCode]
    let onSelect: (LanguageCode) -> Void

    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Recently used section
                if !recentLanguages.isEmpty && searchText.isEmpty {
                    Section {
                        ForEach(recentLanguages) { language in
                            languageRow(language)
                        }
                    } header: {
                        Text("Recently Used", comment: "Language selector section header")
                    }
                }

                // All languages section
                Section {
                    ForEach(filteredLanguages) { language in
                        languageRow(language)
                    }
                } header: {
                    if searchText.isEmpty {
                        Text("All Languages", comment: "Language selector section header")
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt: String(localized: "Search languages", comment: "Language search placeholder")
            )
            .navigationTitle(String(localized: "Select Language", comment: "Language selector title"))
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

    // MARK: - Language Row

    private func languageRow(_ language: LanguageCode) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            onSelect(language)
        } label: {
            HStack(spacing: 12) {
                Text(language.flagEmoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(language.englishName)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)

                    if language.nativeName != language.englishName {
                        Text(language.nativeName)
                            .font(.system(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if language.id == selectedLanguage.id {
                    Image(systemName: "checkmark")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(language.englishName), \(language.nativeName)")
        .accessibilityAddTraits(language.id == selectedLanguage.id ? .isSelected : [])
    }

    // MARK: - Filtering

    private var filteredLanguages: [LanguageCode] {
        guard !searchText.isEmpty else { return languages }

        let query = searchText.lowercased()
        return languages.filter { language in
            language.englishName.lowercased().contains(query) ||
            language.nativeName.lowercased().contains(query) ||
            language.id.lowercased().contains(query)
        }
    }
}

// MARK: - Preview

#Preview("Language Selector") {
    LanguageSelectorView(
        selectedLanguage: .english,
        languages: LanguageCode.allWithAutoDetect,
        recentLanguages: [.english, .arabic, .french],
        onSelect: { _ in }
    )
}

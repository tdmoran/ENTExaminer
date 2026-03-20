import SwiftUI

struct ArchiveView: View {
    @Environment(AppState.self) private var appState

    private var archivedDocuments: [LibraryDocument] {
        appState.libraryDocuments
            .filter(\.isArchived)
            .sorted { $0.addedDate > $1.addedDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            if archivedDocuments.isEmpty {
                emptyState
            } else {
                archiveContent
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Archived Documents",
            systemImage: "archivebox",
            description: Text("Documents you archive will appear here. You can restore them at any time.")
        )
    }

    private var archiveContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Archived Documents")
                    .font(.headline)
                Spacer()
                Text("\(archivedDocuments.count) document\(archivedDocuments.count == 1 ? "" : "s")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(archivedDocuments) { doc in
                        archivedDocumentRow(doc)
                    }
                }
                .padding(20)
            }
        }
    }

    private func archivedDocumentRow(_ document: LibraryDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: document.formatIcon)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.callout)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Text(document.format.displayName)
                    Text("·")
                    Text(document.fileSizeFormatted)
                    if document.examCount > 0 {
                        Text("·")
                        Text("\(document.examCount) exams")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Restore") {
                Task { await appState.restoreDocument(document) }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                Task { await appState.deleteDocument(document) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

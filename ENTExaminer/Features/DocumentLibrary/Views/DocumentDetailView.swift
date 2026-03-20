import SwiftUI

struct DocumentDetailView: View {
    @Environment(AppState.self) private var appState
    let document: LibraryDocument

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                contentPreviewSection
                analysisSection
                examHistorySection
                actionSection
            }
            .padding(32)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 16) {
            Image(systemName: document.formatIcon)
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(document.title)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 12) {
                    Label(document.format.displayName, systemImage: "doc")
                    Label(document.fileSizeFormatted, systemImage: "internaldrive")
                    if let pages = document.pageCount {
                        Label("\(pages) pages", systemImage: "book.pages")
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label("Added \(document.addedDate, style: .date)", systemImage: "calendar")
                    if document.examCount > 0 {
                        Label("Examined \(document.examCount) time\(document.examCount == 1 ? "" : "s")", systemImage: "checkmark.circle")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()
        }
    }

    // MARK: - Content Preview

    private var contentPreviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content Preview")
                .font(.headline)

            if let parsedDoc = appState.document, !parsedDoc.text.isEmpty {
                ScrollView {
                    Text(String(parsedDoc.text.prefix(2000)))
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            } else if !document.contentPreview.isEmpty {
                Text(document.contentPreview)
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Analysis

    private var analysisSection: some View {
        Group {
            if case .analyzing = appState.currentPhase {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Analyzing document...")
                        .foregroundStyle(.secondary)
                }
            } else if let analysis = appState.analysis {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Analysis Complete", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.headline)

                    Text(analysis.documentSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)

                    HStack(spacing: 16) {
                        Label("\(analysis.topics.count) topics", systemImage: "list.bullet")
                        Label("~\(analysis.suggestedQuestionCount) questions", systemImage: "questionmark.circle")
                        Label("~\(analysis.estimatedDurationMinutes) min", systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    FlowLayout(spacing: 6) {
                        ForEach(analysis.topics) { topic in
                            Text(topic.name)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1), in: Capsule())
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Exam History

    private var examHistorySection: some View {
        Group {
            if document.examCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examination History")
                        .font(.headline)

                    if let lastDate = document.lastExaminedDate {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.secondary)
                            Text("Last examined \(lastDate, style: .relative) ago")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("\(document.examCount) session\(document.examCount == 1 ? "" : "s") completed")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        HStack(spacing: 12) {
            if appState.analysis == nil {
                Button("Analyze Document") {
                    Task { await appState.analyzeDocument() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(appState.currentPhase == .analyzing)
            } else {
                Button("Begin Examination") {
                    Task { await appState.startConversation() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Button("Back to Library") {
                appState.selectedSection = .library
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

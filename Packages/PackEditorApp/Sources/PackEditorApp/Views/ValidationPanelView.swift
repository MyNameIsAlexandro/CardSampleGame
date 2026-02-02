import SwiftUI
import PackAuthoring
import PackEditorKit

struct ValidationPanelView: View {
    @EnvironmentObject var tab: EditorTab

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            headerBar
            issueList
        }
        .frame(minHeight: 120, maxHeight: 300)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Label("Validation", systemImage: "checkmark.shield")
                .font(.headline)

            if let summary = tab.validationSummary {
                if summary.errorCount > 0 {
                    Label("\(summary.errorCount) errors", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                if summary.warningCount > 0 {
                    Label("\(summary.warningCount) warnings", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.subheadline)
                }
                if summary.errorCount == 0 && summary.warningCount == 0 {
                    Label("No issues", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }

            Spacer()

            Button {
                tab.showValidation = false
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    // MARK: - Issue List

    @ViewBuilder
    private var issueList: some View {
        if let summary = tab.validationSummary {
            let issues = summary.results.filter { $0.severity != .info }
            if issues.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("No issues found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(Array(issues.enumerated()), id: \.offset) { _, result in
                    HStack(spacing: 8) {
                        severityIcon(result.severity)
                        Text(result.category)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .leading)
                        Text(entityId(from: result.message))
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 140, alignment: .leading)
                            .lineLimit(1)
                        Text(result.message)
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        navigateToIssue(result)
                    }
                }
                .listStyle(.plain)
            }
        } else {
            VStack {
                Spacer()
                Text("Run validation to see results")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Helpers

    private func severityIcon(_ severity: PackValidator.Severity) -> some View {
        switch severity {
        case .error:
            return Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .warning:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
        case .info:
            return Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
        }
    }

    /// Extract entity ID from validation message (pattern: 'entity_id')
    private func entityId(from message: String) -> String {
        guard let start = message.firstIndex(of: "'"),
              let end = message[message.index(after: start)...].firstIndex(of: "'") else {
            return ""
        }
        return String(message[message.index(after: start)..<end])
    }

    /// Navigate to the entity referenced by a validation result
    private func navigateToIssue(_ result: PackValidator.ValidationResult) {
        let id = entityId(from: result.message)
        guard !id.isEmpty else { return }

        let category = categoryForValidation(result.category)
        if let category {
            tab.selectedCategory = category
            tab.selectedEntityId = id
        }
    }

    private func categoryForValidation(_ validationCategory: String) -> ContentCategory? {
        switch validationCategory {
        case "Region": return .regions
        case "Event": return .events
        case "Hero": return .heroes
        case "Card": return .cards
        case "Enemy": return .enemies
        case "Anchor": return .anchors
        case "Balance": return .balance
        case "Reference":
            return nil // cross-reference issues don't map to a single category
        default: return nil
        }
    }
}

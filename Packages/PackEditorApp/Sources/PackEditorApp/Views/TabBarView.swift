import SwiftUI

struct TabBarView: View {
    @EnvironmentObject var state: PackEditorState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Pack Browser button (always first, non-closable)
                Button {
                    state.showPackBrowser()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "house")
                        Text("Pack Browser")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(state.showBrowser ? Color.accentColor.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)

                // Open tabs
                ForEach(state.tabs) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    @ViewBuilder
    private func tabButton(for tab: EditorTab) -> some View {
        let isActive = !state.showBrowser && state.activeTabId == tab.id
        Button {
            state.switchToTab(tab)
        } label: {
            HStack(spacing: 4) {
                if tab.store.isDirty {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                }
                Text(tab.store.packTitle)
                    .lineLimit(1)

                Button {
                    state.closeTab(tab)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

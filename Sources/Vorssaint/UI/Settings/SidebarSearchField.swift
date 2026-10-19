import SwiftUI

/// A floating field without a full-width header or divider. Keyboard focus,
/// clear and Escape use the same query as the sidebar’s search results.
struct SidebarSearchField: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(l10n.s.settingsSearchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .focused(isFocused)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                    isFocused.wrappedValue = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.urlCleanerClearButton)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background { surface }
        .overlay {
            Capsule().strokeBorder(isFocused.wrappedValue ? Color.accentColor.opacity(0.55)
                                   : Color.primary.opacity(hovered ? 0.12 : 0.06), lineWidth: 1)
        }
        .shadow(color: .black.opacity(hovered ? 0.13 : 0.07), radius: hovered ? 7 : 4, y: 2)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var surface: some View {
        if reduceTransparency {
            Capsule().fill(Color(nsColor: .controlBackgroundColor))
        } else {
#if compiler(>=6.2)
            if #available(macOS 26, *), liquidGlassEnabled {
                Capsule().fill(.clear).glassEffect(.regular, in: Capsule())
            } else {
                Capsule().fill(.ultraThinMaterial)
            }
#else
            Capsule().fill(.ultraThinMaterial)
#endif
        }
    }
}

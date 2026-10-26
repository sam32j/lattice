import SwiftUI

/// The window previews card on the Switcher and Dock pages: each page has its
/// own preview size and paused apps, while the minimal look is shared.
struct WindowPreviewsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @AppStorage private var previewSize: String
    private let excludedAppsKey: String
    let embedded: Bool
    let showsExclusions: Bool
    let showsMinimalPreview: Bool

    init(sizeKey: String, excludedAppsKey: String, embedded: Bool = false, showsExclusions: Bool = true, showsMinimalPreview: Bool = true) {
        _previewSize = AppStorage(wrappedValue: "normal", sizeKey)
        self.excludedAppsKey = excludedAppsKey
        self.embedded = embedded
        self.showsExclusions = showsExclusions
        self.showsMinimalPreview = showsMinimalPreview
    }

    var body: some View {
        if embedded {
            controls
        } else {
            SettingsCard(title: FeatureStrings.windowPreviewExclusions(l10n.language).sectionTitle) { controls }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.s.previewSizeLabel)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    sizeChoice("small", title: l10n.s.previewSizeSmall, scale: 0.5)
                    sizeChoice("normal", title: l10n.s.previewSizeNormal, scale: 0.66)
                    sizeChoice("large", title: l10n.s.previewSizeLarge, scale: 0.83)
                    sizeChoice("xlarge", title: l10n.s.previewSizeXLarge, scale: 1)
                }
            }
            if showsMinimalPreview {
                SettingsRow(symbol: "rectangle.dashed", title: l10n.s.minimalWindowPreviews,
                            caption: l10n.s.minimalWindowPreviewsCaption) {
                    Toggle(l10n.s.minimalWindowPreviews, isOn: $minimalPreviews).labelsHidden()
                }
            }
            if showsExclusions { WindowPreviewExclusionsList(key: excludedAppsKey) }
        }
    }

    /// A preview thumbnail drawn at the size it stands for.
    private func sizeChoice(_ value: String, title: String, scale: CGFloat) -> some View {
        let selected = previewSize == value
        return Button {
            previewSize = value
            AppSwitcher.shared.syncWithPreferences()
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.35) : Color.secondary.opacity(0.3))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(selected ? Color.accentColor : Color.secondary.opacity(0.6))
                            .frame(height: 4)
                            .padding(3)
                    }
                    .frame(width: 60 * scale, height: 42 * scale)
                    .frame(height: 42)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}


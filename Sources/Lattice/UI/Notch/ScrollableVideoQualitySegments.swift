// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

/// Keep the existing selector's footprint while exposing quality choices without text clipping or font jiggle.
struct ScrollableVideoQualitySegments<Segment: View>: View {
    let info: VideoDownloadInfo
    var selectedQuality: VideoDownloadQuality? = nil
    let spacing: CGFloat
    var viewportWidth: CGFloat = 168
    @ViewBuilder let segment: (VideoDownloadQuality) -> Segment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentWidth: CGFloat = 0

    private var options: [VideoDownloadQuality] {
        info.qualities + (info.hasAudio ? [.audio] : [])
    }

    private var scrollTargetQuality: VideoDownloadQuality? {
        guard let selectedQuality else { return options.first }
        if selectedQuality.isBest {
            return options.first
        }
        return options.contains(selectedQuality) ? selectedQuality : options.first
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(options, id: \.self) { quality in
                        segment(quality)
                            .id(quality)
                    }
                }
                .padding(.horizontal, 2)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: QualityContentWidthKey.self, value: geo.size.width)
                    }
                )
            }
            .frame(width: contentWidth > 0 ? min(contentWidth, viewportWidth) : nil)
            .frame(maxWidth: viewportWidth)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onPreferenceChange(QualityContentWidthKey.self) { width in
                if width > 0 && width != contentWidth {
                    contentWidth = width
                }
            }
            .onAppear {
                scrollToTarget(proxy: proxy, animated: false)
            }
            .onChange(of: selectedQuality) { _, _ in
                scrollToTarget(proxy: proxy, animated: true)
            }
            .onChange(of: info) { _, _ in
                scrollToTarget(proxy: proxy, animated: false)
            }
        }
    }

    private func scrollToTarget(proxy: ScrollViewProxy, animated: Bool) {
        guard let target = scrollTargetQuality else { return }
        DispatchQueue.main.async {
            if animated && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(target, anchor: .center)
                }
            } else {
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}

private struct QualityContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

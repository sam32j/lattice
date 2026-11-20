import AppKit
import SwiftUI

/// Renders the production page and mixer compositions with inert controls.
/// Device I/O is excluded; the observed boundary is which controls each page owns.
enum AudioSettingsOwnershipTests {
    struct TextCatalog { let s = Strings.enUS; let language = AppLanguage.enUS }
    struct InputPage: View {
        typealias AudioInputMuteCard = AudioSettingsOwnershipTests.AudioInputMuteCard
        typealias AudioInputDeviceControls = AudioSettingsOwnershipTests.AudioInputDeviceControls
        typealias AudioInputPriorityControls = AudioSettingsOwnershipTests.AudioInputPriorityControls
        typealias SettingsCard<C: View> = AudioSettingsOwnershipTests.SettingsCard<C>
        let l10n = TextCatalog()
        let microphoneControlEnabled = true
        struct PriorityStub { let inputPriorityEnabled = false }
        let priority = PriorityStub()
        var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(.enUS) }
        var microphoneCard: some View {
            VStack {
                AudioInputDeviceControls()
                AudioInputMuteCard()
            }
        }
        var inputPriorityCard: some View {
            AudioInputPriorityControls()
        }
    }
    struct OutputPage: View {
        let outputSwitcherEnabled = false
        let volumeMixerEnabled = true
        let lowerOnHeadphonesDisconnect = false
        typealias MixerSection = AudioSettingsOwnershipTests.MixerSection
        typealias MusicBlockingSettings = AudioSettingsOwnershipTests.MusicBlockingSettings
        typealias AudioOutputPriorityControls = AudioSettingsOwnershipTests.AudioOutputPriorityControls
        typealias SettingsCard<C: View> = AudioSettingsOwnershipTests.SettingsCard<C>
        let l10n = TextCatalog()
        let microphoneControlEnabled = true
        struct PriorityStub {
            let inputPriorityEnabled = false
            let outputPriorityEnabled = false
        }
        let priority = PriorityStub()
        var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(.enUS) }
        var soundOutputSwitcherCard: some View { Marker(name: "output-picker") }
        var outputPriorityAndSwitcherCard: some View {
            VStack {
                AudioOutputPriorityControls()
                soundOutputSwitcherCard
            }
        }
    }
    struct AudioInputDeviceControls: View {
        var title: String? = nil
        var sliderWidth: CGFloat = 164
        var showsUnavailableLabel = false
        var body: some View { Marker(name: "microphone") }
    }
    struct AudioInputMuteCard: View { var body: some View { Marker(name: "mute") } }
    struct AudioInputPriorityControls: View { var body: some View { Marker(name: "input-priority") } }
    struct AudioOutputPriorityControls: View { var body: some View { Marker(name: "output-priority") } }
    struct MusicBlockingSettings: View { var body: some View { Marker(name: "music-blocking") } }
    struct MixerSection: View {
        let settingsMode: Bool
        var body: some View { Marker(name: "output-picker") }
    }
    struct SettingsCard<Content: View>: View {
        let content: Content
        init(title: String? = nil, @ViewBuilder content: () -> Content) { self.content = content() }
        init<Accessory: View>(title: String? = nil, @ViewBuilder headerAccessory: () -> Accessory, @ViewBuilder content: () -> Content) { self.content = content() }
        var body: some View { content }
    }
    private final class MarkerView: NSView { var name = "" }
    struct Marker: NSViewRepresentable {
        let name: String
        func makeNSView(context: Context) -> NSView {
            let view = MarkerView()
            view.name = name
            return view
        }
        func updateNSView(_ view: NSView, context: Context) {}
    }

    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let keys = [AppFeature.mixer, .audioPriority, .micMute, .musicBlock, .soundOutputSwitcher].map(\.availabilityKey)
        let prior = keys.map { defaults.object(forKey: $0) }
        keys.forEach { defaults.set(true, forKey: $0) }
        defer {
            for (key, value) in zip(keys, prior) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        func markers<V: View>(_ root: V) -> Set<String> {
            let host = NSHostingView(rootView: root)
            host.frame = NSRect(x: 0, y: 0, width: 560, height: 900)
            host.layoutSubtreeIfNeeded()
            func names(_ view: NSView) -> [String] {
                (view as? MarkerView).map { [$0.name] } ?? view.subviews.flatMap(names)
            }
            return Set(names(host))
        }
        let input = markers(InputPage())
        let output = markers(OutputPage())
        suite.expect(input.contains("microphone") && input.contains("input-priority")
                     && !input.contains("output-priority") && !input.contains("combined-priority"),
                     "rendered Audio Input owns microphone controls and only input priority: \(input)")
        suite.expect(output.contains("output-priority") && output.contains("output-picker")
                     && !output.contains("microphone") && !output.contains("input-priority"),
                     "rendered Audio Output owns output priority without microphone controls: \(output)")
    }
}

extension View {
    func settingsSectionAnchor(_ anchor: SettingsSectionAnchor, cornerRadius: CGFloat) -> some View { self }
}

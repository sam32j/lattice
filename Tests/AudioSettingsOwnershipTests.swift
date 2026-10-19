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
        typealias AudioPriorityDisclosure = AudioSettingsOwnershipTests.AudioPriorityDisclosure
        typealias SettingsCard<C: View> = AudioSettingsOwnershipTests.SettingsCard<C>
        let l10n = TextCatalog()
        var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(.enUS) }
    }
    struct OutputPage: View {
        typealias MixerSection = AudioSettingsOwnershipTests.MixerSection
        typealias MusicBlockingSettings = AudioSettingsOwnershipTests.MusicBlockingSettings
        typealias AudioOutputPriorityControls = AudioSettingsOwnershipTests.AudioOutputPriorityControls
        typealias SettingsCard<C: View> = AudioSettingsOwnershipTests.SettingsCard<C>
        let l10n = TextCatalog()
        var pageStrings: SettingsPageStrings { FeatureStrings.settingsPages(.enUS) }
        var soundOutputSwitcherCard: some View { Marker(name: "output-picker") }
    }
    struct MixerDevices: View {
        typealias AudioInputDeviceControls = AudioSettingsOwnershipTests.AudioInputDeviceControls
        let l10n = TextCatalog()
        let settingsMode: Bool
        struct Mixer { let outputSwitchError: String? = nil }
        let mixer = Mixer()
        var universalOutputPicker: some View { Marker(name: "output-picker") }
        var systemSoundOutputPicker: some View { Marker(name: "system-sounds") }
        var microphonePicker: some View { Marker(name: "microphone") }
        var body: some View { audioDevicesSection }
        func inputMessage(_ text: String, systemImage: String) -> some View { Text(text) }
    }
    struct AudioInputDeviceControls: View { var body: some View { Marker(name: "microphone") } }
    struct AudioInputMuteCard: View { var body: some View { Marker(name: "mute") } }
    struct AudioInputPriorityControls: View { var body: some View { Marker(name: "input-priority") } }
    struct AudioOutputPriorityControls: View { var body: some View { Marker(name: "output-priority") } }
    struct AudioPriorityDisclosure: View {
        var initiallyExpanded = false
        var showsHeader = true
        var body: some View { Marker(name: "combined-priority") }
    }
    struct MusicBlockingSettings: View { var body: some View { Marker(name: "music-blocking") } }
    struct MixerSection: View {
        let settingsMode: Bool
        var body: some View { MixerDevices(settingsMode: settingsMode) }
    }
    struct SettingsCard<Content: View>: View {
        let content: Content
        init(title: String? = nil, @ViewBuilder content: () -> Content) { self.content = content() }
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
        suite.expect(markers(MixerDevices(settingsMode: false)).contains("microphone"),
                     "the menu panel retains shared microphone controls")
    }
}

extension View {
    func settingsSectionAnchor(_ anchor: SettingsSectionAnchor, cornerRadius: CGFloat) -> some View { self }
}

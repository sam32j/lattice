import SwiftUI

struct AudioOutputPriorityControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var priority = AudioPriorityService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                AudioPriorityHeader(title: l10n.s.audioPriorityOutputList,
                                    symbol: "speaker.wave.2.fill",
                                    enabled: Binding(get: { priority.outputPriorityEnabled },
                                                     set: { priority.setOutputPriorityEnabled($0) }),
                                    help: l10n.s.audioPriorityOutputEnable)
            }
            PriorityDeviceList(priorityUIDs: priority.outputPriorityUIDs,
                               isAvailable: priority.isOutputAvailable,
                               displayName: priority.displayName,
                               currentUID: mixer.currentOutputDeviceUID,
                               emptyText: l10n.s.mixerSystemOutputNoDevices,
                               onMove: { priority.setOutputPriorityUIDs($0) })
        }
    }
}

struct AudioInputPriorityControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var priority = AudioPriorityService.shared
    @ObservedObject private var input = AudioInputDeviceManager.shared
    var showsHeader = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                AudioPriorityHeader(title: l10n.s.audioPriorityInputList,
                                    symbol: "mic.fill",
                                    enabled: Binding(get: { priority.inputPriorityEnabled },
                                                     set: { priority.setInputPriorityEnabled($0) }),
                                    help: l10n.s.audioPriorityInputEnable)
            }
            PriorityDeviceList(priorityUIDs: priority.inputPriorityUIDs,
                               isAvailable: priority.isInputAvailable,
                               displayName: priority.displayName,
                               currentUID: input.currentInputDeviceUID,
                               emptyText: l10n.s.mixerInputNoDevices,
                               onMove: { priority.setInputPriorityUIDs($0) })
        }
    }
}

private struct AudioPriorityHeader: View {
    let title: String
    let symbol: String
    @Binding var enabled: Bool
    let help: String

    var body: some View {
        HStack(spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Toggle(help, isOn: $enabled)
                .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                .help(help).accessibilityLabel(help)
        }
    }
}

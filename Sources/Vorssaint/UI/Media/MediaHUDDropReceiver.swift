import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaHUDDropReceiver: NSViewRepresentable {
    let canAccept: (NSPasteboard) -> Bool
    let accept: (NSDraggingInfo) -> Bool
    let targeted: (Bool) -> Void
    func makeNSView(context: Context) -> Receiver { Receiver() }
    func updateNSView(_ view: Receiver, context: Context) {
        view.canAccept = canAccept; view.accept = accept; view.targeted = targeted
    }
    final class Receiver: NSView {
        var canAccept: (NSPasteboard) -> Bool = { _ in false }
        var accept: (NSDraggingInfo) -> Bool = { _ in false }
        var targeted: (Bool) -> Void = { _ in }
        override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL, .URL, NSPasteboard.PasteboardType("NSFilenamesPboardType")]) }
        required init?(coder: NSCoder) { fatalError() }
        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            let accepts = canAccept(sender.draggingPasteboard); targeted(accepts)
            return accepts ? .copy : []
        }
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
        override func draggingExited(_ sender: NSDraggingInfo?) { targeted(false) }
        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            defer { targeted(false) }
            return canAccept(sender.draggingPasteboard) && accept(sender)
        }
    }
}

enum MediaHUDDialogs {
    private static weak var activePanel: NSOpenPanel?
    static func cancelActiveDialog() { activePanel?.cancel(nil) }
    static func run(_ panel: NSOpenPanel, complete: @escaping (NSApplication.ModalResponse) -> Void) {
        guard !MediaWorkspaceView.panelModalActive else { return }
        MediaWorkspaceView.panelModalActive = true
        activePanel = panel
        let island = NotchService.shared.presentationWindow
        if let island, island.isVisible, NSApp.currentEvent?.window === island || NSApp.keyWindow === island {
            panel.level = NSWindow.Level(rawValue: island.level.rawValue + 1)
        }
        panel.hidesOnDeactivate = false
        panel.begin { response in
            activePanel = nil
            MediaWorkspaceView.panelModalActive = false
            complete(response)
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

import AppKit
import Combine
import Foundation

extension KeepAwakeManager {
    func startPreferenceObservation() {
        guard defaultsObserver == nil else { return }
        refreshPasswordlessStatus()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.syncWithPreferences()
        }
        // Every settings write announces itself, including the ones made from
        // inside this class, so a burst folds into a single reply on the next
        // turn of the run loop rather than one full pass per write.
        defaultsObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self, !self.preferenceSyncScheduled else { return }
                self.preferenceSyncScheduled = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.preferenceSyncScheduled = false
                    self.syncWithPreferences()
                }
            }
    }
    func stopPreferenceObservation() {
        defaultsObserver = nil
        preferenceSyncScheduled = false
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }
}

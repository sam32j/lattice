import SwiftUI

struct AppUpdatesSettings: View {
    @ObservedObject private var updates = AppUpdatesService.shared

    var body: some View {
        ScrollView {
            AppUpdatesListView().padding(16)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear { updates.checkIfNeeded() }
    }
}

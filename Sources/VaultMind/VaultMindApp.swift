import AppKit
import SwiftUI
import VaultMindCore
import VaultMindUI

@main
struct VaultMindApp: App {
    @State private var appState: VaultAppState
    @State private var hudController: FloatingVaultHUD?

    init() {
        let store = try? VaultStore()
        let state = VaultAppState(store: store, isPreviewSnapshot: false)
        _appState = State(initialValue: state)
        _hudController = State(initialValue: FloatingVaultHUD(state: state))
    }

    var body: some Scene {
        MenuBarExtra {
            RootVaultView(state: appState, width: 510)
                .task {
                    await appState.bootstrap()
                }
        } label: {
            Image(systemName: "brain.head.profile")
        }
        .menuBarExtraStyle(.window)
    }
}

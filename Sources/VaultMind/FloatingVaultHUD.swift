import AppKit
@preconcurrency import Carbon
import SwiftUI
import VaultMindUI

private enum VaultHotKeyTrampoline {
    nonisolated(unsafe) static var handler: (@Sendable () -> Void)?
}

private func vaultHotKeyCallback(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    VaultHotKeyTrampoline.handler?()
    return noErr
}

@MainActor
final class FloatingVaultHUD {
    private var panel: NSPanel?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let state: VaultAppState

    init(state: VaultAppState) {
        self.state = state
        registerGlobalHotKey()
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        if panel == nil {
            let hosting = NSHostingView(rootView: RootVaultView(state: state, width: 525))
            let newPanel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 525, height: 615),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.isFloatingPanel = true
            newPanel.level = .floating
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            newPanel.isMovableByWindowBackground = true
            newPanel.contentView = hosting
            panel = newPanel
        }

        guard let panel else { return }
        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let x = visible.midX - size.width / 2
            let y = visible.maxY - size.height - 90
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func registerGlobalHotKey() {
        VaultHotKeyTrampoline.handler = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggle()
            }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            vaultHotKeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // Option + Shift + B (completes non-overlapping suite: ⌥Space, ⌥⇧M, ⌥⇧K, ⌥⇧P, ⌥⇧B)
        let hotKeyID = EventHotKeyID(signature: OSType(0x564D4E44), id: 1) // "VMND"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_B),
            UInt32(optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

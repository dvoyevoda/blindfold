import AppKit
import SwiftUI

@MainActor
final class CleaningDisplays {
    private var covers: [NSWindow] = []
    private var statusPanel: NSPanel?

    func show(on screens: [NSScreen], statusScreen: NSScreen?, controller: CleaningController) {
        let collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary,
        ]
        covers = screens.map { screen in
            let cover = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            cover.isReleasedWhenClosed = false
            cover.backgroundColor = .black
            cover.level = .screenSaver
            cover.collectionBehavior = collectionBehavior
            cover.ignoresMouseEvents = true
            cover.orderFrontRegardless()
            return cover
        }

        guard let screen = statusScreen ?? screens.first else { return }
        let width = min(380, screen.frame.width)
        let panel = NSPanel(
            contentRect: NSRect(x: screen.frame.midX - width / 2, y: screen.frame.minY + 36, width: width, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .black
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = collectionBehavior
        panel.ignoresMouseEvents = controller.options.contains(.pointer)
        panel.contentView = NSHostingView(rootView: DisplayStatusView(controller: controller))
        statusPanel = panel
        panel.orderFrontRegardless()
    }

    func close() {
        statusPanel?.close()
        statusPanel = nil
        covers.forEach { $0.close() }
        covers.removeAll()
    }
}

private struct DisplayStatusView: View {
    @ObservedObject var controller: CleaningController

    var body: some View {
        VStack(spacing: 8) {
            if let status = controller.cleaningStatus {
                Text("Blindfold · \(status)")
                    .font(.system(.body, design: .monospaced, weight: .medium))
            }
            Text(controller.escapeHint)
                .font(.callout)
                .foregroundStyle(.secondary)
            if !controller.options.contains(.pointer) {
                Button("End Cleaning", action: controller.stop)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(.dark)
    }
}

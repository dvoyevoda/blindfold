import AppKit
import SwiftUI

@main
struct BlindfoldApp: App {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var controller = CleaningController()

    var body: some Scene {
        Window("Blindfold", id: "cleaning") {
            CleaningView(controller: controller)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Blindfold") { openWindow(id: "about") }
            }
        }

        Window("About Blindfold", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

struct BlindfoldIcon: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            BlindfoldIcon(size: 88)
            Text("Blindfold").font(.title2.weight(.semibold))
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("Version \(version)").foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Link("@dvoyevoda", destination: URL(string: "https://github.com/dvoyevoda")!)
                Text("·").foregroundStyle(.secondary)
                if let license = Bundle.main.url(forResource: "LICENSE", withExtension: "txt") {
                    Button("MIT License") { NSWorkspace.shared.open(license) }
                        .buttonStyle(.link)
                }
            }
            .font(.callout)
        }
        .frame(width: 275)
        .padding(24)
    }
}

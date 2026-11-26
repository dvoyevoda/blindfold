import AppKit
import Combine
import SwiftUI

struct CleaningView: View {
    @ObservedObject var controller: CleaningController

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(CleaningPreferences.pauseKeyboard) private var pauseKeyboard = true
    @AppStorage(CleaningPreferences.turnOffKeyboardBacklight) private var turnOffKeyboardBacklight = true
    @AppStorage(CleaningPreferences.pausePointer) private var pausePointer = true
    @AppStorage(CleaningPreferences.blackOutDisplays) private var blackOutDisplays = true
    @AppStorage(CleaningPreferences.duration) private var duration = CleaningDuration.oneMinute

    private let panelInset: CGFloat = 16
    private let panelShape = RoundedRectangle(cornerRadius: 22)

    private var selectedOptions: CleaningOptions {
        var options: CleaningOptions = []
        if pauseKeyboard { options.insert(.keyboard) }
        if turnOffKeyboardBacklight, controller.hasKeyboardBacklight { options.insert(.keyboardBacklight) }
        if pausePointer { options.insert(.pointer) }
        if blackOutDisplays { options.insert(.display) }
        return options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                BlindfoldIcon(size: 44)
                Text("Cleaning Mode")
                    .font(.title2.weight(.semibold))
            }

            optionsPanel

            if let issue = controller.issue {
                Label(issue.message, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.updatesFrequently)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    if let status = controller.cleaningStatus {
                        Text(status)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    Text(controller.escapeHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                primaryAction
            }
            .frame(minHeight: 46)
            .padding(.horizontal, panelInset)
        }
        .padding(24)
        .frame(width: 420)
        .background {
            if !reduceTransparency {
                RadialGradient(
                    colors: [
                        Color(red: 0.24, green: 0.53, blue: 0.78).opacity(colorScheme == .dark ? 0.44 : 0.27),
                        .clear,
                    ],
                    center: .topTrailing,
                    startRadius: 16,
                    endRadius: 360
                )
                .ignoresSafeArea()
            }
        }
        .onDisappear(perform: controller.stop)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            controller.displayConfigurationChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            controller.appWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            controller.stop()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification).receive(on: DispatchQueue.main)) { _ in
            controller.stop()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).receive(on: DispatchQueue.main)) { _ in
            controller.recoverKeyboardBacklight()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.screensDidSleepNotification).receive(on: DispatchQueue.main)) { _ in
            controller.stop()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification).receive(on: DispatchQueue.main)) { _ in
            controller.stop()
        }
    }

    @ViewBuilder private var optionsPanel: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !reduceTransparency {
            optionsGrid.glassEffect(.regular, in: panelShape)
        } else {
            solidOptionsPanel
        }
        #else
        solidOptionsPanel
        #endif
    }

    private var solidOptionsPanel: some View {
        optionsGrid
            .background(Color(nsColor: .controlBackgroundColor), in: panelShape)
            .overlay { panelShape.strokeBorder(Color.primary.opacity(0.10)) }
    }

    private var optionsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 0) {
            option(
                "Keyboard",
                icon: "keyboard",
                isOn: $pauseKeyboard,
                help: "When this switch is on, Blindfold blocks keyboard input during cleaning."
            )
            Divider().gridCellUnsizedAxes(.horizontal)
            option(
                "Trackpad & Mouse",
                icon: "cursorarrow",
                isOn: $pausePointer,
                help: "When this switch is on, Blindfold blocks trackpad and mouse input during cleaning."
            )
            Divider().gridCellUnsizedAxes(.horizontal)
            option(
                "Display",
                icon: "display",
                isOn: $blackOutDisplays,
                help: "When this switch is on, Blindfold blacks out all connected displays during cleaning."
            )
            Divider().gridCellUnsizedAxes(.horizontal)
            if controller.hasKeyboardBacklight {
                option(
                    "Backlight",
                    icon: "lightbulb",
                    isOn: $turnOffKeyboardBacklight,
                    help: "When this switch is on, Blindfold turns off the built-in keyboard backlight during cleaning."
                )
                Divider().gridCellUnsizedAxes(.horizontal)
            }

            GridRow {
                rowLabel("Auto-unlock", icon: "timer")
                Picker("Auto-unlock", selection: $duration) {
                    ForEach(CleaningDuration.allCases, id: \.self) { duration in
                        Text(duration.label).tag(duration)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .gridColumnAlignment(.trailing)
            }
        }
        .disabled(controller.isCleaning)
        .padding(.horizontal, panelInset)
        .padding(.vertical, 5)
    }

    @ViewBuilder private var primaryAction: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *), !reduceTransparency {
            actionButton.buttonStyle(.glassProminent)
        } else {
            actionButton.buttonStyle(.borderedProminent)
        }
        #else
        actionButton.buttonStyle(.borderedProminent)
        #endif
    }

    private var actionButton: some View {
        Button(controller.isCleaning ? "End Cleaning" : "Start Cleaning") {
            if controller.isCleaning {
                controller.stop()
            } else {
                controller.start(options: selectedOptions, duration: duration)
            }
        }
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
        .disabled(!controller.isCleaning && selectedOptions.isEmpty)
        .fixedSize()
    }

    private func option(_ title: String, icon: String, isOn: Binding<Bool>, help: String) -> some View {
        GridRow {
            rowLabel(title, icon: icon, slashed: isOn.wrappedValue)
                .contentShape(Rectangle())
                .onTapGesture {
                    if !controller.isCleaning {
                        isOn.wrappedValue.toggle()
                    }
                }
                .help(help)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .accessibilityLabel(Text(title))
                .accessibilityHint(Text(help))
                .help(help)
                .toggleStyle(.switch)
                .fixedSize()
                .gridColumnAlignment(.trailing)
        }
    }

    private func rowLabel(_ title: String, icon: String, slashed: Bool = false) -> some View {
        HStack(spacing: 10) {
            rowIcon(icon, slashed: slashed)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(title)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func rowIcon(_ name: String, slashed: Bool) -> some View {
        let slashedName = "\(name).slash"

        if !slashed {
            Image(systemName: name)
        } else if NSImage(systemSymbolName: slashedName, accessibilityDescription: nil) != nil {
            Image(systemName: slashedName)
        } else {
            let slash = Path { path in
                path.move(to: CGPoint(x: 4, y: 2))
                path.addLine(to: CGPoint(x: 16, y: 14))
            }

            ZStack {
                Image(systemName: name)
                slash.stroke(.black, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .blendMode(.destinationOut)
            }
            .frame(width: 20, height: 16)
            .compositingGroup()
            .overlay {
                slash.stroke(style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }
}

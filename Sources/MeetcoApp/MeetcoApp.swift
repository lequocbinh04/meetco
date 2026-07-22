import AppKit
import SwiftUI

@main
struct MeetcoApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Meetco", id: "main") {
            MeetcoRootView(model: model)
                .frame(minWidth: 880, minHeight: 620)
        }
        // Hidden title bar lets the dark sidebar and content run full-height
        // instead of sitting under a detached light title strip.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { MeetcoCommands(model: model) }

        Settings {
            MeetcoSettingsContainer(model: model)
        }

        MenuBarExtra {
            MeetcoMenuBarContainer(model: model)
        } label: {
            Image(systemName: model.session?.viewState.isActive == true
                ? "record.circle.fill"
                : "waveform.and.mic")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MeetcoMenuBarContainer: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @ObservedObject var model: AppModel

    var body: some View {
        MeetcoMenuBarView(
            state: MeetcoViewStateFactory.menuBar(model),
            onStartLastPreset: {
                model.startRecording(
                    title: "Untitled meeting",
                    configuration: model.settings.defaultConfiguration
                )
            },
            onOpenMeeting: {
                model.openLiveMeeting()
                activateMainWindow()
            },
            onPauseResume: { model.session?.pauseOrResume() },
            onStop: { model.session?.stop() },
            onOpenMeetco: activateMainWindow,
            onOpenSettings: {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            }
        )
    }

    private func activateMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct MeetcoCommands: Commands {
    @ObservedObject var model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Recording") { model.presentPreflight() }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandMenu("Recording") {
            Button(model.session?.viewState.phase == .paused ? "Resume" : "Pause") {
                model.session?.pauseOrResume()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(model.session?.viewState.phase != .recording && model.session?.viewState.phase != .paused)

            Button("Stop Recording") { model.session?.stop() }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.session?.viewState.phase != .recording && model.session?.viewState.phase != .paused)
        }
    }
}

import AppKit
import SwiftUI
import AttacheCore

@main
struct AttacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .tint(Theme.accent)
                .onAppear {
                    appDelegate.model = model
                    model.start()
                }
                .onOpenURL { url in
                    model.openImage(url)
                }
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Open Image…") {
                    model.chooseImage(for: model.selection)
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Reveal Output") {
                    model.revealLastOutput()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(model.lastRevealURL == nil)

                Divider()

                Button("Refresh Attached Images") {
                    Task { await model.refreshAttached() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }

            CommandMenu("Image") {
                Button("Attach") {
                    model.selection = .attach
                    model.runAttach()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!model.canRun || model.attachForm.source == nil)

                Button("Detach") {
                    model.detachSelected(force: false)
                }
                .disabled(!model.canRun || model.selectedAttached == nil)

                Button("Force Detach") {
                    model.requestForceDetach()
                }
                .disabled(!model.canRun || model.selectedAttached == nil)

                Divider()

                Button("Create Image") {
                    model.selection = .create
                    model.runCreate()
                }
                .disabled(!model.canRun)

                Button("Convert Image") {
                    model.selection = .convert
                    model.runConvert()
                }
                .disabled(!model.canRun || model.convertForm.source == nil)

                Button("Inspect Image") {
                    model.selection = .inspect
                    model.runInspect()
                }
                .disabled(!model.canRun || model.inspectForm.source == nil)

                Divider()

                Button("Cancel Operation") {
                    model.cancelJob()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!model.job.isRunning)
            }

            CommandGroup(replacing: .help) {
                Button("Attaché Help") {
                    HelpWindowOpener.shared.open()
                }
            }
        }

        Window("Attaché Help", id: HelpPresenter.windowID) {
            HelpView()
        }
        .defaultSize(width: 520, height: 640)
    }
}

enum HelpPresenter {
    static let windowID = "attache-help"
}

extension Notification.Name {
    static let openAttacheHelp = Notification.Name("openAttacheHelp")
}

@MainActor
final class HelpWindowOpener {
    static let shared = HelpWindowOpener()
    var openWindow: ((String) -> Void)?

    func open() {
        if let openWindow {
            openWindow(HelpPresenter.windowID)
            return
        }
        NotificationCenter.default.post(name: .openAttacheHelp, object: nil)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if model?.confirmQuitIfNeeded() != false {
            return .terminateNow
        }
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
            NSApp.activate(ignoringOtherApps: true)
        }
        return .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        model?.openImage(first)
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stop()
        if model?.job.isRunning == true {
            model?.cancelJob()
        }
    }
}

enum Theme {
    static let accent = Color(red: 0.22, green: 0.46, blue: 0.74)
}

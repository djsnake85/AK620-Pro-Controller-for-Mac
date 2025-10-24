import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    private var viewModel: ContentViewModel?
    
    var statusItem: NSStatusItem!
    var cpuTempMenuItem: NSMenuItem!
    var cpuUsageMenuItem: NSMenuItem!
    var cpuFreqMenuItem: NSMenuItem!
    var toggleWindowMenuItem: NSMenuItem!

    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarMenu()
        
        let viewModel = ContentViewModel()
        self.viewModel = viewModel
        
        createMainWindowIfNeeded()
        setupBindings(with: viewModel)
        
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toggleWindowMenuItem.title = "Masquer la fenêtre"
    }

    func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            if let icon = NSImage(named: NSImage.Name("Deepcool 16")) {
                button.image = icon
                button.image?.isTemplate = false
            }
            button.title = ""
        }

        let menu = NSMenu()

        cpuFreqMenuItem = NSMenuItem(title: "Fréquence CPU: -- GHz", action: nil, keyEquivalent: "")
        cpuTempMenuItem = NSMenuItem(title: "Temp CPU: --°C", action: nil, keyEquivalent: "")
        cpuUsageMenuItem = NSMenuItem(title: "Usage CPU: --%", action: nil, keyEquivalent: "")
        toggleWindowMenuItem = NSMenuItem(title: "Afficher la fenêtre", action: #selector(toggleWindow), keyEquivalent: "w")
        toggleWindowMenuItem.target = self

        menu.addItem(cpuFreqMenuItem)
        menu.addItem(cpuTempMenuItem)
        menu.addItem(cpuUsageMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(toggleWindowMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func createMainWindowIfNeeded() {
        if mainWindow == nil {
            let contentView = ContentView(viewModel: viewModel ?? ContentViewModel())

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("Main Window")
            
            // Titre de la fenêtre personnalisé
            window.title = "DEEPCOOL AK620 DIGITAL PRO"
            
            window.contentView = NSHostingView(rootView: contentView)

            window.delegate = self

            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.level = .floating

            mainWindow = window
        }
    }

    @objc func toggleWindow() {
        createMainWindowIfNeeded()
        guard let window = mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            toggleWindowMenuItem.title = "Afficher la fenêtre"
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            toggleWindowMenuItem.title = "Masquer la fenêtre"
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        toggleWindowMenuItem.title = "Afficher la fenêtre"
        return false
    }

    private func setupBindings(with viewModel: ContentViewModel) {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        viewModel.$cpuTemperature
            .combineLatest(viewModel.$cpuUsage, viewModel.$cpuFrequency)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] temp, usage, freq in
                self?.updateStatus(temp: temp, usage: usage, frequency: freq)
            }
            .store(in: &cancellables)
    }

    private func updateStatus(temp: Double, usage: Double, frequency: Double) {
        let tempFormatted = String(format: "%.1f", temp)
        let usageFormatted = String(format: "%.1f", usage)
        let freqFormatted = String(format: "%.2f", frequency)

        self.cpuFreqMenuItem.title = "Fréquence CPU: \(freqFormatted) GHz"
        self.cpuTempMenuItem.title = "Temp CPU: \(tempFormatted)°C"
        self.cpuUsageMenuItem.title = "Usage CPU: \(usageFormatted)%"

        guard let button = self.statusItem.button else { return }

        let statusText = "CPU INFO - \(freqFormatted) GHz - \(tempFormatted)°C - \(usageFormatted)%"

        let color: NSColor
        if temp > 75 {
            color = .red
        } else if temp >= 65 {
            color = .orange
        } else {
            color = .systemGreen
        }

        button.image = NSImage(named: "Deepcool 16")
        button.image?.isTemplate = false
        button.attributedTitle = NSAttributedString(
            string: statusText,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 14, weight: .bold)
            ]
        )
    }
}


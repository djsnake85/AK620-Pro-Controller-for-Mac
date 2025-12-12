import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    private var viewModel: ContentViewModel!

    var statusItem: NSStatusItem!
    var cpuTempMenuItem: NSMenuItem!
    var cpuUsageMenuItem: NSMenuItem!
    var cpuFreqMenuItem: NSMenuItem!
    var toggleWindowMenuItem: NSMenuItem!

    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = ContentViewModel()
        setupStatusBarMenu()
        createMainWindowIfNeeded()
        setupBindings()

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toggleWindowMenuItem.title = "Masquer la fenêtre"
    }

    // MARK: - Barre de statut
    func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Icône Deepcool proportionnée
            if let deepcoolIcon = NSImage(named: "deepcool-logo") {
                deepcoolIcon.isTemplate = false
                button.image = resizeImage(image: deepcoolIcon, width: 18, height: 18)
            }
            button.title = ""
        }

        let menu = NSMenu()
        cpuFreqMenuItem = NSMenuItem(title: "Fréquence CPU : -- GHz", action: nil, keyEquivalent: "")
        cpuTempMenuItem = NSMenuItem(title: "Temp CPU : --°C", action: nil, keyEquivalent: "")
        cpuUsageMenuItem = NSMenuItem(title: "Usage CPU : --%", action: nil, keyEquivalent: "")
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

    // MARK: - Redimensionner image
    private func resizeImage(image: NSImage, width: CGFloat, height: CGFloat) -> NSImage {
        let resized = NSImage(size: NSSize(width: width, height: height))
        resized.lockFocus()
        image.draw(in: NSRect(x: 0, y: 0, width: width, height: height),
                   from: NSRect.zero,
                   operation: .sourceOver,
                   fraction: 1.0)
        resized.unlockFocus()
        return resized
    }

    // MARK: - Fenêtre principale
    func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }
        let contentView = ContentView(viewModel: self.viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false
        )
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "DeepCool AK620 Digital Pro"
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating

        mainWindow = window
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

    // MARK: - Bindings Combine
    private func setupBindings() {
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

    // MARK: - Mise à jour de la barre de statut
    private func updateStatus(temp: Double, usage: Double, frequency: Double) {
        let tempFormatted = String(format: "%.0f", temp)
        let usageFormatted = String(format: "%.0f", usage)
        let freqFormatted = String(format: "%.2f", frequency / 1000.0)

        // Mise à jour menu
        cpuFreqMenuItem.title = "Fréquence CPU : \(freqFormatted) GHz"
        cpuTempMenuItem.title = "Temp CPU : \(tempFormatted)°C"
        cpuUsageMenuItem.title = "Usage CPU : \(usageFormatted)%"

        guard let button = statusItem.button else { return }

        // Texte avec thermomètre
        let thermometer = "🌡️"
        let statusText = "Fréquence: \(freqFormatted) GHz | Température:  \(thermometer) \(tempFormatted)°C | Usage: \(usageFormatted)%"

        // Couleur dynamique selon température
        let color: NSColor
        if temp > 75 {
            color = .systemRed
        } else if temp >= 65 {
            color = .systemOrange
        } else {
            color = .labelColor
        }

        // Police San Francisco 12 pt light
        let font = NSFont.systemFont(ofSize: 12, weight: .light)

        button.attributedTitle = NSAttributedString(
            string: statusText,
            attributes: [
                .foregroundColor: color,
                .font: font
            ]
        )

        // Icône principale Deepcool proportionnée
        if let deepcoolIcon = NSImage(named: "deepcool-logo") {
            deepcoolIcon.isTemplate = false
            button.image = resizeImage(image: deepcoolIcon, width: 18, height: 18)
        }
    }
}



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
    private var pulseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1️⃣ Créer le ViewModel avant tout
        viewModel = ContentViewModel()

        // 2️⃣ Configurer le menu de la barre de statut
        setupStatusBarMenu()

        // 3️⃣ Créer la fenêtre principale
        createMainWindowIfNeeded()

        // 4️⃣ Lier les données du ViewModel à la barre de statut
        setupBindings()

        // 5️⃣ Lancer le timer de pulsation
        setupStatusPulseAnimation()

        // 6️⃣ Afficher la fenêtre et activer l'app
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toggleWindowMenuItem.title = "Masquer la fenêtre"
    }

    // MARK: - Barre de statut
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

    // MARK: - Fenêtre principale
    func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }

        let contentView = ContentView(viewModel: self.viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered, defer: false)
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
        let freqFormatted = String(format: "%.2f", frequency / 1000.0) // <-- Divisé par 1000 pour GHz

        cpuFreqMenuItem.title = "Fréquence CPU: \(freqFormatted) GHz"
        cpuTempMenuItem.title = "Temp CPU: \(tempFormatted)°C"
        cpuUsageMenuItem.title = "Usage CPU: \(usageFormatted)%"

        guard let button = statusItem.button else { return }

        let statusText = "CPU Info : \(freqFormatted) GHz - \(tempFormatted)°C - \(usageFormatted)%"
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

    // MARK: - Animation de pulsation du texte
    private func setupStatusPulseAnimation() {
        guard let button = statusItem.button else { return }

        var increasingAlpha = true
        var currentAlpha: CGFloat = 1.0

        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            currentAlpha += increasingAlpha ? -0.1 : 0.1
            if currentAlpha <= 0.4 {
                currentAlpha = 0.4
                increasingAlpha = false
            } else if currentAlpha >= 1.0 {
                currentAlpha = 1.0
                increasingAlpha = true
            }

            let text = button.attributedTitle.string

            let color: NSColor
            if self.viewModel.cpuTemperature > 75 {
                color = NSColor.red.withAlphaComponent(currentAlpha)
            } else if self.viewModel.cpuTemperature >= 65 {
                color = NSColor.orange.withAlphaComponent(currentAlpha)
            } else {
                color = NSColor.systemGreen.withAlphaComponent(currentAlpha)
            }

            let attrTitle = NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: color,
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold)
                ]
            )

            button.attributedTitle = attrTitle
        }
    }
}

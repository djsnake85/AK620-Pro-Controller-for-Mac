import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var viewModel: ContentViewModel!
    var statusItem: NSStatusItem!
    var cpuTempMenuItem: NSMenuItem?
    var cpuUsageMenuItem: NSMenuItem?
    var cpuFreqMenuItem: NSMenuItem?
    var gpuTempMenuItem: NSMenuItem?
    var toggleWindowMenuItem: NSMenuItem?

    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lancement

    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = ContentViewModel()
        setupStatusBarMenu()
        createMainWindowIfNeeded()
        setupBindings()
        toggleWindowMenuItem?.title = "Afficher la fenêtre"

        viewModel.startUpdates()
    }

    // MARK: - Barre de statut

    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        cpuFreqMenuItem  = NSMenuItem(title: "Fréquence CPU : -- GHz", action: nil, keyEquivalent: "")
        cpuTempMenuItem  = NSMenuItem(title: "Temp CPU : --°C",        action: nil, keyEquivalent: "")
        cpuUsageMenuItem = NSMenuItem(title: "Usage CPU : --%",        action: nil, keyEquivalent: "")
        gpuTempMenuItem  = NSMenuItem(title: "Temp GPU : --°C",        action: nil, keyEquivalent: "")

        let toggleItem = NSMenuItem(title: "Afficher la fenêtre", action: #selector(toggleWindow), keyEquivalent: "w")
        toggleItem.target = self
        toggleWindowMenuItem = toggleItem

        let settingsMenuItem = NSMenuItem(title: "Paramètres", action: #selector(openSettingsWindow), keyEquivalent: "")
        settingsMenuItem.target = self // CORRECTION: Ajout du target pour déclencher l'action
        if let icon = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings") {
            icon.isTemplate = true
            settingsMenuItem.image = icon
        }

        let quitMenuItem = NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let menu = NSMenu()
        [cpuFreqMenuItem, cpuTempMenuItem, cpuUsageMenuItem, gpuTempMenuItem]
            .compactMap { $0 }
            .forEach { menu.addItem($0) }
        menu.addItem(.separator())
        menu.addItem(toggleItem)
        menu.addItem(settingsMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)

        statusItem.menu = menu
    }

    // MARK: - Fenêtre principale

    private func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }

        let contentView = ContentView(viewModel: viewModel)
        
        // CORRECTION & BLOQUAGE REDIMENSIONNEMENT: Retrait de .resizable dans styleMask
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 535, height: 685),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        // Verrouillage strict de la taille
        window.minSize = NSSize(width: 535, height: 685)
        window.maxSize = NSSize(width: 535, height: 685)
        
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "DeepCool AK620 Digital Pro / AK620 G2 Digital NYX - By Snake"
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        mainWindow = window
    }

    // MARK: - Afficher / masquer

    @objc private func toggleWindow() {
        createMainWindowIfNeeded()
        guard let window = mainWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
            toggleWindowMenuItem?.title = "Afficher la fenêtre"
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            toggleWindowMenuItem?.title = "Masquer la fenêtre"
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        toggleWindowMenuItem?.title = "Afficher la fenêtre"
        return false
    }

    // MARK: - Bindings Combine

    private func setupBindings() {
        cancellables.removeAll()
        viewModel.$cpuTemperature
            .combineLatest(viewModel.$cpuUsage, viewModel.$cpuFrequency, viewModel.$gpuTemperature)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] temp, usage, freq, gpuTemp in
                self?.updateStatus(temp: temp, usage: usage, frequency: freq, gpuTemp: gpuTemp)
            }
            .store(in: &cancellables)
    }

    // MARK: - Mise à jour statut

    private func updateStatus(temp: Double, usage: Double, frequency: Double, gpuTemp: Double) {
        let tempColor:    NSColor = temp    > 75 ? .systemRed : temp    >= 65 ? .systemOrange : .labelColor
        let usageColor:   NSColor = usage   > 90 ? .systemRed : usage   >= 70 ? .systemOrange : .labelColor
        let gpuTempColor: NSColor = gpuTemp > 75 ? .systemRed : gpuTemp >= 65 ? .systemOrange : .labelColor

        cpuFreqMenuItem?.title = String(format: "Fréquence ⚡️: %.2f GHz", frequency / 1000.0)
        cpuTempMenuItem?.attributedTitle  = attributedTextWithSymbol(
            symbol: "thermometer", text: String(format: "Température CPU: %.0f°C", temp),  color: tempColor)
        cpuUsageMenuItem?.attributedTitle = attributedTextWithSymbol(
            symbol: "gauge",       text: String(format: "Usage: %.0f%%", usage), color: usageColor)
        gpuTempMenuItem?.attributedTitle  = attributedTextWithSymbol(
            symbol: "thermometer", text: String(format: "Température GPU: %.0f°C", gpuTemp), color: gpuTempColor)

        guard let button = statusItem.button else { return }
        let statusString = NSMutableAttributedString()

        if let logo = NSImage(named: "deepcool-logo") {
            logo.isTemplate = true
            let attach = NSTextAttachment()
            attach.image = resizeImage(image: logo, width: 13, height: 13)
            statusString.append(NSAttributedString(attachment: attach))
            statusString.append(NSAttributedString(string: " "))
        }

        statusString.append(attributedTextWithSymbol(
            symbol: "thermometer", text: String(format: "Température CPU %.0f°C", temp), color: tempColor))
        statusString.append(NSAttributedString(string: " | "))
        statusString.append(attributedTextWithSymbol(
            symbol: "gauge", text: String(format: "Usage: %.0f%%", usage), color: usageColor))
        statusString.append(NSAttributedString(
            string: String(format: " | Fréquence⚡️: %.2fGHz", frequency / 1000.0)))
        statusString.append(NSAttributedString(string: " | "))
        statusString.append(attributedTextWithSymbol(
            symbol: "thermometer", text: String(format: "Température GPU: %.0f°C", gpuTemp), color: gpuTempColor))

        button.attributedTitle = statusString
    }

    // MARK: - Helpers

    private func attributedTextWithSymbol(symbol: String, text: String, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let tintedIcon = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
                icon.draw(in: rect)
                color.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            let attach = NSTextAttachment()
            attach.image = tintedIcon
            result.append(NSAttributedString(attachment: attach))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
        ]))
        return result
    }

    @objc private func openSettingsWindow() {
        // À implémenter
    }

    private func resizeImage(image: NSImage, width: CGFloat, height: CGFloat) -> NSImage {
        let destSize = NSMakeSize(width, height)
        let newImage = NSImage(size: destSize)
        newImage.lockFocus()
        image.draw(in: NSMakeRect(0, 0, destSize.width, destSize.height),
                   from: NSMakeRect(0, 0, image.size.width, image.size.height),
                   operation: .sourceOver, fraction: 1)
        newImage.unlockFocus()
        newImage.isTemplate = image.isTemplate
        return newImage
    }
}

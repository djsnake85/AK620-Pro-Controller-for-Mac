import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    var viewModel: ContentViewModel!
    var statusItem: NSStatusItem!
    var cpuTempMenuItem: NSMenuItem!
    var cpuUsageMenuItem: NSMenuItem!
    var cpuFreqMenuItem: NSMenuItem!
    var toggleWindowMenuItem: NSMenuItem!

    private var mainWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lancement de l'application
    func applicationDidFinishLaunching(_ notification: Notification) {
        viewModel = ContentViewModel()
        setupStatusBarMenu()
        createMainWindowIfNeeded()
        setupBindings()

        toggleWindowMenuItem.title = "Afficher la fenêtre"
    }

    // MARK: - Barre de statut
    private func setupStatusBarMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        cpuFreqMenuItem = NSMenuItem(title: "Fréquence CPU : -- GHz", action: nil, keyEquivalent: "")
        cpuTempMenuItem = NSMenuItem(title: "Temp CPU : --°C", action: nil, keyEquivalent: "")
        cpuUsageMenuItem = NSMenuItem(title: "Usage CPU : --%", action: nil, keyEquivalent: "")

        toggleWindowMenuItem = NSMenuItem(title: "Afficher la fenêtre", action: #selector(toggleWindow), keyEquivalent: "w")
        toggleWindowMenuItem.target = self

        let settingsMenuItem = NSMenuItem(title: "Paramètres", action: #selector(openSettingsWindow), keyEquivalent: "")
        if let settingsIcon = NSImage(systemSymbolName: "gear", accessibilityDescription: "Settings Icon") {
            settingsIcon.isTemplate = true
            settingsMenuItem.image = settingsIcon
        }

        let quitMenuItem = NSMenuItem(title: "Quitter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        
        let menu = NSMenu()
        [cpuFreqMenuItem, cpuTempMenuItem, cpuUsageMenuItem,
         NSMenuItem.separator(),
         toggleWindowMenuItem,
         settingsMenuItem,
         NSMenuItem.separator(),
         quitMenuItem
        ].forEach { menu.addItem($0) }

        statusItem.menu = menu
    }

    // MARK: - Fenêtre principale
    private func createMainWindowIfNeeded() {
        guard mainWindow == nil else { return }
        let contentView = ContentView(viewModel: self.viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.title = "DeepCool AK620 Digital Pro - By Snake"
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .floating
        
        mainWindow = window
    }

    // MARK: - Afficher / masquer la fenêtre
    @objc private func toggleWindow() {
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

    // MARK: - Mise à jour du statut
    private func updateStatus(temp: Double, usage: Double, frequency: Double) {
        let tempFormatted = String(format: "%.0f", temp)
        let usageFormatted = String(format: "%.0f", usage)
        let freqFormatted = String(format: "%.2f", frequency / 1000.0)

        let tempColor: NSColor = temp > 75 ? .systemRed : temp >= 65 ? .systemOrange : NSColor.labelColor
        let usageColor: NSColor = usage > 90 ? .systemRed : usage >= 70 ? .systemOrange : NSColor.labelColor

        // Menu Température et Usage CPU
        cpuTempMenuItem.attributedTitle = attributedMenuItem(title: tempFormatted + "°C", systemSymbol: "thermometer", color: tempColor)
        cpuUsageMenuItem.attributedTitle = attributedMenuItem(title: usageFormatted + "%", systemSymbol: "gauge", color: usageColor)

        // Barre de statut
        guard let button = statusItem.button else { return }
        let statusString = NSMutableAttributedString()

        // Logo DeepCool coloré
        if let logo = NSImage(named: "deepcool-logo") {
            logo.isTemplate = false
            let attach = NSTextAttachment()
            attach.image = resizeImage(image: logo, width: 18, height: 18)
            statusString.append(NSAttributedString(attachment: attach))
            statusString.append(NSAttributedString(string: " "))
        }

        // Température
        statusString.append(attributedTextWithSymbol(symbol: "thermometer", text: "\(tempFormatted)°C", color: tempColor))
        statusString.append(NSAttributedString(string: " | "))

        // Usage CPU
        statusString.append(attributedTextWithSymbol(symbol: "gauge", text: "\(usageFormatted)%", color: usageColor))
        statusString.append(NSAttributedString(string: " | "))

        // Fréquence CPU
        statusString.append(NSAttributedString(string: "Freq: \(freqFormatted)GHz", attributes: [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]))

        button.attributedTitle = statusString
        button.image = nil
    }

    // MARK: - Helpers
    private func attributedMenuItem(title: String, systemSymbol: String, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let icon = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: nil) {
            icon.isTemplate = true
            let tinted = icon.copy() as! NSImage
            tinted.lockFocus()
            color.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            let attach = NSTextAttachment()
            attach.image = resizeImage(image: tinted, width: 14, height: 14)
            result.append(NSAttributedString(attachment: attach))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: title, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]))
        return result
    }

    private func attributedTextWithSymbol(symbol: String, text: String, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let icon = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            icon.isTemplate = true
            let tinted = icon.copy() as! NSImage
            tinted.lockFocus()
            color.set()
            NSRect(origin: .zero, size: tinted.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            let attach = NSTextAttachment()
            attach.image = resizeImage(image: tinted, width: 14, height: 14)
            result.append(NSAttributedString(attachment: attach))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: text, attributes: [
            .foregroundColor: color,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]))
        return result
    }

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

    // MARK: - Fenêtre des paramètres
    @objc private func openSettingsWindow() {
        let settingsWindowController = SettingsWindowController()
        settingsWindowController.showWindow(nil)
    }
}

// Exemple SettingsWindowController
class SettingsWindowController: NSWindowController {
    override var windowNibName: NSNib.Name? {
        return NSNib.Name("SettingsWindow")
    }
}


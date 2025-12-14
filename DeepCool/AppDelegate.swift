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

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        toggleWindowMenuItem.title = "Masquer la fenêtre"
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

        // Couleurs dynamiques
        let tempColor: NSColor = temp > 75 ? .systemRed : temp >= 65 ? .systemOrange : NSColor.labelColor
        let usageColor: NSColor = usage > 90 ? .systemRed : usage >= 70 ? .systemOrange : NSColor.labelColor

        // ------------------------------
        // Menu Température
        let tempString = NSMutableAttributedString()
        if let thermometerIcon = NSImage(systemSymbolName: "thermometer", accessibilityDescription: "Thermometer") {
            thermometerIcon.isTemplate = true
            let tintedIcon = thermometerIcon.copy() as! NSImage
            tintedIcon.lockFocus()
            tempColor.set()
            NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
            tintedIcon.unlockFocus()
            let attachment = NSTextAttachment()
            attachment.image = resizeImage(image: tintedIcon, width: 14, height: 14)
            tempString.append(NSAttributedString(attachment: attachment))
            tempString.append(NSAttributedString(string: " "))
        }
        tempString.append(NSAttributedString(string: "\(tempFormatted)°C", attributes: [
            .foregroundColor: tempColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]))
        cpuTempMenuItem.attributedTitle = tempString

        // ------------------------------
        // Menu Usage CPU
        let usageString = NSMutableAttributedString()
        if let usageIcon = NSImage(systemSymbolName: "gauge", accessibilityDescription: "CPU Usage") {
            usageIcon.isTemplate = true
            let tintedIcon = usageIcon.copy() as! NSImage
            tintedIcon.lockFocus()
            usageColor.set()
            NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
            tintedIcon.unlockFocus()
            let attachment = NSTextAttachment()
            attachment.image = resizeImage(image: tintedIcon, width: 14, height: 14)
            usageString.append(NSAttributedString(attachment: attachment))
            usageString.append(NSAttributedString(string: " "))
        }
        usageString.append(NSAttributedString(string: "\(usageFormatted)%", attributes: [
            .foregroundColor: usageColor,
            .font: NSFont.systemFont(ofSize: 13, weight: .regular)
        ]))
        cpuUsageMenuItem.attributedTitle = usageString

        // ------------------------------
        // Bouton barre de statut : icône DeepCool + thermomètre + usage + fréquence
        if let button = statusItem.button {
            let buttonString = NSMutableAttributedString()

            // Icône DeepCool
            if let deepcoolIcon = NSImage(named: "deepcool-logo") {
                deepcoolIcon.isTemplate = false
                let attachment = NSTextAttachment()
                attachment.image = resizeImage(image: deepcoolIcon, width: 15, height: 15)
                buttonString.append(NSAttributedString(attachment: attachment))
                buttonString.append(NSAttributedString(string: " "))
            }

            // Thermomètre
            if let thermometerIcon = NSImage(systemSymbolName: "thermometer", accessibilityDescription: "Thermometer") {
                thermometerIcon.isTemplate = true
                let tintedIcon = thermometerIcon.copy() as! NSImage
                tintedIcon.lockFocus()
                tempColor.set()
                NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
                tintedIcon.unlockFocus()
                let attachment = NSTextAttachment()
                attachment.image = resizeImage(image: tintedIcon, width: 15, height: 16)
                buttonString.append(NSAttributedString(attachment: attachment))
                buttonString.append(NSAttributedString(string: " Temp:\(tempFormatted)°C | "))
            }

            // Usage CPU
            if let usageIcon = NSImage(systemSymbolName: "gauge", accessibilityDescription: "CPU Usage") {
                usageIcon.isTemplate = true
                let tintedIcon = usageIcon.copy() as! NSImage
                tintedIcon.lockFocus()
                usageColor.set()
                NSRect(origin: .zero, size: tintedIcon.size).fill(using: .sourceAtop)
                tintedIcon.unlockFocus()
                let attachment = NSTextAttachment()
                attachment.image = resizeImage(image: tintedIcon, width: 14, height: 14)
                buttonString.append(NSAttributedString(attachment: attachment))
                buttonString.append(NSAttributedString(string: " Usage: \(usageFormatted)% | "))
            }

            // Fréquence CPU
            buttonString.append(NSAttributedString(string: " Freq:\(freqFormatted) GHz", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 14, weight: .light)
            ]))

            button.attributedTitle = buttonString
            button.image = nil
        }
    }

    // MARK: - Redimensionner une image
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

// Classe SettingsWindowController (exemple)
class SettingsWindowController: NSWindowController {
    override var windowNibName: NSNib.Name? {
        return NSNib.Name("SettingsWindow")
    }
}


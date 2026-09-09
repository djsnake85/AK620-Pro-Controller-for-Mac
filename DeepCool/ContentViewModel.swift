import Foundation
import SwiftUI

class ContentViewModel: ObservableObject {

    // ---------- CPU ----------
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    @Published var cpuFanRPM: Double = 0.0
    @Published var chassisFanRPM: Double = 0.0
    let cpuModel: String
    let cpuCoreCount: Int
    // Modèle SMBIOS de la machine (ex: "MacPro7,1"), statique — lu une seule fois.
    let smbiosModel: String
    // Version macOS installée (ex: "macOS 14.5"), statique.
    let osVersion: String

    // ---------- GPU ----------
    @Published var gpuModel: String = "..."
    @Published var gpuVRAM: Double = 0.0
    @Published var gpuUsage: Double = 0.0
    @Published var gpuTemperature: Double = 0.0
    @Published var gpuVRAMUsed: Double = 0.0
    // Reflète l'état de la règle sudoers NOPASSWD pour powermetrics.
    // Utilisable côté UI pour afficher un bouton "Autoriser l'accès GPU" si false.
    @Published var powermetricsAuthorized: Bool = PowermetricsAuthorization.isAuthorized()

    // ---------- RAM ----------
    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    // ---------- Disk ----------
    @Published var diskUsed: Double = 0.0
    @Published var diskTotal: Double = 0.0
    @Published var diskModel: String = "..."

    // ---------- Network ----------
    @Published var networkSent: Double = 0.0
    @Published var networkReceived: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0
    @Published var networkDownloadSpeed: Double = 0.0
    @Published var ipAddress: String = "..."
    @Published var routerAddress: String = "..."
    @Published var wifiPhyMode: String = "..."
    @Published var wifiChannel: String = "..."
    @Published var wifiLinkSpeed: Double = 0.0
    @Published var wifiSignalDBm: Int = 0

    // ---------- Managers ----------
    let deviceManager: DeepcoolDeviceManager   // internal pour AppDelegate
    let systemMonitor: SystemMonitor            // internal pour AppDelegate
    private var updateTask: Task<Void, Never>? = nil
   
    private let updateInterval: UInt64 = 1_000_000_000

    init() {
        self.deviceManager = DeepcoolDeviceManager()
        self.systemMonitor = SystemMonitor()
        self.cpuModel      = getCPUModel()
        self.cpuCoreCount  = ProcessInfo.processInfo.processorCount
        self.smbiosModel   = getSMBIOSModel()
        self.osVersion     = getOSVersionString()

        // CORRECTION : un seul appel system_profiler pour modèle + VRAM
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let (model, vram) = await self.systemMonitor.fetchGPUModelAndVRAM()
            await MainActor.run {
                self.gpuModel = model
                self.gpuVRAM  = vram
            }
        }

        // Modèle du disque de démarrage — un seul appel diskutil au lancement.
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let model = await self.systemMonitor.fetchDiskModel()
            await MainActor.run {
                self.diskModel = model
            }
        }

        systemMonitor.updateRAMFrequency()
    }


    func requestPowermetricsAccess() {
        PowermetricsAuthorization.requestAuthorization { [weak self] success in
            self?.powermetricsAuthorized = success
        }
    }

    func startUpdates() {
       
        if !powermetricsAuthorized {
            requestPowermetricsAccess()
        }

        updateTask?.cancel()
        updateTask = Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                self.systemMonitor.updateSystemMetrics()
                let monitor = self.systemMonitor

                await MainActor.run {
                    self.cpuFrequency    = monitor.cpuFrequency
                    self.cpuUsage        = monitor.cpuUsage
                    self.cpuTemperature  = monitor.cpuTemperature
                    self.cpuTDP          = monitor.cpuTDP
                    self.cpuFanRPM       = monitor.cpuFanRPM
                    self.chassisFanRPM   = monitor.chassisFanRPM

                    self.ramUsed         = monitor.ramUsed
                    self.ramTotal        = monitor.ramTotal
                    self.ramFrequency    = monitor.ramFrequency

                    self.diskUsed        = monitor.diskUsed
                    self.diskTotal       = monitor.diskTotal

                    self.networkSent          = monitor.networkSent
                    self.networkReceived      = monitor.networkReceived
                    self.networkUploadSpeed   = monitor.networkUploadSpeed
                    self.networkDownloadSpeed = monitor.networkDownloadSpeed
                    self.ipAddress            = monitor.ipAddress
                    self.routerAddress        = monitor.routerAddress
                    self.wifiPhyMode          = monitor.wifiPhyMode
                    self.wifiChannel          = monitor.wifiChannel
                    self.wifiLinkSpeed        = monitor.wifiLinkSpeed
                    self.wifiSignalDBm        = monitor.wifiSignalDBm

                    self.gpuUsage = monitor.gpuUsage
                    self.gpuTemperature = monitor.gpuTemperature
                    self.gpuVRAMUsed = monitor.gpuVRAMUsed
                    // gpuVRAM : fixe, chargé au init — pas besoin de rafraîchir
                }

                let command: Data
                switch self.deviceManager.deviceType {
                case .pro:
                    command = Data()
                case .g2Nyx:
                    command = monitor.createHUDCommandAK620G2Nyx()
                }
                self.deviceManager.sendCommand(command)

                try? await Task.sleep(nanoseconds: self.updateInterval)
            }
        }
    }

    func stopUpdates() {
        updateTask?.cancel()
        updateTask = nil
    }

    deinit { stopUpdates() }
}

// MARK: - Utilitaire CPU
func getCPUModel() -> String {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuModel = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuModel, &size, nil, 0)
    return String(cString: cpuModel)
}

// MARK: - Utilitaire SMBIOS
// "hw.model" correspond à l'identifiant de modèle SMBIOS (ex: "MacPro7,1"),
// celui utilisé par system_profiler / About This Mac.
func getSMBIOSModel() -> String {
    var size: Int = 0
    sysctlbyname("hw.model", nil, &size, nil, 0)
    guard size > 0 else { return "Inconnu" }
    var model = [CChar](repeating: 0, count: size)
    sysctlbyname("hw.model", &model, &size, nil, 0)
    return String(cString: model)
}

// MARK: - Utilitaire version macOS
func getOSVersionString() -> String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    var version = "macOS \(v.majorVersion).\(v.minorVersion)"
    if v.patchVersion > 0 {
        version += ".\(v.patchVersion)"
    }
    return version
}

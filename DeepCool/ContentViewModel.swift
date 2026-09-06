import Foundation
import SwiftUI

class ContentViewModel: ObservableObject {

    // ---------- CPU ----------
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    let cpuModel: String
    let cpuCoreCount: Int

    // ---------- GPU ----------
    @Published var gpuModel: String = "..."
    @Published var gpuVRAM: Double = 0.0
    @Published var gpuUsage: Double = 0.0

    // ---------- RAM ----------
    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    // ---------- Disk ----------
    @Published var diskUsed: Double = 0.0
    @Published var diskTotal: Double = 0.0

    // ---------- Network ----------
    @Published var networkSent: Double = 0.0
    @Published var networkReceived: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0
    @Published var networkDownloadSpeed: Double = 0.0

    // ---------- Managers ----------
    let deviceManager: DeepcoolDeviceManager   // internal pour AppDelegate
    let systemMonitor: SystemMonitor            // internal pour AppDelegate
    private var updateTask: Task<Void, Never>? = nil
    private let updateInterval: UInt64 = 2_000_000_000

    init() {
        self.deviceManager = DeepcoolDeviceManager()
        self.systemMonitor = SystemMonitor()
        self.cpuModel      = getCPUModel()
        self.cpuCoreCount  = ProcessInfo.processInfo.processorCount

        // CORRECTION : un seul appel system_profiler pour modèle + VRAM
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let (model, vram) = await self.systemMonitor.fetchGPUModelAndVRAM()
            await MainActor.run {
                self.gpuModel = model
                self.gpuVRAM  = vram
            }
        }

        systemMonitor.updateRAMFrequency()
    }

    func startUpdates() {
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

                    self.ramUsed         = monitor.ramUsed
                    self.ramTotal        = monitor.ramTotal
                    self.ramFrequency    = monitor.ramFrequency

                    self.diskUsed        = monitor.diskUsed
                    self.diskTotal       = monitor.diskTotal

                    self.networkSent          = monitor.networkSent
                    self.networkReceived      = monitor.networkReceived
                    self.networkUploadSpeed   = monitor.networkUploadSpeed
                    self.networkDownloadSpeed = monitor.networkDownloadSpeed

                    self.gpuUsage = monitor.gpuUsage
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

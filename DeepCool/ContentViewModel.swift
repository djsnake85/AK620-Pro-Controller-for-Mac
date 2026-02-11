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
    private let deviceManager = DeepcoolDeviceManager()
    private let systemMonitor = SystemMonitor()
    private var updateTask: Task<Void, Never>? = nil

    // 🔥 Interval configurable
    private let updateInterval: UInt64 = 1_000_000_000

    init() {
        self.cpuModel = getCPUModel()
        self.cpuCoreCount = ProcessInfo.processInfo.processorCount

        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }
            let model = await self.systemMonitor.fetchGPUModel()

            await MainActor.run {
                self.gpuModel = model
                self.gpuVRAM = self.systemMonitor.gpuVRAM
                self.gpuUsage = self.systemMonitor.gpuUsage
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

                // 🔥 snapshot local (évite accès multiples)
                let monitor = self.systemMonitor

                let cpuFrequency = monitor.cpuFrequency
                let cpuUsage = monitor.cpuUsage
                let cpuTemperature = monitor.cpuTemperature
                let cpuTDP = monitor.cpuTDP

                let ramUsed = monitor.ramUsed
                let ramTotal = monitor.ramTotal
                let ramFrequency = monitor.ramFrequency

                let diskUsed = monitor.diskUsed
                let diskTotal = monitor.diskTotal

                let networkSent = monitor.networkSent
                let networkReceived = monitor.networkReceived
                let networkUploadSpeed = monitor.networkUploadSpeed
                let networkDownloadSpeed = monitor.networkDownloadSpeed

                let gpuVRAM = monitor.gpuVRAM
                let gpuUsage = monitor.gpuUsage

                await MainActor.run {
                    // 🔥 update groupé (moins de refresh UI)
                    self.cpuFrequency = cpuFrequency
                    self.cpuUsage = cpuUsage
                    self.cpuTemperature = cpuTemperature
                    self.cpuTDP = cpuTDP

                    self.ramUsed = ramUsed
                    self.ramTotal = ramTotal
                    self.ramFrequency = ramFrequency

                    self.diskUsed = diskUsed
                    self.diskTotal = diskTotal

                    self.networkSent = networkSent
                    self.networkReceived = networkReceived
                    self.networkUploadSpeed = networkUploadSpeed
                    self.networkDownloadSpeed = networkDownloadSpeed

                    self.gpuVRAM = gpuVRAM
                    self.gpuUsage = gpuUsage
                }

                // 🔥 hors main thread
                let commandData = monitor.createHUDCommand()
                self.deviceManager.sendCommand(commandData)

                try? await Task.sleep(nanoseconds: self.updateInterval)
            }
        }
    }

    func stopUpdates() {
        updateTask?.cancel()
        updateTask = nil
    }

    deinit {
        stopUpdates()
    }
}

// ---------- Utilitaire ----------
func getCPUModel() -> String {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuModel = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuModel, &size, nil, 0)
    return String(cString: cpuModel)
}

import Foundation

class ContentViewModel: ObservableObject {
    // ---------------- CPU ----------------
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    let cpuModel: String
    let cpuCoreCount: Int

    // ---------------- GPU ----------------
    @Published var gpuModel: String = "..."
    @Published var gpuVRAM: Double = 0.0
    @Published var gpuUsage: Double = 0.0

    // ---------------- RAM ----------------
    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    // ---------------- Disk ----------------
    @Published var diskUsed: Double = 0.0
    @Published var diskTotal: Double = 0.0

    // ---------------- Network ----------------
    @Published var networkSent: Double = 0.0
    @Published var networkReceived: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0
    @Published var networkDownloadSpeed: Double = 0.0

    // ---------------- Managers ----------------
    private let deviceManager = DeepcoolDeviceManager()
    private let powerMonitor: PowerGadgetMonitor?
    private let systemMonitor = SystemMonitor() // pour RAM, Disk, Network, GPU simple
    private var updateTask: Task<Void, Never>? = nil

    private var previousSent: Double = 0.0
    private var previousReceived: Double = 0.0

    init() {
        self.cpuModel = getCPUModel()
        self.cpuCoreCount = ProcessInfo.processInfo.processorCount
        self.powerMonitor = PowerGadgetMonitor()

        // Mise à jour GPU initiale
        Task {
            let model = await systemMonitor.fetchGPUModel()
            await MainActor.run {
                self.gpuModel = model
                self.gpuVRAM = systemMonitor.gpuVRAM
                self.gpuUsage = systemMonitor.gpuUsage
            }
        }

        systemMonitor.updateRAMFrequency()
        systemMonitor.updateDiskAndNetwork()
    }

    func startUpdates() {
        updateTask?.cancel()
        updateTask = Task {
            while !Task.isCancelled {
                // ---------------- CPU via PowerGadget ----------------
                if let monitor = powerMonitor, monitor.updateSamples() {
                    await MainActor.run {
                        self.cpuUsage = monitor.getIAUtilization() ?? 0
                        self.cpuTemperature = monitor.getPackageTemperature() ?? 0
                        self.cpuFrequency = monitor.getRequestFrequency() ?? 0
                        self.cpuTDP = monitor.getPackagePower() ?? 0
                    }
                }

                // ---------------- RAM / Disk / Network / GPU ----------------
                systemMonitor.updateSystemMetrics()
                systemMonitor.updateDiskAndNetwork()

                await MainActor.run {
                    // RAM
                    self.ramUsed = systemMonitor.ramUsed
                    self.ramTotal = systemMonitor.ramTotal
                    self.ramFrequency = systemMonitor.ramFrequency

                    // Disk
                    self.diskUsed = systemMonitor.diskUsed
                    self.diskTotal = systemMonitor.diskTotal

                    // Network
                    let newSent = systemMonitor.networkSent
                    let newReceived = systemMonitor.networkReceived
                    self.networkUploadSpeed = max(newSent - self.previousSent, 0)
                    self.networkDownloadSpeed = max(newReceived - self.previousReceived, 0)
                    self.previousSent = newSent
                    self.previousReceived = newReceived
                    self.networkSent = newSent
                    self.networkReceived = newReceived

                    // GPU
                    self.gpuVRAM = systemMonitor.gpuVRAM
                    self.gpuUsage = systemMonitor.gpuUsage
                }

                // Envoyer commandes au périphérique Deepcool (AK620 Pro, etc.)
                let commandData = systemMonitor.createHUDCommand()
                deviceManager.sendCommand(commandData)

                // Pause 1 seconde
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopUpdates() {
        updateTask?.cancel()
    }

    deinit {
        stopUpdates()
    }
}

// ---------------- Utilitaire ----------------
func getCPUModel() -> String {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuModel = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuModel, &size, nil, 0)
    return String(cString: cpuModel)
}


import Foundation

class ContentViewModel: ObservableObject {
    // CPU
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    let cpuModel: String
    let cpuCoreCount: Int

    // GPU
    @Published var gpuModel: String = "..."
    @Published var gpuVRAM: Double = 0.0
    @Published var gpuUsage: Double = 0.0 // ajouté

    // RAM
    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    // Disk
    @Published var diskUsed: Double = 0.0
    @Published var diskTotal: Double = 0.0

    // Network
    @Published var networkSent: Double = 0.0
    @Published var networkReceived: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0
    @Published var networkDownloadSpeed: Double = 0.0

    private let deviceManager = DeepcoolDeviceManager()
    private let systemMonitor = SystemMonitor()
    private var updateTask: Task<Void, Never>? = nil

    private var previousSent: Double = 0.0
    private var previousReceived: Double = 0.0

    init() {
        self.cpuModel = getCPUModel()
        self.cpuCoreCount = systemMonitor.cpuCoreCount

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
                systemMonitor.updateSystemMetrics()
                systemMonitor.updateDiskAndNetwork()

                await MainActor.run {
                    // CPU
                    self.cpuFrequency = systemMonitor.cpuFrequency
                    self.cpuUsage = systemMonitor.cpuUsage
                    self.cpuTemperature = systemMonitor.cpuTemperature
                    self.cpuTDP = systemMonitor.cpuTDP

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

                let commandData = systemMonitor.createHUDCommand()
                deviceManager.sendCommand(commandData)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func stopUpdates() { updateTask?.cancel() }

    deinit { stopUpdates() }
}

func getCPUModel() -> String {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuModel = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuModel, &size, nil, 0)
    return String(cString: cpuModel)
}


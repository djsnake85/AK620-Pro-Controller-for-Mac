import Foundation
import SwiftUI

extension Animation {
    static var pulseAnimation: Animation {
        .easeInOut(duration: 1).repeatForever(autoreverses: true)
    }
}

class ContentViewModel: ObservableObject {
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0
    
    let cpuModel: String
    @Published var gpuModel: String = "..." // @Published pour la mise à jour asynchrone
    let cpuCoreCount: Int
    
    @Published var animatePulse = false
    @Published var animateTitle = false

    private let deviceManager = DeepcoolDeviceManager()
    private let systemMonitor = SystemMonitor()
    private var updateTask: Task<Void, Never>? = nil

    init() {
        self.cpuModel = getCPUModel()
        self.cpuCoreCount = systemMonitor.cpuCoreCount
        
        // Appel asynchrone pour obtenir le modèle de GPU
        Task {
            let model = await systemMonitor.fetchGPUModel()
            await MainActor.run {
                self.gpuModel = model
            }
        }
        
        systemMonitor.updateRAMFrequency()
    }

    func startUpdates() {
        updateTask?.cancel()
        
        updateTask = Task {
            while !Task.isCancelled {
                systemMonitor.updateSystemMetrics()
                await MainActor.run {
                    self.cpuFrequency = systemMonitor.cpuFrequency
                    self.cpuUsage = systemMonitor.cpuUsage
                    self.cpuTemperature = systemMonitor.cpuTemperature
                    self.cpuTDP = systemMonitor.cpuTDP
                    self.ramUsed = systemMonitor.ramUsed
                    self.ramTotal = systemMonitor.ramTotal
                    self.ramFrequency = systemMonitor.ramFrequency
                    
                    withAnimation(Animation.pulseAnimation) {
                        self.animatePulse.toggle()
                        self.animateTitle.toggle()
                    }
                }

                let commandData = systemMonitor.createHUDCommand()
                deviceManager.sendCommand(commandData)
                
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

func getCPUModel() -> String {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuModel = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuModel, &size, nil, 0)
    return String(cString: cpuModel)
}



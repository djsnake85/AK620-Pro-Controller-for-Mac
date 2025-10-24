import Foundation
import IOKit
import MachO
import Darwin

class SystemMonitor: ObservableObject {
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuFanSpeed: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    @Published var cpuCoreCount: Int = 0

    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    private var pgMonitor: PowerGadgetMonitor?

    init() {
        if let monitor = PowerGadgetMonitor() {
            self.pgMonitor = monitor
        } else {
            print("Failed to initialize Power Gadget Monitor")
        }

        self.cpuCoreCount = getCpuCoreCount()
    }
    
    func updateSystemMetrics() {
        guard let monitor = self.pgMonitor else { return }
        if monitor.updateSamples() {
            if let freq = monitor.getRequestFrequency() { self.cpuFrequency = freq / 1000 }
            if let power = monitor.getPackagePower() { self.cpuTDP = power }
            if let temp = monitor.getPackageTemperature() { self.cpuTemperature = temp }
            if let util = monitor.getIAUtilization() { self.cpuUsage = util }
        }
        self.updateMemoryUsage()
    }

    private func getCpuCoreCount() -> Int {
        var size: Int = MemoryLayout<Int>.size
        var coreCount: Int = 0
        sysctlbyname("hw.ncpu", &coreCount, &size, nil, 0)
        return coreCount
    }
    
    private func updateMemoryUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let hostPort: host_t = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = vm_kernel_page_size
            let active = Double(stats.active_count) * Double(pageSize)
            let inactive = Double(stats.inactive_count) * Double(pageSize)
            let wired = Double(stats.wire_count) * Double(pageSize)
            let compressed = Double(stats.compressor_page_count) * Double(pageSize)
            let free = Double(stats.free_count) * Double(pageSize)

            let used = active + inactive + wired + compressed
            let total = used + free

            DispatchQueue.main.async {
                self.ramUsed = used / 1_073_741_824
                self.ramTotal = total / 1_073_741_824
            }
        }
    }

    func updateRAMFrequency() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments = ["SPMemoryDataType"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
            } catch {
                print("Erreur lancement system_profiler:", error)
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return
            }

            let pattern = #"(\d+)\s*MHz"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: output.utf16.count)
                if let match = regex.firstMatch(in: output, options: [], range: range),
                   let freqRange = Range(match.range(at: 1), in: output) {
                    let freqStr = String(output[freqRange])
                    if let freqDouble = Double(freqStr) {
                        DispatchQueue.main.async {
                            self.ramFrequency = freqDouble
                        }
                    }
                }
            }
        }
    }

    // Fonction modifiée pour être asynchrone
    func fetchGPUModel() async -> String {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments = ["SPDisplaysDataType"]

            let pipe = Pipe()
            task.standardOutput = pipe

            do {
                try task.run()
            } catch {
                print("Erreur lancement system_profiler pour GPU:", error)
                continuation.resume(returning: "Inconnu")
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                continuation.resume(returning: "Inconnu")
                return
            }

            let lines = output.components(separatedBy: "\n")
            var modelName = "Inconnu"

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "Chipset Model:") {
                    modelName = trimmed.replacingOccurrences(of: "Chipset Model:", with: "").trimmingCharacters(in: .whitespaces)
                    break
                }
            }
            continuation.resume(returning: modelName)
        }
    }
    
    // Ton code d'origine pour createHUDCommand() est le bon
    func createHUDCommand() -> Data {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 16
        let comando: [UInt8] = [104, 1, 4, 13, 1, 2, 8]
        for i in 0..<min(7, comando.count) {
            bytes[1 + i] = comando[i]
        }

        let tdp: UInt16 = UInt16(self.cpuTDP)
        let tdpBE = tdp.bigEndian
        withUnsafeBytes(of: tdpBE) { ptr in
            bytes[8] = ptr[0]
            bytes[9] = ptr[1]
        }

        bytes[10] = 0

        let cpuTempF32: Float32 = Float32(self.cpuTemperature)
        let cpuTempBitsBE = cpuTempF32.bitPattern.bigEndian
        withUnsafeBytes(of: cpuTempBitsBE) { ptr in
            bytes[11] = ptr[0]
            bytes[12] = ptr[1]
            bytes[13] = ptr[2]
            bytes[14] = ptr[3]
        }

        let cpuUsageValue: UInt8 = UInt8(min(max(self.cpuUsage, 0.0), 100.0))
        bytes[15] = cpuUsageValue

        let cpuFreqValue: UInt16 = UInt16(floor(self.cpuFrequency * 1000))
        let cpuFreqBE = cpuFreqValue.bigEndian
        withUnsafeBytes(of: cpuFreqBE) { ptr in
            bytes[16] = ptr[0]
            bytes[17] = ptr[1]
        }

        let checksumSum = bytes[1...17].reduce(0) { $0 + Int($1) }
        let checksum = UInt8(checksumSum % 256)
        bytes[18] = checksum

        bytes[19] = 22

        return Data(bytes)
    }
}

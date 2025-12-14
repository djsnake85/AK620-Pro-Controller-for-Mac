import Foundation
import IOKit
import Darwin
import Network

class SystemMonitor: ObservableObject {
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    @Published var cpuCoreCount: Int = 0

    @Published var ramUsed: Double = 0.0
    @Published var ramTotal: Double = 0.0
    @Published var ramFrequency: Double = 0.0

    @Published var diskUsed: Double = 0.0
    @Published var diskTotal: Double = 0.0

    @Published var networkSent: Double = 0.0
    @Published var networkReceived: Double = 0.0
    @Published var networkUploadSpeed: Double = 0.0
    @Published var networkDownloadSpeed: Double = 0.0

    // ---------- GPU ----------
    @Published var gpuVRAM: Double = 0.0 // en GB
    @Published var gpuUsage: Double = 0.0 // en %

    private var previousSent: UInt64 = 0
    private var previousReceived: UInt64 = 0
    private var previousTime: Date = Date()

    private var pgMonitor: PowerGadgetMonitor?

    init() {
        self.pgMonitor = PowerGadgetMonitor()
        self.cpuCoreCount = getCpuCoreCount()
    }

    func updateSystemMetrics() {
        guard let monitor = self.pgMonitor else { return }
        if monitor.updateSamples() {
            if let freq = monitor.getRequestFrequency() { self.cpuFrequency = freq }
            if let power = monitor.getPackagePower() { self.cpuTDP = power }
            if let temp = monitor.getPackageTemperature() { self.cpuTemperature = temp }
            if let util = monitor.getIAUtilization() { self.cpuUsage = util }
        }
        self.updateMemoryUsage()
        self.updateGPUUsage()
    }

    // ---------- CPU ----------
    private func getCpuCoreCount() -> Int {
        var size = MemoryLayout<Int>.size
        var count = 0
        sysctlbyname("hw.ncpu", &count, &size, nil, 0)
        return count
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
            try? task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            let pattern = #"(\d+)\s*MHz"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: output.utf16.count)
                if let match = regex.firstMatch(in: output, options: [], range: range),
                   let freqRange = Range(match.range(at: 1), in: output),
                   let freqDouble = Double(output[freqRange]) {
                    DispatchQueue.main.async { self.ramFrequency = freqDouble }
                }
            }
        }
    }

    // ---------- Disk & Network ----------
    func updateDiskAndNetwork() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let used = (attrs[.systemSize] as? NSNumber)?.doubleValue ?? 0.0
            let free = (attrs[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0.0
            let total = used
            DispatchQueue.main.async {
                self.diskUsed = total - free
                self.diskTotal = total
            }
        }

        var sent: UInt64 = 0
        var received: UInt64 = 0

        var addrs: UnsafeMutablePointer<ifaddrs>? = nil
        if getifaddrs(&addrs) == 0, let firstAddr = addrs {
            var ptr = firstAddr
            while ptr.pointee.ifa_next != nil {
                let data = ptr.pointee.ifa_data
                if let data = data?.assumingMemoryBound(to: if_data.self).pointee {
                    sent += UInt64(data.ifi_obytes)
                    received += UInt64(data.ifi_ibytes)
                }
                ptr = ptr.pointee.ifa_next!
            }
            freeifaddrs(addrs)
        }

        let now = Date()
        let interval = now.timeIntervalSince(previousTime)
        if interval > 0 {
            DispatchQueue.main.async {
                self.networkUploadSpeed = Double(sent - self.previousSent) / interval
                self.networkDownloadSpeed = Double(received - self.previousReceived) / interval
            }
        }
        previousSent = sent
        previousReceived = received

        DispatchQueue.main.async {
            self.networkSent = Double(sent)
            self.networkReceived = Double(received)
        }
    }

    // ---------- GPU ----------
    func fetchGPUModel() async -> String {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments = ["SPDisplaysDataType"]
            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                continuation.resume(returning: "Inconnu")
                return
            }

            // Récupère le modèle GPU
            let model = output.components(separatedBy: "\n").first { $0.trimmingCharacters(in: .whitespaces).starts(with: "Chipset Model:") }?
                .replacingOccurrences(of: "Chipset Model:", with: "")
                .trimmingCharacters(in: .whitespaces) ?? "Inconnu"

            // Récupère la VRAM
            if let vramLine = output.components(separatedBy: "\n").first(where: { $0.trimmingCharacters(in: .whitespaces).starts(with: "VRAM (Total):") }) {
                let vramStr = vramLine.replacingOccurrences(of: "VRAM (Total):", with: "").trimmingCharacters(in: .whitespaces)
                if vramStr.contains("GB"), let value = Double(vramStr.replacingOccurrences(of: "GB", with: "").trimmingCharacters(in: .whitespaces)) {
                    DispatchQueue.main.async { self.gpuVRAM = value }
                } else if vramStr.contains("MB"), let value = Double(vramStr.replacingOccurrences(of: "MB", with: "").trimmingCharacters(in: .whitespaces)) {
                    DispatchQueue.main.async { self.gpuVRAM = value / 1024.0 }
                }
            }

            continuation.resume(returning: model)
        }
    }

    func updateGPUUsage() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.launchPath = "/usr/bin/env"
            task.arguments = ["sudo", "powermetrics", "--samplers", "smc", "-n1"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe() // ignore errors

            do {
                try task.run()
            } catch {
                print("Erreur powermetrics: \(error)")
                return
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            let lines = output.split(separator: "\n")
            for line in lines {
                if line.contains("GPU Busy") {
                    if let percentStr = line.split(separator: ":").last?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .replacingOccurrences(of: "%", with: ""),
                       let percent = Double(percentStr) {
                        DispatchQueue.main.async {
                            self.gpuUsage = percent
                        }
                        break
                    }
                }
            }
        }
    }

    // ---------- HUD Command ----------
       func createHUDCommand() -> Data {
           var bytes = [UInt8](repeating: 0, count: 20)
           bytes[0] = 16
           let comando: [UInt8] = [104, 1, 4, 13, 1, 2, 8]
           for i in 0..<min(7, comando.count) { bytes[1+i] = comando[i] }

           let tdp: UInt16 = UInt16(self.cpuTDP)
           let tdpBE = tdp.bigEndian
           withUnsafeBytes(of: tdpBE) { ptr in bytes[8] = ptr[0]; bytes[9] = ptr[1] }

           let cpuTempF32: Float32 = Float32(self.cpuTemperature)
           let cpuTempBitsBE = cpuTempF32.bitPattern.bigEndian
           withUnsafeBytes(of: cpuTempBitsBE) { ptr in
               bytes[11] = ptr[0]; bytes[12] = ptr[1]; bytes[13] = ptr[2]; bytes[14] = ptr[3]
           }

           bytes[15] = UInt8(min(max(self.cpuUsage, 0), 100))
           let cpuFreqValue: UInt16 = UInt16(floor(self.cpuFrequency))
           let cpuFreqBE = cpuFreqValue.bigEndian
           withUnsafeBytes(of: cpuFreqBE) { ptr in bytes[16] = ptr[0]; bytes[17] = ptr[1] }

           let checksum = UInt8(bytes[1...17].reduce(0) { $0 + Int($1) } % 256)
           bytes[18] = checksum
           bytes[19] = 22

           return Data(bytes)
       }
   }

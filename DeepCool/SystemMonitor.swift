import Foundation
import IOKit
import Darwin
import AppKit
import CoreWLAN


enum PowermetricsAuthorization {

    private static let sudoersPath = "/etc/sudoers.d/powermetrics"


    static func isAuthorized() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments  = ["-n", "/usr/bin/powermetrics", "-h"]
        task.standardOutput = Pipe()
        task.standardError  = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    
    static func requestAuthorization(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let user = NSUserName()

            let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/powermetrics"
            let shellCommand = "echo '\(rule)' > \(sudoersPath) && chmod 440 \(sudoersPath)"
            let appleScriptSource = "do shell script \"\(shellCommand)\" with administrator privileges"

            var errorDict: NSDictionary?
            let script = NSAppleScript(source: appleScriptSource)
            script?.executeAndReturnError(&errorDict)

            if let errorDict {
                #if DEBUG
                print("[PowermetricsAuthorization] Échec ou annulation par l'utilisateur : \(errorDict)")
                #endif
                DispatchQueue.main.async { completion(false) }
                return
            }

            let success = isAuthorized()
            DispatchQueue.main.async { completion(success) }
        }
    }
}

class SystemMonitor: ObservableObject {

    // ---------- CPU ----------
    @Published var cpuFrequency: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var cpuTemperature: Double = 0.0
    @Published var cpuTDP: Double = 0.0
    @Published var cpuFanRPM: Double = 0.0
    // CORRECTION : confirmé par l'utilisateur via test terminal — F0Ac
    // est en réalité le ventilateur du BOÎTIER (chassis), F1Ac est le
    // vrai ventilateur CPU (AK620). On n'affiche donc que F1Ac comme
    // "ventilateur CPU" ; F0Ac est gardé à part (chassisFanRPM) si besoin
    // de l'afficher ailleurs plus tard.
    @Published var chassisFanRPM: Double = 0.0
    @Published var cpuCoreCount: Int = 0

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

    // ---------- GPU ----------
    @Published var gpuVRAM: Double = 0.0
    @Published var gpuUsage: Double = 0.0
   
    @Published var gpuVRAMUsed: Double = 0.0
    @Published var gpuTemperature: Double = 0.0
    @Published var gpuFanRPM: Double = 0.0
    @Published var gpuFanPercent: Double = 0.0
    @Published var gpuFrequency: Double = 0.0
    @Published var gpuTDP: Double = 0.0

    // ---------- Network Info (IP / Routeur / Wi-Fi) ----------
    @Published var ipAddress: String = "..."
    @Published var routerAddress: String = "..."
    @Published var wifiPhyMode: String = "..."
    @Published var wifiChannel: String = "..."
    @Published var wifiLinkSpeed: Double = 0.0   // Mb/s négociés (débit de liaison, pas le débit réel)
    @Published var wifiSignalDBm: Int = 0         // Force du signal Wi-Fi reçu (RSSI, en dBm)

    // ---------- Private ----------
    private var previousSent: UInt64 = 0
    private var previousReceived: UInt64 = 0
    private var previousNetworkCheck: Date = Date()
    private var pgMonitor: PowerGadgetMonitor?

    
    private var gpuUsageTask: Task<Void, Never>? = nil

   
    private var networkInfoTask: Task<Void, Never>? = nil

    init() {
        self.pgMonitor = PowerGadgetMonitor()
        self.cpuCoreCount = getCpuCoreCount()
        startGPUUsageLoop()
        startNetworkInfoLoop()
    }

    deinit {
        gpuUsageTask?.cancel()
        networkInfoTask?.cancel()
    }

    // MARK: - System Update

    func updateSystemMetrics() {
        guard let monitor = self.pgMonitor else { return }

        if monitor.updateSamples() {
            if let freq  = monitor.getRequestFrequency()    { self.cpuFrequency    = freq  }
            if let power = monitor.getPackagePower()        { self.cpuTDP          = power }
            if let temp  = monitor.getPackageTemperature()  { self.cpuTemperature  = temp  }
            if let util  = monitor.getIAUtilization()       { self.cpuUsage        = util  }
        }

        self.updateMemoryUsage()
        self.updateDiskAndNetwork()
        self.updateGPUTemperature()
        self.updateCPUFanSpeed()
        // NOTE : GPU usage géré par startGPUUsageLoop(), pas ici
    }

    private func getCpuCoreCount() -> Int {
        var size = MemoryLayout<Int>.size
        var count = 0
        sysctlbyname("hw.ncpu", &count, &size, nil, 0)
        return count
    }

    // MARK: - RAM

    private func updateMemoryUsage() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let hostPort: host_t = mach_host_self()

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize   = vm_kernel_page_size
            let active     = Double(stats.active_count)          * Double(pageSize)
            let wired      = Double(stats.wire_count)            * Double(pageSize)
            let compressed = Double(stats.compressor_page_count) * Double(pageSize)

            // CORRECTION : "inactive_count" correspond à des pages en cache
            // immédiatement récupérables (fichiers mis en cache). Le Moniteur
            // d'activité macOS ne les compte PAS dans "Mémoire utilisée" — il
            // les affiche séparément sous "Fichiers en cache". Les inclure
            // gonflait l'usage affiché de plusieurs Go par rapport au Moniteur
            // d'activité. On reproduit donc son calcul : App + Wired + Compressé.
            let used  = active + wired + compressed
            let total = Double(ProcessInfo.processInfo.physicalMemory)

            DispatchQueue.main.async {
                self.ramUsed  = used  / 1_073_741_824
                self.ramTotal = total / 1_073_741_824
            }
        }
    }

    func updateRAMFrequency() {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments  = ["SPMemoryDataType"]

            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            let pattern = #"(\d+)\s*MHz"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: output.utf16.count)
                if let match     = regex.firstMatch(in: output, range: range),
                   let freqRange = Range(match.range(at: 1), in: output),
                   let freqDouble = Double(output[freqRange]) {
                    DispatchQueue.main.async { self.ramFrequency = freqDouble }
                }
            }
        }
    }



    func updateDiskAndNetwork() {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            let total = (attrs[.systemSize]     as? NSNumber)?.doubleValue ?? 0
            let free  = (attrs[.systemFreeSize] as? NSNumber)?.doubleValue ?? 0
            DispatchQueue.main.async {
                self.diskTotal = total / 1_073_741_824
                self.diskUsed  = (total - free) / 1_073_741_824
            }
        }

        var sent: UInt64 = 0
        var received: UInt64 = 0
        var addrs: UnsafeMutablePointer<ifaddrs>? = nil

        if getifaddrs(&addrs) == 0, let firstAddr = addrs {
            var ptr = firstAddr
            while true {
                if let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
                    sent     = sent     &+ UInt64(data.ifi_obytes)
                    received = received &+ UInt64(data.ifi_ibytes)
                }
                guard let next = ptr.pointee.ifa_next else { break }
                ptr = next
            }
            freeifaddrs(addrs)
        }

        let now      = Date()
        let interval = now.timeIntervalSince(previousNetworkCheck)

        if interval > 0 {
            let uploadDelta   = abs(Int64(sent)     - Int64(previousSent))
            let downloadDelta = abs(Int64(received) - Int64(previousReceived))
            DispatchQueue.main.async {
                self.networkUploadSpeed   = Double(uploadDelta)   / interval
                self.networkDownloadSpeed = Double(downloadDelta) / interval
                self.networkSent          = Double(sent)
                self.networkReceived      = Double(received)
            }
        }

        // Variables privées : mises à jour sur le thread appelant (background task)
        previousSent         = sent
        previousReceived     = received
        previousNetworkCheck = now
    }

    // MARK: - Network Info (IP / Routeur / Wi-Fi)

    private func startNetworkInfoLoop() {
        networkInfoTask?.cancel()
        networkInfoTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.updateNetworkInfo()
                // CoreWLAN ne scanne pas (contrairement à l'ancienne
                // méthode via system_profiler) : un intervalle court n'a
                // plus d'impact sur le débit Wi-Fi.
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func updateNetworkInfo() {
        let (interface, gateway) = defaultRouteInfo()
        let ip = interface.flatMap { localIPv4Address(forInterface: $0) }

        var phyMode = ""
        var channel = ""
        var linkSpeed: Double = 0
        var signalDBm: Int = 0

        if let interface, isWiFiInterface(interface) {
            let wifi   = wifiCurrentNetworkInfo(interface: interface)
            phyMode    = wifi.phyMode
            channel    = wifi.channel
            linkSpeed  = wifi.transmitRateMbps
            signalDBm  = wifi.signalDBm ?? 0
        }

        DispatchQueue.main.async {
            self.ipAddress     = ip ?? "Inconnue"
            self.routerAddress = (gateway?.isEmpty == false) ? gateway! : "Inconnu"
            self.wifiPhyMode   = phyMode.isEmpty ? "N/A (Ethernet)" : phyMode
            self.wifiChannel   = channel.isEmpty ? "N/A" : channel
            self.wifiLinkSpeed = linkSpeed
            self.wifiSignalDBm = signalDBm
        }
    }

    /// Interface de sortie ("en0", ...) et adresse de la passerelle par
    /// défaut, via "route -n get default".
    private func defaultRouteInfo() -> (interface: String?, gateway: String?) {
        let task = Process()
        task.launchPath = "/sbin/route"
        task.arguments  = ["-n", "get", "default"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run() } catch { return (nil, nil) }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return (nil, nil) }

        var interface: String?
        var gateway: String?
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                interface = trimmed.replacingOccurrences(of: "interface:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("gateway:") {
                gateway = trimmed.replacingOccurrences(of: "gateway:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return (interface, gateway)
    }

    
    private func localIPv4Address(forInterface interfaceName: String) -> String? {
        var addrs: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&addrs) == 0, let firstAddr = addrs else { return nil }
        defer { freeifaddrs(addrs) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }
            let name = String(cString: current.pointee.ifa_name)
            guard name == interfaceName,
                  let addr = current.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                        &host, socklen_t(host.count),
                        nil, 0, NI_NUMERICHOST)
            return String(cString: host)
        }
        return nil
    }

    // MARK: - Wi-Fi via CoreWLAN
    // CORRECTION MAJEURE : la version précédente utilisait
    // "system_profiler SPAirPortDataType" pour lire PHY/canal/signal.
    // Cette commande DÉCLENCHE UN SCAN WI-FI ACTIF (pour lister les
    // réseaux voisins), ce qui force la carte à quitter brièvement son
    // canal actuel — appelé toutes les 1-2s, ça dégradait réellement le
    // débit/la latence pendant que l'app tournait (symptôme signalé :
    // "la vitesse internet chute quand je lance l'application").
    // CoreWLAN (CWInterface) lit en direct les stats de l'interface DÉJÀ
    // CONNECTÉE (RSSI, PHY, canal, débit de liaison) sans jamais scanner
    // les réseaux voisins — aucun impact sur le débit, même à haute
    // fréquence. Ne nécessite pas d'autorisation de localisation tant
    // qu'on ne lit pas le SSID/BSSID (non utilisés ici).

    private struct WiFiCurrentNetwork {
        var phyMode: String = ""
        var channel: String = ""
        var transmitRateMbps: Double = 0
        var signalDBm: Int? = nil
    }

    /// Vrai si l'interface donnée est gérée par CoreWLAN (donc Wi-Fi).
    private func isWiFiInterface(_ interfaceName: String) -> Bool {
        CWWiFiClient.shared().interface(withName: interfaceName) != nil
    }

    /// Lit les infos de l'interface Wi-Fi connectée via CoreWLAN — aucun
    /// scan déclenché, contrairement à system_profiler.
    private func wifiCurrentNetworkInfo(interface interfaceName: String) -> WiFiCurrentNetwork {
        guard let wifi = CWWiFiClient.shared().interface(withName: interfaceName) else {
            return WiFiCurrentNetwork()
        }

        var result = WiFiCurrentNetwork()

        let rssi = wifi.rssiValue()
        if rssi != 0 { result.signalDBm = rssi }

        if let channel = wifi.wlanChannel() {
            let band: String
            switch channel.channelBand {
            case .band2GHz: band = "2.4GHz"
            case .band5GHz: band = "5GHz"
            case .band6GHz: band = "6GHz"
            default: band = ""
            }
            let width: String
            switch channel.channelWidth {
            case .width20MHz:  width = "20MHz"
            case .width40MHz:  width = "40MHz"
            case .width80MHz:  width = "80MHz"
            case .width160MHz: width = "160MHz"
            default: width = ""
            }
            result.channel = "\(channel.channelNumber) (\(band), \(width))"
        }

        switch wifi.activePHYMode() {
        case .mode11a:  result.phyMode = "802.11a"
        case .mode11b:  result.phyMode = "802.11b"
        case .mode11g:  result.phyMode = "802.11g"
        case .mode11n:  result.phyMode = "802.11n"
        case .mode11ac: result.phyMode = "802.11ac"
        case .mode11ax: result.phyMode = "802.11ax"
        default: break
        }

        result.transmitRateMbps = wifi.transmitRate()

        return result
    }



    func fetchDiskModel() async -> String {
        await withCheckedContinuation { continuation in
            let wholeDiskIdentifier = physicalWholeDiskIdentifier()

            if let identifier = wholeDiskIdentifier,
               let model = nvmeModelName(forBSDName: identifier) {
                continuation.resume(returning: model)
                return
            }

        
            let fallbackIdentifier = wholeDiskIdentifier ?? "/"
            if let output = runDiskutilInfo(identifier: fallbackIdentifier) {
                var model = output.components(separatedBy: "\n")
                    .first { $0.contains("Device / Media Name:") }?
                    .replacingOccurrences(of: "Device / Media Name:", with: "")
                    .trimmingCharacters(in: .whitespaces) ?? ""
                if model.hasSuffix(" Media") {
                    model = String(model.dropLast(" Media".count))
                }
                if !model.isEmpty {
                    continuation.resume(returning: model)
                    return
                }
            }

            continuation.resume(returning: "Inconnu")
        }
    }

   
    private func physicalWholeDiskIdentifier() -> String? {
        guard let rootInfo = runDiskutilInfo(identifier: "/") else { return nil }

        guard let physicalLine = rootInfo.components(separatedBy: "\n")
            .first(where: { $0.contains("APFS Physical Store:") }) else {
            return nil
        }

        let storeIdentifier = physicalLine
            .replacingOccurrences(of: "APFS Physical Store:", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !storeIdentifier.isEmpty else { return nil }

        // "diskNsM" (partition) -> "diskN" (disque entier).
        guard let range = storeIdentifier.range(of: #"^disk\d+"#, options: .regularExpression) else {
            return storeIdentifier
        }
        return String(storeIdentifier[range])
    }

   
    private func nvmeModelName(forBSDName bsdName: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments  = ["SPNVMeDataType"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run() } catch { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return nil }

        let lines = output.components(separatedBy: "\n")
        guard let bsdLineIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "BSD Name: \(bsdName)"
        }) else { return nil }

        let bsdIndent = lines[bsdLineIndex].prefix(while: { $0 == " " }).count
        var i = bsdLineIndex - 1
        while i >= 0 {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = line.prefix(while: { $0 == " " }).count
            
            if !trimmed.isEmpty, trimmed.hasSuffix(":"), indent < bsdIndent {
                return String(trimmed.dropLast())
            }
            i -= 1
        }
        return nil
    }

  
    private func runDiskutilInfo(identifier: String) -> String? {
        let task = Process()
        task.launchPath = "/usr/sbin/diskutil"
        task.arguments  = ["info", identifier]

        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }

   

    func fetchGPUModelAndVRAM() async -> (model: String, vram: Double) {
        await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/usr/sbin/system_profiler"
            task.arguments  = ["SPDisplaysDataType"]

            let pipe = Pipe()
            task.standardOutput = pipe
            try? task.run()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                continuation.resume(returning: ("Inconnu", 0.0))
                return
            }

            let lines = output.components(separatedBy: "\n")

            // Modèle GPU
            let model = lines
                .first { $0.contains("Chipset Model:") }?
                .replacingOccurrences(of: "Chipset Model:", with: "")
                .trimmingCharacters(in: .whitespaces) ?? "Inconnu"

            // VRAM — cherche "VRAM (Total): 8 GB" ou "VRAM (Dynamic, Max): 2048 MB"
            var vramGB: Double = 0.0
            let pattern = #"(\d+)\s*(GB|MB|gb|mb)"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                for line in lines {
                    guard line.lowercased().contains("vram") else { continue }
                    let nsLine = line as NSString
                    let range  = NSRange(location: 0, length: nsLine.length)
                    guard let match      = regex.firstMatch(in: line, range: range),
                          let valueRange = Range(match.range(at: 1), in: line),
                          let unitRange  = Range(match.range(at: 2), in: line)
                    else { continue }
                    let value = Double(line[valueRange]) ?? 0
                    let unit  = line[unitRange].uppercased()
                    vramGB = unit == "MB" ? value / 1024.0 : value
                    break
                }
            }

            continuation.resume(returning: (model, vramGB))
        }
    }

    // Conservés pour compatibilité si appelés ailleurs
    func fetchGPUModel() async -> String {
        await fetchGPUModelAndVRAM().model
    }

    func fetchGPUVRAM() async -> Double {
        await fetchGPUModelAndVRAM().vram
    }



    private func startGPUUsageLoop() {
        gpuUsageTask?.cancel()
        gpuUsageTask = Task.detached(priority: .background) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.readGPUUsageOnce()
                self.readGPUVRAMUsage()
                // Aligné sur le "-i 500" de powermetrics ci-dessus.
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func readGPUUsageOnce() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let task = Process()
 
            task.launchPath = "/usr/bin/sudo"
        
            task.arguments  = ["-n", "/usr/bin/powermetrics", "--samplers", "smc", "-i", "500", "-n1"]

            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError  = errPipe

            do {
                try task.run()
            } catch {
                #if DEBUG
                print("[SystemMonitor] Impossible de lancer powermetrics : \(error)")
                #endif
                continuation.resume()
                return
            }

            let data = outPipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            #if DEBUG
            if task.terminationStatus != 0 {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errStr  = String(data: errData, encoding: .utf8) ?? "?"
                print("[SystemMonitor] powermetrics a échoué (code \(task.terminationStatus)) : \(errStr)")
            }
            #endif

            guard let output = String(data: data, encoding: .utf8) else {
                continuation.resume()
                return
            }

            for line in output.split(separator: "\n") {
                if line.contains("GPU Busy"),
                   let percentStr = line.split(separator: ":").last?
                       .trimmingCharacters(in: .whitespacesAndNewlines)
                       .replacingOccurrences(of: "%", with: ""),
                   let percent = Double(percentStr) {
                    DispatchQueue.main.async { self.gpuUsage = percent }
                }

                // AJOUT : sur Apple Silicon, le sampler "smc" de powermetrics
                // expose la température GPU via cette ligne — contrairement aux
                // clés SMC TG0D/TG0P qui ne concernent que les GPU discrets Intel/AMD.
                if line.contains("GPU die temperature"),
                   let tempStr = line.split(separator: ":").last?
                       .trimmingCharacters(in: .whitespacesAndNewlines)
                       .replacingOccurrences(of: "C", with: "")
                       .trimmingCharacters(in: .whitespaces),
                   let temp = Double(tempStr) {
                    DispatchQueue.main.async { self.gpuTemperature = temp }
                }
            }
            continuation.resume()
        }
    }



    private func readGPUVRAMUsage() {
        let task = Process()
        task.launchPath = "/usr/sbin/ioreg"

        task.arguments  = ["-a", "-l", "-w0"]

        let pipe = Pipe()
        task.standardOutput = pipe
        do { try task.run() } catch { return }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil)
        else { return }

        var allStats: [[String: Any]] = []
        collectPerformanceStatistics(in: root, into: &allStats)


        let stats = allStats.first {
            $0["inUseVidMemoryBytes"] != nil || $0["vramUsedBytes"] != nil || $0["vramFreeBytes"] != nil
        } ?? allStats.first {
            $0["GPU Core Utilization"] != nil || $0["Device Utilization %"] != nil || $0["GPU Activity(%)"] != nil
        }

        guard let stats else { return }

        // VRAM utilisée + total
        if let usedBytes = (stats["inUseVidMemoryBytes"] as? NSNumber)?.doubleValue
            ?? (stats["vramUsedBytes"] as? NSNumber)?.doubleValue {
            let usedGB = usedBytes / 1_073_741_824.0
            DispatchQueue.main.async { self.gpuVRAMUsed = usedGB }

            if let freeBytes = (stats["vramFreeBytes"] as? NSNumber)?.doubleValue {
                let totalGB = (usedBytes + freeBytes) / 1_073_741_824.0
                DispatchQueue.main.async { self.gpuVRAM = totalGB }
            }
        } else if let freeBytes = (stats["vramFreeBytes"] as? NSNumber)?.doubleValue {
            // Repli : seule "vramFreeBytes" existe (pas de clé "used"
            // directe) — on déduit l'utilisé depuis le total déjà connu.
            let freeGB = freeBytes / 1_073_741_824.0
            DispatchQueue.main.async {
                let total = self.gpuVRAM > 0 ? self.gpuVRAM : freeGB
                self.gpuVRAMUsed = max(total - freeGB, 0)
            }
        } else if let usedBytes = (stats["In use system memory"] as? NSNumber)?.doubleValue {
            let usedGB = usedBytes / 1_073_741_824.0
            DispatchQueue.main.async { self.gpuVRAMUsed = usedGB }
        }

        // Charge GPU
        if let coreUse = (stats["GPU Core Utilization"] as? NSNumber)?.doubleValue {
            let percent = min(max(coreUse / 1_000_000_000.0 * 100.0, 0), 100)
            DispatchQueue.main.async { self.gpuUsage = percent }
        } else if let devicePercent = (stats["Device Utilization %"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuUsage = devicePercent }
        } else if let activityPercent = (stats["GPU Activity(%)"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuUsage = activityPercent }
        }

        // Ventilateur GPU — exposé directement par le driver AMD dans ce
        // même dictionnaire "PerformanceStatistics" (confirmé par test :
        // "Fan Speed(RPM)" présent, contrairement aux clés SMC F*Ac qui ne
        // couvrent que les ventilateurs pilotés par le Super I/O de la
        // carte mère). Pas besoin de SMCRadeonSensors ni de SMC ici.
        if let fanRPM = (stats["Fan Speed(RPM)"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuFanRPM = fanRPM }
        }
        if let fanPercent = (stats["Fan Speed(%)"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuFanPercent = fanPercent }
        }

        // Fréquence GPU — même dictionnaire, exposée par le driver AMD.
        if let coreClock = (stats["Core Clock(MHz)"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuFrequency = coreClock }
        }

        // TDP GPU — même dictionnaire, exposé par le driver AMD.
        if let totalPower = (stats["Total Power(W)"] as? NSNumber)?.doubleValue {
            DispatchQueue.main.async { self.gpuTDP = totalPower }
        }
    }

    private func collectPerformanceStatistics(in node: Any, into results: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            if let stats = dict["PerformanceStatistics"] as? [String: Any] {
                results.append(stats)
            }
            if let children = dict["IORegistryEntryChildren"] as? [Any] {
                for child in children {
                    collectPerformanceStatistics(in: child, into: &results)
                }
            }
        } else if let array = node as? [Any] {
            for item in array {
                collectPerformanceStatistics(in: item, into: &results)
            }
        }
    }

    // MARK: - GPU Temperature via SMCRadeonSensor
    // NOTE : ne fonctionne que sur Mac Intel avec GPU discret AMD (clés TG0D/TG0P).
    // Sur Apple Silicon, ces clés SMC n'existent pas — la température GPU est
    // alors récupérée via readGPUUsageOnce() (powermetrics --samplers smc,
    // ligne "GPU die temperature"), qui écrase gpuTemperature si elle trouve mieux.

    private func updateGPUTemperature() {
        let smcKeys: [String] = ["TG0D", "TG0P", "TG0d", "TG0p", "TGDD"]
        for key in smcKeys {
            if let temp = readSMCTemperature(key: key), temp > 0, temp < 150 {
                DispatchQueue.main.async { self.gpuTemperature = temp }
                return
            }
        }
    }

    private func readSMCTemperature(key: String) -> Double? {
        guard let smc = readSMCKey(key: key) else { return nil }
        let hi   = Double(smc.bytes.byte0)
        let lo   = Double(smc.bytes.byte1) / 256.0
        let temp = hi + lo
        return temp > 0 ? temp : nil
    }

    // MARK: - CPU Fan Speed via SMC
    // Clés SMC standard des ventilateurs Mac : "F0Ac" = vitesse RÉELLE du
    // ventilateur 0, "F1Ac" = ventilateur 1. Exposées ici via SMCSuperIO
    // (lecture des en-têtes ventilateurs de la carte mère par la puce
    // Super I/O), présent dans la configuration EFI de cette machine.
    // CONFIRMÉ par test terminal : F0Ac = ventilateur BOÎTIER, F1Ac =
    // ventilateur CPU (AK620). Contrairement à la température (format
    // "SP78"), la vitesse ventilateur utilise le format SMC "fpe2" :
    // 16 bits = 14 bits entiers + 2 bits fractionnaires, donc
    // RPM = valeur_brute / 4.

    private func updateCPUFanSpeed() {
        let chassis = readSMCFanRPM(key: "F0Ac")
        let cpu     = readSMCFanRPM(key: "F1Ac")

        DispatchQueue.main.async {
            if let chassis, chassis > 0, chassis < 10_000 {
                self.chassisFanRPM = chassis
            }
            if let cpu, cpu > 0, cpu < 10_000 {
                self.cpuFanRPM = cpu
            }
        }
    }

    private func readSMCFanRPM(key: String) -> Double? {
        guard let smc = readSMCKey(key: key) else { return nil }
        let raw = (UInt16(smc.bytes.byte0) << 8) | UInt16(smc.bytes.byte1)
        return Double(raw) / 4.0
    }

    /// Lecture SMC bas niveau, commune à la température et au ventilateur.
    /// CORRECTION CRITIQUE (VirtualSMC) : la structure Swift native
    /// SMCKeyData_t (définie plus bas) nécessite un champ "padding: UInt16"
    /// explicite entre "keyInfo" et "result" pour matcher EXACTEMENT le
    /// layout mémoire attendu par le driver SMC. Sans ce champ, la taille
    /// de la structure ne correspond pas à ce qu'attend VirtualSMC, qui
    /// rejette la requête avec kIOReturnBadArgument (-536870206) — plus
    /// strict sur ce point que le SMC matériel réel, qui tolère l'écart.
    private func readSMCKey(key: String) -> SMCKeyData_t? {
        let masterPort: mach_port_t
        if #available(macOS 12.0, *) {
            masterPort = kIOMainPortDefault
        } else {
            masterPort = kIOMasterPortDefault
        }

        let service = IOServiceGetMatchingService(masterPort, IOServiceMatching("AppleSMC"))
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var conn: io_connect_t = 0
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == kIOReturnSuccess else { return nil }
        defer { IOServiceClose(conn) }

        var inputStruct  = SMCKeyData_t()
        var outputStruct = SMCKeyData_t()
        let inputSize    = MemoryLayout<SMCKeyData_t>.size
        var outputSize   = MemoryLayout<SMCKeyData_t>.size

        let keyBytes = Array(key.utf8)
        guard keyBytes.count == 4 else { return nil }
        inputStruct.key = UInt32(keyBytes[0]) << 24
                        | UInt32(keyBytes[1]) << 16
                        | UInt32(keyBytes[2]) << 8
                        | UInt32(keyBytes[3])
        inputStruct.data8 = SMC_CMD_READ_KEYINFO

        guard IOConnectCallStructMethod(conn, UInt32(KERNEL_INDEX_SMC), &inputStruct, inputSize, &outputStruct, &outputSize) == kIOReturnSuccess else {
            return nil
        }

        inputStruct.keyInfo = outputStruct.keyInfo
        inputStruct.data8   = SMC_CMD_READ_BYTES

        guard IOConnectCallStructMethod(conn, UInt32(KERNEL_INDEX_SMC), &inputStruct, inputSize, &outputStruct, &outputSize) == kIOReturnSuccess else {
            return nil
        }

        return outputStruct
    }

    // MARK: - HUD Command

    func createHUDCommandAK620G2Nyx() -> Data {
        var bytes = [UInt8](repeating: 0, count: 20)
        bytes[0] = 16

        let comando: [UInt8] = [104, 1, 8, 12, 1, 2, 1]
        for i in 0..<min(7, comando.count) { bytes[1 + i] = comando[i] }

        let tdpBE = UInt16(cpuTDP).bigEndian
        withUnsafeBytes(of: tdpBE) { ptr in bytes[7] = ptr[0]; bytes[8] = ptr[1] }

        let cpuTempBitsBE = Float32(cpuTemperature).bitPattern.bigEndian
        withUnsafeBytes(of: cpuTempBitsBE) { ptr in
            bytes[10] = ptr[0]; bytes[11] = ptr[1]
            bytes[12] = ptr[2]; bytes[13] = ptr[3]
        }

        bytes[14] = UInt8(min(max(cpuUsage, 0), 100))

        let cpuFreqBE = UInt16(floor(cpuFrequency)).bigEndian
        withUnsafeBytes(of: cpuFreqBE) { ptr in bytes[15] = ptr[0]; bytes[16] = ptr[1] }

        bytes[17] = UInt8(bytes[1...16].reduce(0) { $0 + Int($1) } & 0xFF)
        bytes[18] = 22

        return Data(bytes)
    }
}

// MARK: - Structures SMC bas niveau
// CORRECTION CRITIQUE (VirtualSMC) : structure Swift native avec un champ
// "padding: UInt16" EXPLICITE entre "keyInfo" et "result" — indispensable
// pour que le layout mémoire calculé par Swift corresponde exactement à
// celui attendu par le driver SMC (réel ou VirtualSMC). Sans ce champ,
// VirtualSMC rejetait la requête avec kIOReturnBadArgument
// (-536870206), plus strict sur ce point que le SMC matériel réel.

private let KERNEL_INDEX_SMC: UInt32    = 2
private let SMC_CMD_READ_BYTES: UInt8   = 5
private let SMC_CMD_READ_KEYINFO: UInt8 = 9

private struct SMCVersion {
    var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0
    var reserved: UInt8 = 0, release: UInt16 = 0
}

private struct SMCPLimitData {
    var version: UInt16 = 0, length: UInt16 = 0
    var cpuPLimit: UInt32 = 0, gpuPLimit: UInt32 = 0, memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

private struct SMCBytes {
    var b: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
            UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0)
    var byte0: UInt8 { b.0 }
    var byte1: UInt8 { b.1 }
}

private struct SMCKeyData_t {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0 // Alignement C indispensable
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes = SMCBytes()
}

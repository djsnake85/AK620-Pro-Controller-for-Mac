import Foundation
import IOKit.hid

class DeepcoolDeviceManager: ObservableObject {
    private var hidManager: IOHIDManager!
    @Published var device: IOHIDDevice?
    @Published var deviceType: DeviceType = .pro

    enum DeviceType {
        case pro
        case g2Nyx
    }

    init() {
        setupHIDManager()
    }

    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchingDicts: [[String: Any]] = [
            [kIOHIDVendorIDKey as String: 0x3633, kIOHIDProductIDKey as String: 0x0012], // AK620 Pro
            [kIOHIDVendorIDKey as String: 0x3633, kIOHIDProductIDKey as String: 0x0029]  // AK620 G2 Nyx
        ]

        let dictsCF = matchingDicts.map { $0 as CFDictionary } as CFArray
        IOHIDManagerSetDeviceMatchingMultiple(hidManager, dictsCF)

        let result = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            print("Error opening HID Manager: \(result)")
            return
        }

        if let deviceSet = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice>,
           let foundDevice = deviceSet.first {
            self.device = foundDevice
            let pid = IOHIDDeviceGetProperty(foundDevice, kIOHIDProductIDKey as CFString) as? Int ?? 0
            self.deviceType = (pid == 0x0029) ? .g2Nyx : .pro
            print("Device connected: \(self.deviceType == .pro ? "AK620 Pro" : "AK620 G2 Nyx")")
        } else {
            print("Device not found")
        }
    }

    func sendCommand(_ command: Data) {
        guard let device = self.device else {
            print("Device unavailable for sending commands")
            return
        }
        let reportID: CFIndex = 0
        command.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            if let pointer = buffer.bindMemory(to: UInt8.self).baseAddress {
                let result = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, reportID, pointer, command.count)
                if result != kIOReturnSuccess {
                    print("Failed to send command: \(result)")
                } else {
                    print("Command sent successfully")
                }
            }
        }
    }
}

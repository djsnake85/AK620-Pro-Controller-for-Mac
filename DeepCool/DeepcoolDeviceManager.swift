import Foundation
import IOKit.hid

class DeepcoolDeviceManager: ObservableObject {
    private var hidManager: IOHIDManager!
    @Published var device: IOHIDDevice?
    
    init() {
        setupHIDManager()
    }
    
    private func setupHIDManager() {
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matchingDict: [String: Any] = [
            kIOHIDVendorIDKey as String: 0x3633,
            kIOHIDProductIDKey as String: 0x0012
        ]
        IOHIDManagerSetDeviceMatching(hidManager, matchingDict as CFDictionary)
        let result = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result != kIOReturnSuccess {
            print("Error opening HID Manager: \(result)")
            return
        }
        
        if let deviceSet = IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice>,
           let foundDevice = deviceSet.first {
            self.device = foundDevice
            print("AK620 Pro connected.")
        } else {
            print("AK620 not found!!!")
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
                    print("Command sent successfully: \(result)")
                }
            }
        }
    }
}

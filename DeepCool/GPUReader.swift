
import Foundation
import IOKit

final class GPUReader {

    func getUsage() -> Double {

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")

        let result = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return 0 }

        var totalUsage: Double = 0

        var service = IOIteratorNext(iterator)

        while service != 0 {

            var properties: Unmanaged<CFMutableDictionary>?

            let kr = IORegistryEntryCreateCFProperties(
                service,
                &properties,
                kCFAllocatorDefault,
                0
            )

            if kr == KERN_SUCCESS,
               let props = properties?.takeRetainedValue() as? [String: Any] {

                if let perf = props["PerformanceStatistics"] as? [String: Any],
                   let gpu = perf["GPU Busy"] as? Double {
                    totalUsage += gpu
                }
            }

            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        IOObjectRelease(iterator)

        return min(max(totalUsage, 0), 100)
    }
}

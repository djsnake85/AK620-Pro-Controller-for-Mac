import Foundation

final class PowerGadgetMonitor {

    private var previousSample: PGSampleID?
    private var currentSample: PGSampleID?

    init?() {
        guard PG_Initialize() else { return nil }
        var firstSample: PGSampleID = 0
        guard withUnsafeMutablePointer(to: &firstSample, { PG_ReadSample(0, $0) }) else {
            PG_Shutdown()
            return nil
        }
        currentSample = firstSample
    }

    deinit {
        if let prev = previousSample { PGSample_Release(prev) }
        if let curr = currentSample { PGSample_Release(curr) }
        PG_Shutdown()
    }

    @discardableResult
    func updateSamples() -> Bool {
        if let prev = previousSample { PGSample_Release(prev) }
        previousSample = currentSample

        var newSample: PGSampleID = 0
        guard withUnsafeMutablePointer(to: &newSample, { PG_ReadSample(0, $0) }) else { return false }
        currentSample = newSample
        return true
    }

    func getPackageTemperature() -> Double? {
        guard let curr = currentSample else { return nil }
        var temp: Double = 0, minTemp: Double = 0, maxTemp: Double = 0
        guard PGSample_GetIATemperature(curr, &temp, &minTemp, &maxTemp), temp > 0 else { return nil }
        return temp
    }

    func getPackagePower() -> Double? {
        guard let prev = previousSample, let curr = currentSample else { return nil }
        var power: Double = 0, energy: Double = 0
        guard PGSample_GetPackagePower(prev, curr, &power, &energy), power >= 0 else { return nil }
        return power
    }

    func getIAUtilization() -> Double? {
        guard let prev = previousSample, let curr = currentSample else { return nil }
        var util: Double = 0
        guard PGSample_GetIAUtilization(prev, curr, &util) else { return nil }
        return min(max(util, 0), 100)
    }

    func getRequestFrequency() -> Double? {
        guard let curr = currentSample else { return nil }
        var freq: Double = 0, minFreq: Double = 0, maxFreq: Double = 0
        guard PGSample_GetIAFrequencyRequest(curr, &freq, &minFreq, &maxFreq), freq > 0 else { return nil }
        return freq
    }
}

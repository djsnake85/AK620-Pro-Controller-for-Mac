import Foundation

// Bridging header requis :
// #include <IntelPowerGadget/PowerGadgetLib.h>
// typedef uint64_t PGSampleID;

final class PowerGadgetMonitor {

    // MARK: - Samples
    private var previousSample: PGSampleID?
    private var currentSample: PGSampleID?

    // MARK: - Init / Deinit
    init?() {
        guard PG_Initialize() else {
            print("❌ Intel Power Gadget initialization failed")
            return nil
        }

        var firstSample: PGSampleID = 0
        let ok = withUnsafeMutablePointer(to: &firstSample) {
            PG_ReadSample(0, $0)
        }

        guard ok else {
            print("❌ Failed to read initial PowerGadget sample")
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

    // MARK: - Sample Update
    @discardableResult
    func updateSamples() -> Bool {
        if let prev = previousSample {
            PGSample_Release(prev)
        }

        previousSample = currentSample

        var newSample: PGSampleID = 0
        let ok = withUnsafeMutablePointer(to: &newSample) {
            PG_ReadSample(0, $0)
        }

        guard ok else {
            print("❌ Failed to read PowerGadget sample")
            return false
        }

        currentSample = newSample
        return true
    }

    // MARK: - CPU Metrics

    /// Température instantanée du package CPU (°C)
    /// ⚠️ Un seul sample suffit
    func getPackageTemperature() -> Double? {
        guard let curr = currentSample else { return nil }

        var temp: Double = 0
        var minTemp: Double = 0
        var maxTemp: Double = 0

        let ok = PGSample_GetIATemperature(curr, &temp, &minTemp, &maxTemp)
        guard ok, temp > 0 else { return nil }

        return temp
    }

    /// Consommation du package CPU (Watts)
    /// ⚠️ nécessite 2 samples
    func getPackagePower() -> Double? {
        guard let prev = previousSample, let curr = currentSample else { return nil }

        var power: Double = 0
        var energy: Double = 0

        let ok = PGSample_GetPackagePower(prev, curr, &power, &energy)
        guard ok, power >= 0 else { return nil }

        return power
    }

    /// Utilisation CPU (%) sur les unités IA
    func getIAUtilization() -> Double? {
        guard let prev = previousSample, let curr = currentSample else { return nil }

        var util: Double = 0
        let ok = PGSample_GetIAUtilization(prev, curr, &util)
        guard ok else { return nil }

        return min(max(util, 0), 100)
    }

    /// Fréquence demandée CPU (MHz)
    /// ⚠️ retourne la fréquence requise, pas la réelle
    func getRequestFrequency() -> Double? {
        guard let curr = currentSample else { return nil }

        var freq: Double = 0
        var minFreq: Double = 0
        var maxFreq: Double = 0

        let ok = PGSample_GetIAFrequencyRequest(curr, &freq, &minFreq, &maxFreq)
        guard ok, freq > 0 else { return nil }

        return freq
    }
}


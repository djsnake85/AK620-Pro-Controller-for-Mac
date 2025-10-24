import Foundation

// Suppose your bridging header already includes the headers:
//   #include <IntelPowerGadget/PowerGadgetLib.h>
// And according to the header, we have:
//   typedef uint64_t PGSampleID;

class PowerGadgetMonitor {
    // We will use PGSampleID (UInt64) to represent a sample.
    private var previousSample: PGSampleID? = nil
    private var currentSample: PGSampleID? = nil

    /// Initializes the monitor and reads the first sample.
    init?() {
        // initializes the API; PG_Initialize() returns Bool (true if successful)
        let initRet = PG_Initialize()
        if !initRet {
            print("Error initializing Intel Power Gadget")
            return nil
        }
        // Leia o primeiro sample
        var sample: PGSampleID = 0
        let ret = withUnsafeMutablePointer(to: &sample) { pointer in
            PG_ReadSample(0, pointer)
        }
        if !ret {
            print("Error reading initial sample: \(ret)")
            return nil
        }
        currentSample = sample
    }
    
    deinit {
        // Release retained samples, if any
        if let prev = previousSample {
            PGSample_Release(prev)
        }
        if let curr = currentSample {
            PGSample_Release(curr)
        }
        PG_Shutdown()
    }
    
    /// Updates the samples:
    /// - Releases the previous sample (if it exists)
    /// - Moves the current sample to previousSample
    /// - Reads a new sample to currentSample
    /// Returns true if the read is successful.
    func updateSamples() -> Bool {
        // Release the previous sample, if it exists
        if let prev = previousSample {
            PGSample_Release(prev)
        }
        // Move the current sample to previousSample
        previousSample = currentSample
        
        // Read a new sample into currentSample
        var newSample: PGSampleID = 0
        let ret = withUnsafeMutablePointer(to: &newSample) { pointer in
            PG_ReadSample(0, pointer)
        }
        if !ret {
            print("Error reading new sample: \(ret)")
            return false
        }
        currentSample = newSample
        
        return true
    }
    
    /// Obtém a potência do pacote (TDP dinâmico) em Watts.
    func getPackagePower() -> Double? {
        guard let prev = previousSample, let curr = currentSample else {
            print("Insufficient samples for PGSample_GetPackagePower")
            return nil
        }
        var pkgPower: Double = 0.0
        var energyJoules: Double = 0.0
        let ret = PGSample_GetPackagePower(prev, curr, &pkgPower, &energyJoules)
        if !ret {
            print("Error in PGSample_GetPackagePower: \(ret)")
            return nil
        }
        return pkgPower
    }
    
    ///Obtient la température du package (par exemple la température du processeur) en °C.
    func getPackageTemperature() -> Double? {
        guard let prev = previousSample, let curr = currentSample else {
            print("Insufficient samples for PGSample_GetPackageTemperature")
            return nil
        }
        var pkgTemp: Double = 0.0,
            minTemp: Double = 0.0,
            maxTemp: Double = 0.0
        
        let ret = PGSample_GetIATemperature(curr, &pkgTemp, &minTemp, &maxTemp)
        if !ret {
            print("Error in PGSample_GetPackageTemperature: \(ret)")
            return nil
        }
        return maxTemp
    }
    
    /// Obtient l'utilisation de l'IA (utilisation du processeur) en pourcentage.
    func getIAUtilization() -> Double? {
        guard let prev = previousSample, let curr = currentSample else {
            print("Insufficient samples for PGSample_GetIAUtilization")
            return nil
        }
        var iaUtil: Double = 0.0
        let ret = PGSample_GetIAUtilization(prev, curr, &iaUtil)
        if !ret {
            print("Error in PGSample_GetIAUtilization: \(ret)")
            return nil
        }
        return iaUtil
    }
    
    /// Obtient la fréquence de requête (Core Req) en GHz.
    func getRequestFrequency() -> Double? {
        guard let prev = previousSample, let curr = currentSample else {
            print("Insufficient samples for PGSample_GetIAFrequency")
            return nil
        }
        var reqFreq: Double = 0.0
        var minFreq: Double = 0.0
        var maxFreq: Double = 0.0
        let ret = PGSample_GetIAFrequencyRequest(curr, &reqFreq, &minFreq, &maxFreq)
        if !ret {
            print("Error in PGSample_GetIAFrequency: \(ret)")
            return nil
        }
        return reqFreq
    }
}

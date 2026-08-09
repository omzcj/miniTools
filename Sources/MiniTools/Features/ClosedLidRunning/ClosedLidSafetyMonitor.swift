import Foundation
import IOKit.ps

struct ClosedLidSafetySnapshot {
    let isOnBattery: Bool
    let batteryPercent: Int?
    let thermalState: ProcessInfo.ThermalState
}

enum ClosedLidSafetyMonitor {
    static func snapshot() -> ClosedLidSafetySnapshot {
        let power = batteryStatus()
        return ClosedLidSafetySnapshot(
            isOnBattery: power.isOnBattery,
            batteryPercent: power.percent,
            thermalState: ProcessInfo.processInfo.thermalState
        )
    }

    private static func batteryStatus() -> (isOnBattery: Bool, percent: Int?) {
        guard let information = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sourceList = IOPSCopyPowerSourcesList(information)?.takeRetainedValue()
                as? [CFTypeRef] else {
            return (false, nil)
        }

        for source in sourceList {
            guard let description = IOPSGetPowerSourceDescription(information, source)?
                .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else {
                continue
            }
            let sourceState = description[kIOPSPowerSourceStateKey] as? String
            let current = description[kIOPSCurrentCapacityKey] as? Int
            let maximum = description[kIOPSMaxCapacityKey] as? Int
            let percent: Int?
            if let current, let maximum, maximum > 0 {
                percent = Int((Double(current) / Double(maximum) * 100).rounded())
            } else {
                percent = nil
            }
            return (sourceState == kIOPSBatteryPowerValue, percent)
        }
        return (false, nil)
    }
}

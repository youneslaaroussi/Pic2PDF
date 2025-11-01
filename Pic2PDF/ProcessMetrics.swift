//
//  ProcessMetrics.swift
//  Pic2PDF
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import UIKit

class ProcessMetrics {
    /// Returns the current resident memory usage in MB
    static func currentResidentMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        } else {
            return 0.0
        }
    }
    static func currentCPUUsage() -> Double {
        return 0
    }

    /// Returns system uptime in seconds
    static func systemUptime() -> TimeInterval {
        return ProcessInfo.processInfo.systemUptime
    }

    /// Returns device thermal state description
    static func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}

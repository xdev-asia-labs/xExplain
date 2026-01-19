import Foundation

/// Normalized system metrics used by the xExplain engine
public struct NormalizedMetrics: Sendable {
    // MARK: - CPU
    public let cpuUsage: Double              // 0-100%
    public let cpuUserUsage: Double          // 0-100%
    public let cpuSystemUsage: Double        // 0-100%
    public let coreUsages: [CoreUsage]       // Per-core usage
    
    // MARK: - Memory
    public let memoryUsagePercent: Double    // 0-100%
    public let memoryUsedBytes: UInt64
    public let memoryTotalBytes: UInt64
    public let memoryPressure: MemoryPressureLevel
    public let swapUsedBytes: UInt64
    public let compressedBytes: UInt64
    
    // MARK: - Disk I/O
    public let diskReadRate: Double          // MB/s
    public let diskWriteRate: Double         // MB/s
    public let diskUsagePercent: Double      // 0-100%
    
    // MARK: - Thermal
    public let cpuTemperature: Double        // Celsius
    public let gpuTemperature: Double        // Celsius
    public let thermalState: ThermalStateLevel
    public let fanSpeed: Int                 // RPM (0 for fanless)
    
    // MARK: - Power
    public let cpuFrequencyMHz: Double?      // Current frequency
    public let maxFrequencyMHz: Double?      // Max frequency
    public let powerWatts: Double?           // Current power draw
    public let batteryLevel: Double?         // 0-100% (nil if not on battery)
    public let isOnBattery: Bool
    
    // MARK: - GPU
    public let gpuUsage: Double              // 0-100%
    public let gpuMemoryUsed: UInt64?
    public let isUsingMetal: Bool
    public let isUsingANE: Bool              // Apple Neural Engine
    
    // MARK: - Network
    public let networkDownloadRate: Double   // MB/s
    public let networkUploadRate: Double     // MB/s
    
    // MARK: - Timestamp
    public let timestamp: Date
    
    public init(
        cpuUsage: Double = 0,
        cpuUserUsage: Double = 0,
        cpuSystemUsage: Double = 0,
        coreUsages: [CoreUsage] = [],
        memoryUsagePercent: Double = 0,
        memoryUsedBytes: UInt64 = 0,
        memoryTotalBytes: UInt64 = 0,
        memoryPressure: MemoryPressureLevel = .normal,
        swapUsedBytes: UInt64 = 0,
        compressedBytes: UInt64 = 0,
        diskReadRate: Double = 0,
        diskWriteRate: Double = 0,
        diskUsagePercent: Double = 0,
        cpuTemperature: Double = 0,
        gpuTemperature: Double = 0,
        thermalState: ThermalStateLevel = .nominal,
        fanSpeed: Int = 0,
        cpuFrequencyMHz: Double? = nil,
        maxFrequencyMHz: Double? = nil,
        powerWatts: Double? = nil,
        batteryLevel: Double? = nil,
        isOnBattery: Bool = false,
        gpuUsage: Double = 0,
        gpuMemoryUsed: UInt64? = nil,
        isUsingMetal: Bool = false,
        isUsingANE: Bool = false,
        networkDownloadRate: Double = 0,
        networkUploadRate: Double = 0
    ) {
        self.cpuUsage = cpuUsage
        self.cpuUserUsage = cpuUserUsage
        self.cpuSystemUsage = cpuSystemUsage
        self.coreUsages = coreUsages
        self.memoryUsagePercent = memoryUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.memoryPressure = memoryPressure
        self.swapUsedBytes = swapUsedBytes
        self.compressedBytes = compressedBytes
        self.diskReadRate = diskReadRate
        self.diskWriteRate = diskWriteRate
        self.diskUsagePercent = diskUsagePercent
        self.cpuTemperature = cpuTemperature
        self.gpuTemperature = gpuTemperature
        self.thermalState = thermalState
        self.fanSpeed = fanSpeed
        self.cpuFrequencyMHz = cpuFrequencyMHz
        self.maxFrequencyMHz = maxFrequencyMHz
        self.powerWatts = powerWatts
        self.batteryLevel = batteryLevel
        self.isOnBattery = isOnBattery
        self.gpuUsage = gpuUsage
        self.gpuMemoryUsed = gpuMemoryUsed
        self.isUsingMetal = isUsingMetal
        self.isUsingANE = isUsingANE
        self.networkDownloadRate = networkDownloadRate
        self.networkUploadRate = networkUploadRate
        self.timestamp = Date()
    }
}

// MARK: - Core Usage

public struct CoreUsage: Sendable {
    public let coreIndex: Int
    public let coreType: CoreType
    public let usage: Double              // 0-100%
    public let frequencyMHz: Double?
    
    public init(coreIndex: Int, coreType: CoreType, usage: Double, frequencyMHz: Double? = nil) {
        self.coreIndex = coreIndex
        self.coreType = coreType
        self.usage = usage
        self.frequencyMHz = frequencyMHz
    }
}

public enum CoreType: String, Sendable {
    case performance = "P"
    case efficiency = "E"
    case unknown = "?"
}

// MARK: - Memory Pressure

public enum MemoryPressureLevel: String, Sendable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"
}

// MARK: - Thermal State

public enum ThermalStateLevel: String, Sendable {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"
}

// MARK: - Process Information

public struct ProcessSnapshot: Identifiable, Sendable {
    public let id: Int32                 // PID
    public let name: String
    public let displayName: String
    public let bundleIdentifier: String?
    
    // Resource usage
    public let cpuUsage: Double          // 0-100%
    public let memoryBytes: UInt64
    public let diskReadBytes: UInt64
    public let diskWriteBytes: UInt64
    
    // Classification
    public let category: ProcessCategory
    public let isSystemProcess: Bool
    
    // Developer-relevant
    public let parentPID: Int32?
    public let threadCount: Int
    public let coreAffinity: [Int]?      // Which cores this process uses
    
    public init(
        pid: Int32,
        name: String,
        displayName: String? = nil,
        bundleIdentifier: String? = nil,
        cpuUsage: Double = 0,
        memoryBytes: UInt64 = 0,
        diskReadBytes: UInt64 = 0,
        diskWriteBytes: UInt64 = 0,
        category: ProcessCategory = .other,
        isSystemProcess: Bool = false,
        parentPID: Int32? = nil,
        threadCount: Int = 1,
        coreAffinity: [Int]? = nil
    ) {
        self.id = pid
        self.name = name
        self.displayName = displayName ?? name
        self.bundleIdentifier = bundleIdentifier
        self.cpuUsage = cpuUsage
        self.memoryBytes = memoryBytes
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.category = category
        self.isSystemProcess = isSystemProcess
        self.parentPID = parentPID
        self.threadCount = threadCount
        self.coreAffinity = coreAffinity
    }
}

public enum ProcessCategory: String, Sendable, CaseIterable {
    case browser = "Browser"
    case developer = "Developer"
    case productivity = "Productivity"
    case media = "Media"
    case communication = "Communication"
    case system = "System"
    case utilities = "Utilities"
    case aiml = "AI/ML"           // New: AI/ML workloads
    case container = "Container"   // New: Docker, Podman, etc.
    case other = "Other"
}

// MARK: - Throttle Detection

public struct ThrottleInfo: Sendable {
    public let isThrottling: Bool
    public let frequencyReduction: Double   // Percentage reduction (0-100)
    public let reason: ThrottleReason
    public let detectedAt: Date
    
    public init(
        isThrottling: Bool,
        frequencyReduction: Double = 0,
        reason: ThrottleReason = .none
    ) {
        self.isThrottling = isThrottling
        self.frequencyReduction = frequencyReduction
        self.reason = reason
        self.detectedAt = Date()
    }
}

public enum ThrottleReason: String, Sendable {
    case none = "None"
    case thermal = "Thermal"
    case power = "Power Limit"
    case batteryHealth = "Battery Health"
    case unknown = "Unknown"
}

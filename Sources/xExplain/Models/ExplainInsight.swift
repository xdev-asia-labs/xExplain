import Foundation

/// Represents an insight with counterfactual analysis capability
/// This is the core output of the xExplain engine
public struct ExplainInsight: Identifiable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    
    // MARK: - Core Properties
    
    /// The symptom observed (e.g., "High CPU Usage")
    public let symptom: String
    
    /// Root cause analysis (e.g., "Docker container running intensive build")
    public let rootCause: String
    
    /// Human-readable explanation
    public let explanation: String
    
    /// Confidence score (0.0 - 1.0)
    public let confidence: Double
    
    /// Type of insight
    public let type: ExplainInsightType
    
    /// Severity level
    public let severity: ExplainSeverity
    
    // MARK: - Counterfactual Analysis (Key differentiator)
    
    /// What would happen if a specific action is taken
    /// e.g., "If Docker paused → CPU -31%"
    public let counterfactual: Counterfactual?
    
    // MARK: - Actionability
    
    /// Safety level of suggested action
    public let actionSafety: ActionSafety
    
    /// Target audience for this insight
    public let audience: InsightAudience
    
    /// Suggested actions to resolve
    public let suggestedActions: [ExplainAction]
    
    // MARK: - Context
    
    /// Affected processes
    public let affectedProcesses: [String]
    
    /// Related metrics
    public let relatedMetrics: [MetricSnapshot]
    
    public init(
        symptom: String,
        rootCause: String,
        explanation: String,
        confidence: Double,
        type: ExplainInsightType,
        severity: ExplainSeverity,
        counterfactual: Counterfactual? = nil,
        actionSafety: ActionSafety = .safe,
        audience: InsightAudience = .general,
        suggestedActions: [ExplainAction] = [],
        affectedProcesses: [String] = [],
        relatedMetrics: [MetricSnapshot] = []
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.symptom = symptom
        self.rootCause = rootCause
        self.explanation = explanation
        self.confidence = confidence
        self.type = type
        self.severity = severity
        self.counterfactual = counterfactual
        self.actionSafety = actionSafety
        self.audience = audience
        self.suggestedActions = suggestedActions
        self.affectedProcesses = affectedProcesses
        self.relatedMetrics = relatedMetrics
    }
}

// MARK: - Counterfactual Model

/// Represents a "what if" analysis
public struct Counterfactual: Codable, Sendable {
    /// The hypothetical action
    public let action: String
    
    /// Expected outcome if action is taken
    public let expectedOutcome: String
    
    /// Quantified impact (e.g., "-31%")
    public let quantifiedImpact: String?
    
    /// Confidence in this prediction
    public let confidence: Double
    
    /// Time to see effect
    public let timeToEffect: TimeInterval?
    
    public init(
        action: String,
        expectedOutcome: String,
        quantifiedImpact: String? = nil,
        confidence: Double,
        timeToEffect: TimeInterval? = nil
    ) {
        self.action = action
        self.expectedOutcome = expectedOutcome
        self.quantifiedImpact = quantifiedImpact
        self.confidence = confidence
        self.timeToEffect = timeToEffect
    }
}

// MARK: - Insight Types

public enum ExplainInsightType: String, Codable, CaseIterable, Sendable {
    // Performance
    case cpuSaturation = "CPU Saturation"
    case memoryPressure = "Memory Pressure"
    case ioBottleneck = "I/O Bottleneck"
    case thermalThrottling = "Thermal Throttling"
    
    // Developer-specific
    case coreImbalance = "Core Imbalance"
    case devLoopDetected = "Dev Loop Detected"
    case ioAmplification = "I/O Amplification"
    case mlWorkloadFallback = "ML Workload Fallback"
    case buildInProgress = "Build In Progress"
    
    // Thermal-specific
    case silentThrottling = "Silent Throttling"
    case energyInefficiency = "Energy Inefficiency"
    case environmentalHeat = "Environmental Heat"
    case thermalForecast = "Thermal Forecast"
    
    // General
    case backgroundMisbehavior = "Background Misbehavior"
    case networkHog = "Network Hog"
    case batteryDrain = "Battery Drain"
    case diskFull = "Disk Full"
    
    public var icon: String {
        switch self {
        case .cpuSaturation: return "cpu"
        case .memoryPressure: return "memorychip"
        case .ioBottleneck: return "internaldrive"
        case .thermalThrottling: return "thermometer.sun"
        case .coreImbalance: return "cpu.fill"
        case .devLoopDetected: return "arrow.triangle.2.circlepath"
        case .ioAmplification: return "arrow.up.arrow.down"
        case .mlWorkloadFallback: return "brain"
        case .buildInProgress: return "hammer"
        case .silentThrottling: return "gauge.with.dots.needle.33percent"
        case .energyInefficiency: return "bolt.trianglebadge.exclamationmark"
        case .environmentalHeat: return "sun.max"
        case .thermalForecast: return "thermometer.variable.and.figure"
        case .backgroundMisbehavior: return "moon.circle"
        case .networkHog: return "network"
        case .batteryDrain: return "battery.25"
        case .diskFull: return "externaldrive.badge.exclamationmark"
        }
    }
    
    public var category: InsightCategory {
        switch self {
        case .cpuSaturation, .memoryPressure, .thermalThrottling, .coreImbalance:
            return .performance
        case .ioBottleneck, .diskFull, .ioAmplification:
            return .storage
        case .networkHog:
            return .network
        case .backgroundMisbehavior, .batteryDrain, .energyInefficiency:
            return .efficiency
        case .devLoopDetected, .mlWorkloadFallback, .buildInProgress:
            return .developer
        case .silentThrottling, .environmentalHeat, .thermalForecast:
            return .thermal
        }
    }
}

public enum InsightCategory: String, Codable, CaseIterable, Sendable {
    case performance = "Performance"
    case storage = "Storage"
    case network = "Network"
    case efficiency = "Efficiency"
    case developer = "Developer"
    case thermal = "Thermal"
}

// MARK: - Severity

public enum ExplainSeverity: String, Codable, CaseIterable, Comparable, Sendable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    
    public var priority: Int {
        switch self {
        case .info: return 0
        case .warning: return 1
        case .critical: return 2
        }
    }
    
    public static func < (lhs: ExplainSeverity, rhs: ExplainSeverity) -> Bool {
        lhs.priority < rhs.priority
    }
    
    public var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }
}

// MARK: - Action Safety

public enum ActionSafety: String, Codable, Sendable {
    case safe = "Safe"           // Can be auto-executed
    case caution = "Caution"     // Needs user confirmation
    case dangerous = "Dangerous" // May cause data loss
}

// MARK: - Target Audience

public enum InsightAudience: String, Codable, Sendable {
    case general = "general"     // Consumer users
    case developer = "dev"       // Developers
    case power = "power"         // Power users
}

// MARK: - Suggested Action

public struct ExplainAction: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String
    public let impact: String
    public let safety: ActionSafety
    public let actionType: ExplainActionType
    
    public init(
        title: String,
        description: String,
        impact: String,
        safety: ActionSafety = .safe,
        actionType: ExplainActionType
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.impact = impact
        self.safety = safety
        self.actionType = actionType
    }
}

public enum ExplainActionType: Codable, Sendable {
    case quitApp(processName: String, pid: Int32)
    case forceQuitApp(processName: String, pid: Int32)
    case pauseProcess(processName: String, pid: Int32)
    case reduceLoad(suggestions: [String])
    case openSystemSettings(path: String)
    case openActivityMonitor
    case runTerminalCommand(command: String)
    case none
}

// MARK: - Metric Snapshot

public struct MetricSnapshot: Codable, Sendable {
    public let name: String
    public let value: Double
    public let unit: String
    public let timestamp: Date
    
    public init(name: String, value: Double, unit: String) {
        self.name = name
        self.value = value
        self.unit = unit
        self.timestamp = Date()
    }
}

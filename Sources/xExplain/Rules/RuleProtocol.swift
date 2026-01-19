import Foundation

/// Protocol for all insight rules in xExplain
/// Rules evaluate system state and generate insights with counterfactual analysis
public protocol ExplainRule: Sendable {
    /// Unique identifier for this rule
    var id: String { get }
    
    /// Human-readable name
    var name: String { get }
    
    /// Target audience for this rule's insights
    var audience: InsightAudience { get }
    
    /// Evaluate the current system state and return an insight if conditions are met
    /// - Parameters:
    ///   - metrics: Current normalized system metrics
    ///   - processes: Current process snapshots
    ///   - context: Additional context from the engine
    /// - Returns: An insight if conditions warrant, nil otherwise
    func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight?
}

/// Context provided to rules during evaluation
public struct EvaluationContext: Sendable {
    /// Recent metric history for trend analysis
    public let metricsHistory: [NormalizedMetrics]
    
    /// Detected anomalies
    public let anomalies: [DetectedAnomaly]
    
    /// Correlations found between metrics and processes
    public let correlations: [MetricCorrelation]
    
    /// Previous insights (for deduplication)
    public let recentInsights: [ExplainInsight]
    
    /// Throttle detection info
    public let throttleInfo: ThrottleInfo?
    
    public init(
        metricsHistory: [NormalizedMetrics] = [],
        anomalies: [DetectedAnomaly] = [],
        correlations: [MetricCorrelation] = [],
        recentInsights: [ExplainInsight] = [],
        throttleInfo: ThrottleInfo? = nil
    ) {
        self.metricsHistory = metricsHistory
        self.anomalies = anomalies
        self.correlations = correlations
        self.recentInsights = recentInsights
        self.throttleInfo = throttleInfo
    }
}

/// Detected anomaly in metrics
public struct DetectedAnomaly: Sendable {
    public let metric: String
    public let currentValue: Double
    public let expectedValue: Double
    public let deviation: Double       // Standard deviations
    public let timestamp: Date
    
    public init(
        metric: String,
        currentValue: Double,
        expectedValue: Double,
        deviation: Double
    ) {
        self.metric = metric
        self.currentValue = currentValue
        self.expectedValue = expectedValue
        self.deviation = deviation
        self.timestamp = Date()
    }
}

/// Correlation between a metric and a process
public struct MetricCorrelation: Sendable {
    public let metric: String
    public let process: ProcessSnapshot
    public let strength: Double        // 0-1
    public let description: String
    
    public init(
        metric: String,
        process: ProcessSnapshot,
        strength: Double,
        description: String
    ) {
        self.metric = metric
        self.process = process
        self.strength = strength
        self.description = description
    }
}

// MARK: - Rule Helper Extensions

extension ExplainRule {
    /// Default audience is general
    public var audience: InsightAudience { .general }
    
    /// Helper to create a counterfactual for process termination
    public func terminationCounterfactual(
        process: ProcessSnapshot,
        metricName: String,
        currentValue: Double,
        estimatedReduction: Double
    ) -> Counterfactual {
        let newValue = currentValue - estimatedReduction
        let percentReduction = (estimatedReduction / currentValue) * 100
        
        return Counterfactual(
            action: "Quit \(process.displayName)",
            expectedOutcome: "\(metricName) giảm từ \(String(format: "%.0f", currentValue))% xuống ~\(String(format: "%.0f", newValue))%",
            quantifiedImpact: "-\(String(format: "%.0f", percentReduction))%",
            confidence: min(0.9, estimatedReduction / currentValue),
            timeToEffect: 2.0 // seconds
        )
    }
    
    /// Helper to check if similar insight was recently generated
    public func hasRecentSimilarInsight(
        type: ExplainInsightType,
        in context: EvaluationContext,
        within seconds: TimeInterval = 60
    ) -> Bool {
        let cutoff = Date().addingTimeInterval(-seconds)
        return context.recentInsights.contains { insight in
            insight.type == type && insight.timestamp > cutoff
        }
    }
    
    /// Helper to calculate trend from metrics history
    public func calculateTrend(
        for keyPath: KeyPath<NormalizedMetrics, Double>,
        in history: [NormalizedMetrics]
    ) -> MetricTrend {
        guard history.count >= 3 else { return .stable }
        
        let values = history.suffix(5).map { $0[keyPath: keyPath] }
        var increases = 0
        var decreases = 0
        
        for i in 1..<values.count {
            if values[i] > values[i-1] + 1 { increases += 1 }
            if values[i] < values[i-1] - 1 { decreases += 1 }
        }
        
        if Double(increases) / Double(values.count - 1) > 0.6 {
            return .increasing
        }
        if Double(decreases) / Double(values.count - 1) > 0.6 {
            return .decreasing
        }
        return .stable
    }
}

public enum MetricTrend: String, Sendable {
    case increasing
    case stable
    case decreasing
}

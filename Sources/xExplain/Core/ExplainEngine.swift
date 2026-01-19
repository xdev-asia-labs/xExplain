import Foundation

/// Main xExplain Engine - The "System Brain"
/// Analyzes system state and generates insights with counterfactual reasoning
public final class ExplainEngine: @unchecked Sendable {
    
    // MARK: - Singleton
    public static let shared = ExplainEngine()
    
    // MARK: - Configuration
    private var registeredRules: [any ExplainRule] = []
    private var metricsHistory: [NormalizedMetrics] = []
    private var insightHistory: [ExplainInsight] = []
    private let historyLimit = 100
    private let metricsHistoryLimit = 60 // ~1 minute at 1s intervals
    
    // MARK: - Sub-engines
    private let correlationEngine = CorrelationEngine()
    private let anomalyDetector = AnomalyDetector()
    private let counterfactualAnalyzer = CounterfactualAnalyzer()
    private let confidenceScorer = ConfidenceScorer()
    
    // MARK: - Initialization
    
    private init() {
        registerDefaultRules()
    }
    
    /// Register default rules based on audience
    private func registerDefaultRules() {
        // Consumer rules (always active)
        registeredRules.append(CPUSaturationRule())
        registeredRules.append(MemoryPressureRule())
        registeredRules.append(IOBottleneckRule())
        registeredRules.append(ThermalThrottlingRule())
    }
    
    /// Register additional rules for specific audience
    public func registerRules(for audience: InsightAudience) {
        switch audience {
        case .developer:
            registeredRules.append(CoreImbalanceRule())
            registeredRules.append(DevLoopRule())
            registeredRules.append(IOAmplificationRule())
            registeredRules.append(MLWorkloadRule())
        case .power:
            registeredRules.append(SilentThrottleRule())
            registeredRules.append(EnergyEfficiencyRule())
            registeredRules.append(ThermalForecastRule())
        case .general:
            break // Default rules only
        }
    }
    
    /// Register a custom rule
    public func registerRule(_ rule: any ExplainRule) {
        registeredRules.append(rule)
    }
    
    // MARK: - Main Analysis
    
    /// Analyze system state and generate insights
    /// - Parameters:
    ///   - metrics: Current normalized metrics
    ///   - processes: Current process snapshots
    ///   - throttleInfo: Optional throttle detection info
    /// - Returns: Array of insights sorted by severity
    public func analyze(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        throttleInfo: ThrottleInfo? = nil
    ) -> [ExplainInsight] {
        // 1. Update history
        metricsHistory.append(metrics)
        if metricsHistory.count > metricsHistoryLimit {
            metricsHistory.removeFirst()
        }
        
        // 2. Find correlations
        let correlations = correlationEngine.correlate(
            metrics: metrics,
            processes: processes
        )
        
        // 3. Detect anomalies
        let anomalies = anomalyDetector.detect(
            current: metrics,
            history: metricsHistory
        )
        
        // 4. Build evaluation context
        let context = EvaluationContext(
            metricsHistory: metricsHistory,
            anomalies: anomalies,
            correlations: correlations,
            recentInsights: Array(insightHistory.suffix(20)),
            throttleInfo: throttleInfo
        )
        
        // 5. Evaluate all rules
        var insights: [ExplainInsight] = []
        for rule in registeredRules {
            if let insight = rule.evaluate(
                metrics: metrics,
                processes: processes,
                context: context
            ) {
                // Enhance with counterfactual if not already present
                let enhancedInsight = counterfactualAnalyzer.enhance(
                    insight: insight,
                    metrics: metrics,
                    processes: processes
                )
                
                // Score confidence
                let scoredInsight = confidenceScorer.score(
                    insight: enhancedInsight,
                    context: context
                )
                
                insights.append(scoredInsight)
            }
        }
        
        // 6. Deduplicate by type
        var seenTypes: Set<ExplainInsightType> = []
        var uniqueInsights: [ExplainInsight] = []
        for insight in insights {
            if !seenTypes.contains(insight.type) {
                uniqueInsights.append(insight)
                seenTypes.insert(insight.type)
            }
        }
        
        // 7. Sort by severity (critical first)
        uniqueInsights.sort { $0.severity > $1.severity }
        
        // 8. Update history
        addToHistory(uniqueInsights)
        
        return uniqueInsights
    }
    
    // MARK: - Quick Analysis Methods
    
    /// Quick answer: "Why is CPU high?"
    public func whyCPU(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> ExplainInsight? {
        let cpuRule = CPUSaturationRule()
        let context = EvaluationContext(metricsHistory: metricsHistory)
        
        guard let insight = cpuRule.evaluate(
            metrics: metrics,
            processes: processes,
            context: context
        ) else {
            return nil
        }
        
        return counterfactualAnalyzer.enhance(
            insight: insight,
            metrics: metrics,
            processes: processes
        )
    }
    
    /// Quick answer: "Why is it hot?"
    public func whyHot(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> ExplainInsight? {
        let thermalRule = ThermalThrottlingRule()
        let context = EvaluationContext(
            metricsHistory: metricsHistory,
            throttleInfo: ThrottleInfo(
                isThrottling: metrics.thermalState == .serious || metrics.thermalState == .critical
            )
        )
        
        return thermalRule.evaluate(
            metrics: metrics,
            processes: processes,
            context: context
        )
    }
    
    /// Analyze a specific process
    public func analyzeProcess(
        _ process: ProcessSnapshot,
        metrics: NormalizedMetrics,
        allProcesses: [ProcessSnapshot]
    ) -> [ExplainInsight] {
        var insights: [ExplainInsight] = []
        
        // CPU analysis
        if process.cpuUsage > 50 {
            let counterfactual = Counterfactual(
                action: "Quit \(process.displayName)",
                expectedOutcome: "CPU sẽ giảm đáng kể",
                quantifiedImpact: "-\(String(format: "%.0f", process.cpuUsage))%",
                confidence: 0.85,
                timeToEffect: 2.0
            )
            
            insights.append(ExplainInsight(
                symptom: "High CPU from \(process.displayName)",
                rootCause: "\(process.displayName) đang sử dụng \(String(format: "%.0f", process.cpuUsage))% CPU",
                explanation: describeProcessUsage(process),
                confidence: 0.9,
                type: .cpuSaturation,
                severity: process.cpuUsage > 80 ? .critical : .warning,
                counterfactual: counterfactual,
                affectedProcesses: [process.name]
            ))
        }
        
        // Memory analysis
        let memoryGB = Double(process.memoryBytes) / 1_073_741_824
        if memoryGB > 2 {
            insights.append(ExplainInsight(
                symptom: "High memory from \(process.displayName)",
                rootCause: "\(process.displayName) đang chiếm \(String(format: "%.1f", memoryGB))GB RAM",
                explanation: "App này đang sử dụng nhiều bộ nhớ",
                confidence: 0.9,
                type: .memoryPressure,
                severity: memoryGB > 4 ? .critical : .warning,
                affectedProcesses: [process.name]
            ))
        }
        
        return insights
    }
    
    // MARK: - Thermal Forecast
    
    /// Predict thermal throttling
    public func thermalForecast(
        currentMetrics: NormalizedMetrics
    ) -> ThermalPrediction? {
        guard metricsHistory.count >= 10 else { return nil }
        
        let recentTemps = metricsHistory.suffix(10).map { $0.cpuTemperature }
        let avgTemp = recentTemps.reduce(0, +) / Double(recentTemps.count)
        let trend = calculateTemperatureTrend(recentTemps)
        
        if trend > 0 && avgTemp > 70 {
            let minutesToThrottle = estimateMinutesToThrottle(
                currentTemp: currentMetrics.cpuTemperature,
                trend: trend
            )
            
            return ThermalPrediction(
                willThrottle: true,
                estimatedMinutes: minutesToThrottle,
                currentTemperature: currentMetrics.cpuTemperature,
                recommendedAction: "Giảm workload hoặc cải thiện thông gió"
            )
        }
        
        return ThermalPrediction(
            willThrottle: false,
            estimatedMinutes: nil,
            currentTemperature: currentMetrics.cpuTemperature,
            recommendedAction: nil
        )
    }
    
    // MARK: - Private Helpers
    
    private func addToHistory(_ insights: [ExplainInsight]) {
        for insight in insights {
            let recentSimilar = insightHistory.suffix(10).contains { existing in
                existing.type == insight.type &&
                Date().timeIntervalSince(existing.timestamp) < 60
            }
            
            if !recentSimilar {
                insightHistory.append(insight)
            }
        }
        
        if insightHistory.count > historyLimit {
            insightHistory.removeFirst(insightHistory.count - historyLimit)
        }
    }
    
    private func describeProcessUsage(_ process: ProcessSnapshot) -> String {
        switch process.category {
        case .browser:
            return "\(process.displayName) có thể đang chạy nhiều tabs hoặc extensions nặng"
        case .developer:
            if process.name.lowercased().contains("xcode") {
                return "Xcode đang compile hoặc indexing"
            }
            if process.name.lowercased().contains("docker") {
                return "Docker containers đang hoạt động"
            }
            return "\(process.displayName) đang xử lý tác vụ nặng"
        case .aiml:
            return "\(process.displayName) đang chạy AI/ML workload"
        default:
            return "\(process.displayName) đang sử dụng nhiều tài nguyên"
        }
    }
    
    private func calculateTemperatureTrend(_ temps: [Double]) -> Double {
        guard temps.count >= 2 else { return 0 }
        let first = temps.prefix(temps.count / 2).reduce(0, +) / Double(temps.count / 2)
        let second = temps.suffix(temps.count / 2).reduce(0, +) / Double(temps.count / 2)
        return second - first
    }
    
    private func estimateMinutesToThrottle(currentTemp: Double, trend: Double) -> Double {
        let throttleTemp = 90.0
        guard trend > 0 else { return Double.infinity }
        let degreesToThrottle = throttleTemp - currentTemp
        return max(0.5, degreesToThrottle / (trend * 6)) // trend per 10s -> per minute
    }
}

// MARK: - Thermal Prediction

public struct ThermalPrediction: Sendable {
    public let willThrottle: Bool
    public let estimatedMinutes: Double?
    public let currentTemperature: Double
    public let recommendedAction: String?
}

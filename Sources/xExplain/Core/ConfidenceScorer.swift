import Foundation

/// Scores and adjusts confidence levels for insights
public final class ConfidenceScorer: @unchecked Sendable {
    
    public init() {}
    
    /// Score and potentially adjust insight confidence
    public func score(
        insight: ExplainInsight,
        context: EvaluationContext
    ) -> ExplainInsight {
        var newConfidence = insight.confidence
        
        // Factor 1: Correlation strength
        let relevantCorrelations = context.correlations.filter { correlation in
            insight.affectedProcesses.contains(correlation.process.name)
        }
        if !relevantCorrelations.isEmpty {
            let avgStrength = relevantCorrelations.map { $0.strength }.reduce(0, +) / Double(relevantCorrelations.count)
            newConfidence = (newConfidence + avgStrength) / 2
        }
        
        // Factor 2: Anomaly confirmation
        let relevantAnomalies = context.anomalies.filter { anomaly in
            isAnomalyRelevant(anomaly, to: insight.type)
        }
        if !relevantAnomalies.isEmpty {
            newConfidence = min(1.0, newConfidence + 0.1)
        }
        
        // Factor 3: Historical pattern match
        let similarPastInsights = context.recentInsights.filter { past in
            past.type == insight.type
        }
        if similarPastInsights.count > 3 {
            // Recurring issue - higher confidence
            newConfidence = min(1.0, newConfidence + 0.05)
        }
        
        // Factor 4: Trend confirmation
        if let throttleInfo = context.throttleInfo, 
           insight.type == .thermalThrottling || insight.type == .silentThrottling {
            if throttleInfo.isThrottling {
                newConfidence = min(1.0, newConfidence + 0.15)
            }
        }
        
        // Clamp confidence
        newConfidence = max(0.1, min(1.0, newConfidence))
        
        // Return updated insight if confidence changed significantly
        if abs(newConfidence - insight.confidence) > 0.05 {
            return ExplainInsight(
                symptom: insight.symptom,
                rootCause: insight.rootCause,
                explanation: insight.explanation,
                confidence: newConfidence,
                type: insight.type,
                severity: insight.severity,
                counterfactual: insight.counterfactual,
                actionSafety: insight.actionSafety,
                audience: insight.audience,
                suggestedActions: insight.suggestedActions,
                affectedProcesses: insight.affectedProcesses,
                relatedMetrics: insight.relatedMetrics
            )
        }
        
        return insight
    }
    
    /// Check if an anomaly is relevant to an insight type
    private func isAnomalyRelevant(_ anomaly: DetectedAnomaly, to type: ExplainInsightType) -> Bool {
        switch type {
        case .cpuSaturation, .coreImbalance:
            return anomaly.metric.contains("CPU")
        case .memoryPressure:
            return anomaly.metric.contains("Memory")
        case .thermalThrottling, .silentThrottling, .environmentalHeat:
            return anomaly.metric.contains("Temperature")
        case .ioBottleneck, .ioAmplification:
            return anomaly.metric.contains("Disk") || anomaly.metric.contains("I/O")
        default:
            return false
        }
    }
}

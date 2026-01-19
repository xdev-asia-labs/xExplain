import Foundation

/// Enhances insights with "what if" counterfactual analysis
/// This is the KEY differentiator of xExplain
public final class CounterfactualAnalyzer: @unchecked Sendable {
    
    public init() {}
    
    /// Enhance an insight with counterfactual analysis
    public func enhance(
        insight: ExplainInsight,
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> ExplainInsight {
        // If already has counterfactual, return as-is
        if insight.counterfactual != nil {
            return insight
        }
        
        // Generate counterfactual based on insight type
        let counterfactual = generateCounterfactual(
            for: insight,
            metrics: metrics,
            processes: processes
        )
        
        // Create new insight with counterfactual
        return ExplainInsight(
            symptom: insight.symptom,
            rootCause: insight.rootCause,
            explanation: insight.explanation,
            confidence: insight.confidence,
            type: insight.type,
            severity: insight.severity,
            counterfactual: counterfactual,
            actionSafety: insight.actionSafety,
            audience: insight.audience,
            suggestedActions: insight.suggestedActions,
            affectedProcesses: insight.affectedProcesses,
            relatedMetrics: insight.relatedMetrics
        )
    }
    
    /// Generate counterfactual for an insight
    private func generateCounterfactual(
        for insight: ExplainInsight,
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> Counterfactual? {
        switch insight.type {
        case .cpuSaturation:
            return cpuCounterfactual(metrics: metrics, processes: processes)
            
        case .memoryPressure:
            return memoryCounterfactual(metrics: metrics, processes: processes)
            
        case .thermalThrottling, .silentThrottling:
            return thermalCounterfactual(metrics: metrics)
            
        case .ioBottleneck, .ioAmplification:
            return ioCounterfactual(metrics: metrics, processes: processes)
            
        case .devLoopDetected:
            return devLoopCounterfactual(processes: processes)
            
        case .coreImbalance:
            return coreImbalanceCounterfactual(metrics: metrics)
            
        case .mlWorkloadFallback:
            return mlWorkloadCounterfactual(processes: processes)
            
        default:
            return nil
        }
    }
    
    // MARK: - Counterfactual Generators
    
    private func cpuCounterfactual(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> Counterfactual? {
        guard let topProcess = processes
            .sorted(by: { $0.cpuUsage > $1.cpuUsage })
            .first,
              topProcess.cpuUsage > 20
        else { return nil }
        
        let estimatedReduction = topProcess.cpuUsage
        let newCPU = max(0, metrics.cpuUsage - estimatedReduction)
        
        return Counterfactual(
            action: "Quit \(topProcess.displayName)",
            expectedOutcome: "CPU sẽ giảm từ \(String(format: "%.0f", metrics.cpuUsage))% xuống ~\(String(format: "%.0f", newCPU))%",
            quantifiedImpact: "-\(String(format: "%.0f", estimatedReduction))%",
            confidence: min(0.9, estimatedReduction / metrics.cpuUsage),
            timeToEffect: 2.0
        )
    }
    
    private func memoryCounterfactual(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> Counterfactual? {
        guard let topProcess = processes
            .sorted(by: { $0.memoryBytes > $1.memoryBytes })
            .first
        else { return nil }
        
        let memoryGB = Double(topProcess.memoryBytes) / 1_073_741_824
        guard memoryGB > 0.5 else { return nil }
        
        return Counterfactual(
            action: "Quit \(topProcess.displayName)",
            expectedOutcome: "Giải phóng \(String(format: "%.1f", memoryGB))GB RAM",
            quantifiedImpact: "+\(String(format: "%.1f", memoryGB))GB",
            confidence: 0.95,
            timeToEffect: 1.0
        )
    }
    
    private func thermalCounterfactual(metrics: NormalizedMetrics) -> Counterfactual? {
        return Counterfactual(
            action: "Giảm workload 50%",
            expectedOutcome: "Nhiệt độ sẽ giảm ~\(String(format: "%.0f", metrics.cpuTemperature * 0.15))°C trong 2-3 phút",
            quantifiedImpact: "-15%",
            confidence: 0.7,
            timeToEffect: 180.0 // 3 minutes
        )
    }
    
    private func ioCounterfactual(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> Counterfactual? {
        let totalIO = metrics.diskReadRate + metrics.diskWriteRate
        
        return Counterfactual(
            action: "Đợi hoàn thành hoặc pause heavy tasks",
            expectedOutcome: "Disk I/O sẽ giảm từ \(String(format: "%.0f", totalIO))MB/s",
            quantifiedImpact: nil,
            confidence: 0.6,
            timeToEffect: 60.0
        )
    }
    
    private func devLoopCounterfactual(processes: [ProcessSnapshot]) -> Counterfactual? {
        // Find potential file watcher processes
        let watcherProcesses = processes.filter { proc in
            proc.name.lowercased().contains("node") ||
            proc.name.lowercased().contains("esbuild") ||
            proc.name.lowercased().contains("vite") ||
            proc.name.lowercased().contains("webpack")
        }
        
        guard !watcherProcesses.isEmpty else { return nil }
        
        return Counterfactual(
            action: "Optimize file watcher config (ignore node_modules, .git)",
            expectedOutcome: "Giảm rebuild loop và CPU spikes",
            quantifiedImpact: "-30% CPU",
            confidence: 0.75,
            timeToEffect: 0 // Immediate after config change
        )
    }
    
    private func coreImbalanceCounterfactual(metrics: NormalizedMetrics) -> Counterfactual? {
        let pCoreUsages = metrics.coreUsages.filter { $0.coreType == .performance }.map { $0.usage }
        let eCoreUsages = metrics.coreUsages.filter { $0.coreType == .efficiency }.map { $0.usage }
        
        guard !pCoreUsages.isEmpty, !eCoreUsages.isEmpty else { return nil }
        
        let avgPCore = pCoreUsages.reduce(0, +) / Double(pCoreUsages.count)
        let avgECore = eCoreUsages.reduce(0, +) / Double(eCoreUsages.count)
        
        if avgPCore < 30 && avgECore > 70 {
            return Counterfactual(
                action: "Workload phù hợp hơn với P-cores",
                expectedOutcome: "Performance cores sẽ được sử dụng, tăng throughput",
                quantifiedImpact: "~2x faster",
                confidence: 0.65,
                timeToEffect: nil
            )
        }
        
        return nil
    }
    
    private func mlWorkloadCounterfactual(processes: [ProcessSnapshot]) -> Counterfactual? {
        return Counterfactual(
            action: "Sử dụng Metal/ANE thay vì CPU",
            expectedOutcome: "AI inference nhanh hơn và tiết kiệm pin",
            quantifiedImpact: "~5x faster, -60% power",
            confidence: 0.80,
            timeToEffect: nil
        )
    }
}

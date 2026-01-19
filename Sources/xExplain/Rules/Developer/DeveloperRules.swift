import Foundation

// MARK: - Core Imbalance Rule

/// Detects when P-cores are idle while E-cores are overloaded (or vice versa)
/// This is a developer-specific insight that reveals single-thread bottlenecks
public struct CoreImbalanceRule: ExplainRule {
    public let id = "core_imbalance"
    public let name = "Core Imbalance"
    public var audience: InsightAudience { .developer }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard !metrics.coreUsages.isEmpty else { return nil }
        
        let pCores = metrics.coreUsages.filter { $0.coreType == .performance }
        let eCores = metrics.coreUsages.filter { $0.coreType == .efficiency }
        
        guard !pCores.isEmpty, !eCores.isEmpty else { return nil }
        
        let avgPCore = pCores.map { $0.usage }.reduce(0, +) / Double(pCores.count)
        let avgECore = eCores.map { $0.usage }.reduce(0, +) / Double(eCores.count)
        
        // Detect imbalance: P-cores idle while E-cores busy
        if avgPCore < 30 && avgECore > 60 && metrics.cpuUsage > 50 {
            return ExplainInsight(
                symptom: "Performance cores đang idle",
                rootCause: "Workload bị single-thread bottleneck hoặc không tối ưu cho Apple Silicon",
                explanation: "P-cores (\(String(format: "%.0f", avgPCore))%) đang idle trong khi E-cores (\(String(format: "%.0f", avgECore))%) bận. Workload có thể không parallelized tốt.",
                confidence: 0.75,
                type: .coreImbalance,
                severity: .warning,
                counterfactual: Counterfactual(
                    action: "Parallelize workload",
                    expectedOutcome: "Tận dụng P-cores, tăng throughput ~2x",
                    quantifiedImpact: "+100% performance",
                    confidence: 0.7
                ),
                audience: .developer,
                suggestedActions: [
                    ExplainAction(
                        title: "Kiểm tra thread model",
                        description: "App có thể đang chạy single-threaded",
                        impact: "Tối ưu multi-threading có thể tăng 2-4x",
                        actionType: .none
                    )
                ],
                relatedMetrics: [
                    MetricSnapshot(name: "P-Core Avg", value: avgPCore, unit: "%"),
                    MetricSnapshot(name: "E-Core Avg", value: avgECore, unit: "%")
                ]
            )
        }
        
        // Detect: All on P-cores (power inefficiency)
        if avgPCore > 70 && avgECore < 20 && metrics.cpuUsage < 50 {
            return ExplainInsight(
                symptom: "Efficiency cores không được sử dụng",
                rootCause: "Light workload đang chạy trên P-cores thay vì E-cores",
                explanation: "Workload nhẹ nhưng đang dùng P-cores, gây tốn pin. macOS thường tự optimize, nhưng một số app không tối ưu.",
                confidence: 0.65,
                type: .coreImbalance,
                severity: .info,
                audience: .developer,
                relatedMetrics: [
                    MetricSnapshot(name: "P-Core Avg", value: avgPCore, unit: "%"),
                    MetricSnapshot(name: "E-Core Avg", value: avgECore, unit: "%")
                ]
            )
        }
        
        return nil
    }
}

// MARK: - Dev Loop Detection Rule

/// Detects hot reload loops causing unnecessary CPU spikes
public struct DevLoopRule: ExplainRule {
    public let id = "dev_loop"
    public let name = "Dev Loop Detection"
    public var audience: InsightAudience { .developer }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        // Look for common dev tools
        let devProcesses = processes.filter { proc in
            let name = proc.name.lowercased()
            return name.contains("node") ||
                   name.contains("esbuild") ||
                   name.contains("vite") ||
                   name.contains("webpack") ||
                   name.contains("tsc") ||
                   name.contains("swc") ||
                   name.contains("turbopack")
        }
        
        guard !devProcesses.isEmpty else { return nil }
        
        // Check for high CPU + disk I/O pattern (typical of rebuild loop)
        let totalDevCPU = devProcesses.map { $0.cpuUsage }.reduce(0, +)
        
        guard totalDevCPU > 30 && metrics.diskReadRate > 20 else { return nil }
        
        // Check history for spiky pattern
        let cpuHistory = context.metricsHistory.suffix(10).map { $0.cpuUsage }
        let hasSpikes = detectSpikes(cpuHistory)
        
        guard hasSpikes else { return nil }
        
        return ExplainInsight(
            symptom: "Hot reload loop đang gây CPU spikes",
            rootCause: "Dev tools đang rebuild liên tục",
            explanation: "Phát hiện pattern save → rebuild → reload lặp lại. File watcher có thể đang trigger quá nhiều rebuilds.",
            confidence: 0.7,
            type: .devLoopDetected,
            severity: .warning,
            counterfactual: Counterfactual(
                action: "Optimize file watcher (ignore node_modules, .git, dist)",
                expectedOutcome: "Giảm rebuild không cần thiết",
                quantifiedImpact: "-40% CPU",
                confidence: 0.75
            ),
            audience: .developer,
            suggestedActions: [
                ExplainAction(
                    title: "Thêm ignore patterns",
                    description: "Exclude node_modules, .git, dist từ file watcher",
                    impact: "Giảm đáng kể CPU usage",
                    actionType: .none
                ),
                ExplainAction(
                    title: "Sử dụng incremental builds",
                    description: "Enable caching trong build tool",
                    impact: "Build nhanh hơn 2-5x",
                    actionType: .none
                )
            ],
            affectedProcesses: devProcesses.map { $0.name }
        )
    }
    
    private func detectSpikes(_ values: [Double]) -> Bool {
        guard values.count >= 5 else { return false }
        
        var spikes = 0
        for i in 1..<(values.count - 1) {
            let prev = values[i - 1]
            let curr = values[i]
            let next = values[i + 1]
            
            // Spike = significantly higher than neighbors
            if curr > prev * 1.3 && curr > next * 1.3 {
                spikes += 1
            }
        }
        
        return spikes >= 2
    }
}

// MARK: - I/O Amplification Rule

/// Detects when a single write causes many reads (common with file watchers)
public struct IOAmplificationRule: ExplainRule {
    public let id = "io_amplification"
    public let name = "I/O Amplification"
    public var audience: InsightAudience { .developer }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard context.metricsHistory.count >= 5 else { return nil }
        
        let recent = context.metricsHistory.suffix(5)
        let avgRead = recent.map { $0.diskReadRate }.reduce(0, +) / 5
        let avgWrite = recent.map { $0.diskWriteRate }.reduce(0, +) / 5
        
        // I/O amplification: reads >> writes
        guard avgWrite > 5 && avgRead > avgWrite * 10 else { return nil }
        
        // Look for file watcher processes
        let watcherProcesses = processes.filter { proc in
            let name = proc.name.lowercased()
            return name.contains("fsevents") ||
                   name.contains("watchman") ||
                   name.contains("fs.watch") ||
                   proc.category == .developer
        }
        
        return ExplainInsight(
            symptom: "I/O Amplification detected",
            rootCause: "Một write đang trigger nhiều reads (file watcher pattern)",
            explanation: "Write: \(String(format: "%.0f", avgWrite))MB/s nhưng Read: \(String(format: "%.0f", avgRead))MB/s. File watchers có thể đang scan lại toàn bộ directory.",
            confidence: 0.7,
            type: .ioAmplification,
            severity: .warning,
            counterfactual: Counterfactual(
                action: "Limit file watcher scope",
                expectedOutcome: "Giảm disk reads đáng kể",
                quantifiedImpact: "-\(String(format: "%.0f", avgRead * 0.7))MB/s reads",
                confidence: 0.7
            ),
            audience: .developer,
            suggestedActions: [
                ExplainAction(
                    title: "Configure .watchmanconfig",
                    description: "Ignore large directories",
                    impact: "Giảm I/O spikes",
                    actionType: .none
                )
            ],
            affectedProcesses: watcherProcesses.map { $0.name }
        )
    }
}

// MARK: - ML Workload Fallback Rule

/// Detects when ML/AI workload falls back to CPU instead of GPU/ANE
public struct MLWorkloadRule: ExplainRule {
    public let id = "ml_workload"
    public let name = "ML Workload Fallback"
    public var audience: InsightAudience { .developer }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        // Find ML-related processes
        let mlProcesses = processes.filter { proc in
            proc.category == .aiml ||
            proc.name.lowercased().contains("python") ||
            proc.name.lowercased().contains("mlc") ||
            proc.name.lowercased().contains("ollama") ||
            proc.name.lowercased().contains("llama")
        }
        
        guard !mlProcesses.isEmpty else { return nil }
        
        let totalMLCPU = mlProcesses.map { $0.cpuUsage }.reduce(0, +)
        
        // High CPU from ML processes but no Metal/ANE usage
        guard totalMLCPU > 50 && !metrics.isUsingMetal && !metrics.isUsingANE else {
            return nil
        }
        
        return ExplainInsight(
            symptom: "AI/ML đang chạy trên CPU",
            rootCause: "Model inference fallback về CPU thay vì Metal/ANE",
            explanation: "ML workload đang sử dụng \(String(format: "%.0f", totalMLCPU))% CPU nhưng không dùng GPU hoặc Neural Engine. Có thể model chưa được optimize cho Apple Silicon.",
            confidence: 0.75,
            type: .mlWorkloadFallback,
            severity: .warning,
            counterfactual: Counterfactual(
                action: "Sử dụng Metal/CoreML backend",
                expectedOutcome: "Inference nhanh hơn và tiết kiệm pin",
                quantifiedImpact: "~5x faster, -60% power",
                confidence: 0.8
            ),
            audience: .developer,
            suggestedActions: [
                ExplainAction(
                    title: "Check Metal support",
                    description: "Đảm bảo framework hỗ trợ Metal backend",
                    impact: "Tăng 5-10x inference speed",
                    actionType: .none
                ),
                ExplainAction(
                    title: "Convert to CoreML",
                    description: "Dùng coremltools để convert model",
                    impact: "Tận dụng Neural Engine",
                    actionType: .none
                )
            ],
            affectedProcesses: mlProcesses.map { $0.name },
            relatedMetrics: [
                MetricSnapshot(name: "ML CPU Usage", value: totalMLCPU, unit: "%"),
                MetricSnapshot(name: "GPU Usage", value: metrics.gpuUsage, unit: "%")
            ]
        )
    }
}

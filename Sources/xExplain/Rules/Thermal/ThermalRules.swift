import Foundation

// MARK: - Silent Throttle Detection Rule

/// Detects when CPU is throttled before thermal state changes
/// Apple reduces frequency silently - this catches that
public struct SilentThrottleRule: ExplainRule {
    public let id = "silent_throttle"
    public let name = "Silent Throttling Detection"
    public var audience: InsightAudience { .power }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        // Check if we have throttle info
        if let throttleInfo = context.throttleInfo, throttleInfo.isThrottling {
            guard throttleInfo.frequencyReduction > 10 else { return nil }
            
            return ExplainInsight(
                symptom: "CPU đang bị silent throttle",
                rootCause: "Frequency giảm \(String(format: "%.0f", throttleInfo.frequencyReduction))% dù thermal state chưa critical",
                explanation: "Apple âm thầm giảm CPU frequency để kiểm soát nhiệt. Hiệu năng thực tế thấp hơn hiển thị.",
                confidence: 0.85,
                type: .silentThrottling,
                severity: throttleInfo.frequencyReduction > 30 ? .warning : .info,
                counterfactual: Counterfactual(
                    action: "Giảm workload hoặc cooling",
                    expectedOutcome: "Frequency sẽ phục hồi về max",
                    quantifiedImpact: "+\(String(format: "%.0f", throttleInfo.frequencyReduction))% performance",
                    confidence: 0.8,
                    timeToEffect: 60.0
                ),
                audience: .power,
                relatedMetrics: [
                    MetricSnapshot(name: "Frequency Reduction", value: throttleInfo.frequencyReduction, unit: "%"),
                    MetricSnapshot(name: "CPU Temp", value: metrics.cpuTemperature, unit: "°C")
                ]
            )
        }
        
        // Fallback: detect via frequency vs max frequency
        guard let currentFreq = metrics.cpuFrequencyMHz,
              let maxFreq = metrics.maxFrequencyMHz,
              maxFreq > 0 else { return nil }
        
        let reduction = ((maxFreq - currentFreq) / maxFreq) * 100
        
        guard reduction > 15 && metrics.thermalState != .critical else { return nil }
        
        return ExplainInsight(
            symptom: "CPU frequency thấp hơn bình thường",
            rootCause: "Đang chạy ở \(String(format: "%.0f", currentFreq))MHz thay vì \(String(format: "%.0f", maxFreq))MHz",
            explanation: "CPU đang bị giới hạn frequency (\(String(format: "%.0f", reduction))%). Có thể do thermal management hoặc power limit.",
            confidence: 0.7,
            type: .silentThrottling,
            severity: .info,
            audience: .power,
            relatedMetrics: [
                MetricSnapshot(name: "Current Freq", value: currentFreq, unit: "MHz"),
                MetricSnapshot(name: "Max Freq", value: maxFreq, unit: "MHz")
            ]
        )
    }
}

// MARK: - Energy Efficiency Rule

/// Detects inefficient power usage patterns
public struct EnergyEfficiencyRule: ExplainRule {
    public let id = "energy_efficiency"
    public let name = "Energy Inefficiency"
    public var audience: InsightAudience { .power }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard metrics.isOnBattery else { return nil }
        
        // Check for efficiency core wake-up frequency
        let _ = metrics.coreUsages.filter { $0.coreType == .efficiency }
        
        // Look for processes with low CPU but frequent activity (wake-ups)
        let inefficientProcesses = processes.filter { proc in
            proc.cpuUsage > 0.5 && proc.cpuUsage < 5 && !proc.isSystemProcess
        }
        
        guard !inefficientProcesses.isEmpty else { return nil }
        
        let totalLowCPU = inefficientProcesses.map { $0.cpuUsage }.reduce(0, +)
        
        // Many processes with tiny CPU usage = lots of wake-ups = battery drain
        if inefficientProcesses.count > 5 && totalLowCPU > 10 {
            return ExplainInsight(
                symptom: "Nhiều apps đang wake-up CPU thường xuyên",
                rootCause: "\(inefficientProcesses.count) apps dùng ít CPU nhưng wake-up liên tục",
                explanation: "Các background apps đang gây CPU wake-ups thường xuyên, ảnh hưởng đến battery life. Mỗi wake-up tiêu tốn năng lượng dù CPU usage thấp.",
                confidence: 0.7,
                type: .energyInefficiency,
                severity: .info,
                audience: .power,
                suggestedActions: [
                    ExplainAction(
                        title: "Quit background apps",
                        description: "Đóng các apps không cần thiết",
                        impact: "Kéo dài battery ~15%",
                        actionType: .reduceLoad(suggestions: inefficientProcesses.prefix(3).map { $0.displayName })
                    )
                ],
                affectedProcesses: inefficientProcesses.map { $0.name }
            )
        }
        
        return nil
    }
}

// MARK: - Thermal Forecast Rule

/// Predicts when thermal throttling will occur
public struct ThermalForecastRule: ExplainRule {
    public let id = "thermal_forecast"
    public let name = "Thermal Forecast"
    public var audience: InsightAudience { .power }
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard context.metricsHistory.count >= 10 else { return nil }
        
        // Already throttling? Skip
        guard metrics.thermalState != .critical && metrics.thermalState != .serious else {
            return nil
        }
        
        let tempHistory = context.metricsHistory.suffix(10).map { $0.cpuTemperature }
        let trend = calculateTrend(tempHistory)
        
        // Only predict if temperature is rising
        guard trend > 0.5 else { return nil } // >0.5°C per sample
        
        let currentTemp = metrics.cpuTemperature
        let throttleTemp = 90.0 // Typical throttle threshold
        
        guard currentTemp > 70 && currentTemp < throttleTemp else { return nil }
        
        let degreesToThrottle = throttleTemp - currentTemp
        let samplesPerMinute = 6.0 // Assuming 10s intervals
        let minutesToThrottle = degreesToThrottle / (trend * samplesPerMinute)
        
        guard minutesToThrottle > 0 && minutesToThrottle < 10 else { return nil }
        
        return ExplainInsight(
            symptom: "Thermal throttle dự đoán trong ~\(String(format: "%.0f", minutesToThrottle)) phút",
            rootCause: "Nhiệt độ đang tăng \(String(format: "%.1f", trend * samplesPerMinute))°C/phút",
            explanation: "Với workload hiện tại, CPU sẽ đạt ngưỡng throttle (~\(String(format: "%.0f", throttleTemp))°C) trong khoảng \(String(format: "%.0f", minutesToThrottle)) phút.",
            confidence: 0.65,
            type: .thermalForecast,
            severity: .info,
            counterfactual: Counterfactual(
                action: "Giảm 30% workload ngay",
                expectedOutcome: "Tránh được thermal throttle",
                quantifiedImpact: "Maintain full performance",
                confidence: 0.7,
                timeToEffect: 30.0
            ),
            audience: .power,
            suggestedActions: [
                ExplainAction(
                    title: "Preemptive cooling",
                    description: "Giảm tải trước khi throttle",
                    impact: "Tránh performance drop",
                    actionType: .reduceLoad(suggestions: [
                        "Close unused apps",
                        "Pause heavy tasks temporarily",
                        "Move to cooler location"
                    ])
                )
            ],
            relatedMetrics: [
                MetricSnapshot(name: "Current Temp", value: currentTemp, unit: "°C"),
                MetricSnapshot(name: "Trend", value: trend * samplesPerMinute, unit: "°C/min"),
                MetricSnapshot(name: "Time to Throttle", value: minutesToThrottle, unit: "min")
            ]
        )
    }
    
    private func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 3 else { return 0 }
        
        let n = Double(values.count)
        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0
        
        for (i, value) in values.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += value
            sumXY += x * value
            sumX2 += x * x
        }
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }
}

import Foundation

/// Detects anomalies in system metrics using statistical analysis
public final class AnomalyDetector: @unchecked Sendable {
    
    private var baselineStats: [String: BaselineStats] = [:]
    
    public init() {}
    
    /// Detect anomalies in current metrics compared to history
    public func detect(
        current: NormalizedMetrics,
        history: [NormalizedMetrics]
    ) -> [DetectedAnomaly] {
        guard history.count >= 10 else { return [] }
        
        var anomalies: [DetectedAnomaly] = []
        
        // CPU anomaly detection
        if let cpuAnomaly = detectMetricAnomaly(
            name: "CPU Usage",
            currentValue: current.cpuUsage,
            historicalValues: history.map { $0.cpuUsage }
        ) {
            anomalies.append(cpuAnomaly)
        }
        
        // Memory anomaly detection
        if let memAnomaly = detectMetricAnomaly(
            name: "Memory Usage",
            currentValue: current.memoryUsagePercent,
            historicalValues: history.map { $0.memoryUsagePercent }
        ) {
            anomalies.append(memAnomaly)
        }
        
        // Temperature anomaly detection
        if let tempAnomaly = detectMetricAnomaly(
            name: "CPU Temperature",
            currentValue: current.cpuTemperature,
            historicalValues: history.map { $0.cpuTemperature },
            deviationThreshold: 1.5 // More sensitive for temperature
        ) {
            anomalies.append(tempAnomaly)
        }
        
        // Disk I/O anomaly detection
        let totalIO = current.diskReadRate + current.diskWriteRate
        let historicalIO = history.map { $0.diskReadRate + $0.diskWriteRate }
        if let ioAnomaly = detectMetricAnomaly(
            name: "Disk I/O",
            currentValue: totalIO,
            historicalValues: historicalIO
        ) {
            anomalies.append(ioAnomaly)
        }
        
        return anomalies
    }
    
    /// Detect anomaly for a single metric
    private func detectMetricAnomaly(
        name: String,
        currentValue: Double,
        historicalValues: [Double],
        deviationThreshold: Double = 2.0
    ) -> DetectedAnomaly? {
        let stats = calculateStats(historicalValues)
        
        guard stats.stdDev > 0.001 else { return nil }
        
        let deviation = (currentValue - stats.mean) / stats.stdDev
        
        if abs(deviation) > deviationThreshold {
            return DetectedAnomaly(
                metric: name,
                currentValue: currentValue,
                expectedValue: stats.mean,
                deviation: deviation
            )
        }
        
        return nil
    }
    
    /// Calculate mean and standard deviation
    private func calculateStats(_ values: [Double]) -> BaselineStats {
        guard !values.isEmpty else {
            return BaselineStats(mean: 0, stdDev: 0, count: 0)
        }
        
        let count = Double(values.count)
        let mean = values.reduce(0, +) / count
        
        let variance = values.reduce(0) { acc, value in
            let diff = value - mean
            return acc + (diff * diff)
        } / count
        
        let stdDev = sqrt(variance)
        
        return BaselineStats(mean: mean, stdDev: stdDev, count: values.count)
    }
}

// MARK: - Baseline Stats

private struct BaselineStats {
    let mean: Double
    let stdDev: Double
    let count: Int
}

import Foundation

/// Analyzes correlations between metrics and processes
public final class CorrelationEngine: @unchecked Sendable {
    
    public init() {}
    
    /// Find correlations between metrics and processes
    public func correlate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot]
    ) -> [MetricCorrelation] {
        var correlations: [MetricCorrelation] = []
        
        // CPU correlations
        if metrics.cpuUsage > 50 {
            correlations.append(contentsOf: correlateCPU(
                usage: metrics.cpuUsage,
                processes: processes
            ))
        }
        
        // Memory correlations
        if metrics.memoryPressure != .normal {
            correlations.append(contentsOf: correlateMemory(
                pressure: metrics.memoryPressure,
                processes: processes,
                totalMemory: metrics.memoryTotalBytes
            ))
        }
        
        // Disk I/O correlations
        if metrics.diskReadRate > 50 || metrics.diskWriteRate > 50 {
            correlations.append(contentsOf: correlateDiskIO(
                readRate: metrics.diskReadRate,
                writeRate: metrics.diskWriteRate,
                processes: processes
            ))
        }
        
        return correlations
    }
    
    // MARK: - CPU Correlation
    
    private func correlateCPU(
        usage: Double,
        processes: [ProcessSnapshot]
    ) -> [MetricCorrelation] {
        var correlations: [MetricCorrelation] = []
        
        let topCPU = processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(5)
        
        for process in topCPU where process.cpuUsage > 10 {
            let strength = min(process.cpuUsage / usage, 1.0)
            let description = describeCPUUsage(process)
            
            correlations.append(MetricCorrelation(
                metric: "CPU Usage",
                process: process,
                strength: strength,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeCPUUsage(_ process: ProcessSnapshot) -> String {
        let name = process.displayName
        let usage = Int(process.cpuUsage)
        
        switch process.category {
        case .browser:
            return "\(name) đang sử dụng \(usage)% CPU - có thể do nhiều tabs hoặc extensions"
        case .developer:
            if name.lowercased().contains("xcode") {
                return "\(name) đang sử dụng \(usage)% CPU - có thể đang build hoặc indexing"
            }
            if name.lowercased().contains("docker") {
                return "Docker đang sử dụng \(usage)% CPU - containers đang hoạt động"
            }
            return "\(name) đang sử dụng \(usage)% CPU"
        case .system:
            if name == "kernel_task" {
                return "kernel_task sử dụng \(usage)% CPU - hệ thống có thể đang thermal throttle"
            }
            if name.contains("mds") || name.contains("Spotlight") {
                return "Spotlight đang index - sử dụng \(usage)% CPU"
            }
            return "\(name) đang sử dụng \(usage)% CPU"
        case .aiml:
            return "\(name) đang chạy AI/ML workload - sử dụng \(usage)% CPU"
        case .container:
            return "\(name) container đang hoạt động - sử dụng \(usage)% CPU"
        default:
            return "\(name) đang sử dụng \(usage)% CPU"
        }
    }
    
    // MARK: - Memory Correlation
    
    private func correlateMemory(
        pressure: MemoryPressureLevel,
        processes: [ProcessSnapshot],
        totalMemory: UInt64
    ) -> [MetricCorrelation] {
        var correlations: [MetricCorrelation] = []
        
        let topMemory = processes
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(5)
        
        for process in topMemory {
            let memoryRatio = Double(process.memoryBytes) / Double(totalMemory)
            guard memoryRatio > 0.05 else { continue }
            
            let strength = min(memoryRatio * 2, 1.0)
            let description = describeMemoryUsage(process, ratio: memoryRatio)
            
            correlations.append(MetricCorrelation(
                metric: "Memory Pressure",
                process: process,
                strength: strength,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeMemoryUsage(_ process: ProcessSnapshot, ratio: Double) -> String {
        let name = process.displayName
        let memoryGB = Double(process.memoryBytes) / 1_073_741_824
        let percentOfTotal = Int(ratio * 100)
        
        if memoryGB >= 1 {
            return "\(name) đang chiếm \(String(format: "%.1f", memoryGB))GB RAM (\(percentOfTotal)% tổng bộ nhớ)"
        } else {
            let memoryMB = Int(Double(process.memoryBytes) / 1_048_576)
            return "\(name) đang sử dụng \(memoryMB)MB RAM"
        }
    }
    
    // MARK: - Disk I/O Correlation
    
    private func correlateDiskIO(
        readRate: Double,
        writeRate: Double,
        processes: [ProcessSnapshot]
    ) -> [MetricCorrelation] {
        var correlations: [MetricCorrelation] = []
        
        let topDisk = processes
            .sorted { ($0.diskReadBytes + $0.diskWriteBytes) > ($1.diskReadBytes + $1.diskWriteBytes) }
            .prefix(3)
        
        for process in topDisk {
            let totalBytes = process.diskReadBytes + process.diskWriteBytes
            guard totalBytes > 10_000_000 else { continue }
            
            let description = describeDiskUsage(process)
            
            correlations.append(MetricCorrelation(
                metric: "Disk I/O",
                process: process,
                strength: 0.8,
                description: description
            ))
        }
        
        return correlations
    }
    
    private func describeDiskUsage(_ process: ProcessSnapshot) -> String {
        let name = process.displayName
        
        if name.contains("mds") || name.contains("Spotlight") {
            return "Spotlight đang index files - gây ra disk I/O cao"
        }
        if name.contains("backupd") || name.contains("Time Machine") {
            return "Time Machine đang backup - disk I/O sẽ cao trong thời gian ngắn"
        }
        if name.contains("bird") || name.contains("cloudd") {
            return "iCloud đang sync files - có thể gây disk I/O"
        }
        
        return "\(name) đang đọc/ghi disk nhiều"
    }
}

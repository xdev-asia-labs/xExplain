import Foundation

// MARK: - CPU Saturation Rule

/// Detects high CPU usage and identifies the cause
public struct CPUSaturationRule: ExplainRule {
    public let id = "cpu_saturation"
    public let name = "CPU Saturation"
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard metrics.cpuUsage > 80 else { return nil }
        
        let topProcesses = processes
            .sorted { $0.cpuUsage > $1.cpuUsage }
            .prefix(5)
        
        guard let topProcess = topProcesses.first else { return nil }
        
        let description = generateDescription(
            topProcess: topProcess,
            totalCPU: metrics.cpuUsage,
            thermalState: metrics.thermalState
        )
        
        let severity: ExplainSeverity = metrics.cpuUsage > 95 ? .critical : .warning
        
        var actions: [ExplainAction] = []
        
        if topProcess.cpuUsage > 50 {
            actions.append(ExplainAction(
                title: "Đóng \(topProcess.displayName)",
                description: "App này đang sử dụng nhiều CPU nhất",
                impact: "Giải phóng ~\(Int(topProcess.cpuUsage))% CPU",
                safety: topProcess.isSystemProcess ? .caution : .safe,
                actionType: .quitApp(processName: topProcess.name, pid: topProcess.id)
            ))
        }
        
        actions.append(ExplainAction(
            title: "Mở Activity Monitor",
            description: "Xem chi tiết tất cả processes",
            impact: "",
            actionType: .openActivityMonitor
        ))
        
        return ExplainInsight(
            symptom: "CPU đang quá tải (\(Int(metrics.cpuUsage))%)",
            rootCause: "\(topProcess.displayName) đang sử dụng \(Int(topProcess.cpuUsage))% CPU",
            explanation: description,
            confidence: 0.85,
            type: .cpuSaturation,
            severity: severity,
            actionSafety: topProcess.isSystemProcess ? .caution : .safe,
            suggestedActions: actions,
            affectedProcesses: topProcesses.map { $0.name },
            relatedMetrics: [
                MetricSnapshot(name: "CPU Usage", value: metrics.cpuUsage, unit: "%"),
                MetricSnapshot(name: "Top Process CPU", value: topProcess.cpuUsage, unit: "%")
            ]
        )
    }
    
    private func generateDescription(
        topProcess: ProcessSnapshot,
        totalCPU: Double,
        thermalState: ThermalStateLevel
    ) -> String {
        let name = topProcess.displayName
        let cpu = Int(topProcess.cpuUsage)
        
        if name == "kernel_task" && cpu > 30 {
            return "Hệ thống đang thermal throttling để làm mát. CPU cần giảm tải để tránh quá nhiệt."
        }
        
        switch topProcess.category {
        case .browser:
            return "\(name) đang ngốn \(cpu)% CPU. Có thể do nhiều tabs đang mở hoặc có extension nặng."
        case .developer:
            if name.lowercased().contains("xcode") || name.contains("clang") || name.contains("swift") {
                return "Xcode đang compile code, sử dụng \(cpu)% CPU. Build sẽ hoàn thành sớm."
            }
            if name.lowercased().contains("docker") {
                return "Docker containers đang hoạt động mạnh, sử dụng \(cpu)% CPU."
            }
            return "\(name) đang sử dụng \(cpu)% CPU - có thể đang build hoặc processing."
        case .aiml:
            return "\(name) đang chạy AI/ML workload, sử dụng \(cpu)% CPU."
        default:
            return "\(name) đang sử dụng \(cpu)% CPU, chiếm phần lớn tài nguyên xử lý."
        }
    }
}

// MARK: - Memory Pressure Rule

/// Detects memory pressure and identifies memory hogs
public struct MemoryPressureRule: ExplainRule {
    public let id = "memory_pressure"
    public let name = "Memory Pressure"
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard metrics.memoryPressure != .normal else { return nil }
        
        let topProcesses = processes
            .sorted { $0.memoryBytes > $1.memoryBytes }
            .prefix(5)
        
        guard let topProcess = topProcesses.first else { return nil }
        
        let description = generateDescription(topProcess: topProcess, metrics: metrics)
        let severity: ExplainSeverity = metrics.memoryPressure == .critical ? .critical : .warning
        
        var actions: [ExplainAction] = []
        
        let memoryGB = Double(topProcess.memoryBytes) / 1_073_741_824
        if memoryGB > 1 {
            actions.append(ExplainAction(
                title: "Đóng \(topProcess.displayName)",
                description: "App này đang chiếm nhiều RAM nhất",
                impact: "Giải phóng ~\(String(format: "%.1f", memoryGB))GB RAM",
                safety: topProcess.isSystemProcess ? .caution : .safe,
                actionType: .quitApp(processName: topProcess.name, pid: topProcess.id)
            ))
        }
        
        return ExplainInsight(
            symptom: "Bộ nhớ đang chịu áp lực \(metrics.memoryPressure.rawValue)",
            rootCause: "\(topProcess.displayName) đang chiếm \(String(format: "%.1f", memoryGB))GB RAM",
            explanation: description,
            confidence: 0.9,
            type: .memoryPressure,
            severity: severity,
            suggestedActions: actions,
            affectedProcesses: topProcesses.map { $0.name },
            relatedMetrics: [
                MetricSnapshot(name: "Memory Usage", value: metrics.memoryUsagePercent, unit: "%"),
                MetricSnapshot(name: "Swap Used", value: Double(metrics.swapUsedBytes) / 1_048_576, unit: "MB")
            ]
        )
    }
    
    private func generateDescription(topProcess: ProcessSnapshot, metrics: NormalizedMetrics) -> String {
        let totalMemGB = Double(metrics.memoryTotalBytes) / 1_073_741_824
        let usedMemGB = Double(metrics.memoryUsedBytes) / 1_073_741_824
        let swapMB = Double(metrics.swapUsedBytes) / 1_048_576
        
        var desc = "Đang sử dụng \(String(format: "%.1f", usedMemGB))GB / \(String(format: "%.0f", totalMemGB))GB RAM. "
        
        if swapMB > 100 {
            desc += "Hệ thống đang dùng \(String(format: "%.0f", swapMB))MB swap, có thể gây chậm. "
        }
        
        let topMemGB = Double(topProcess.memoryBytes) / 1_073_741_824
        if topMemGB > 2 {
            desc += "\(topProcess.displayName) đang chiếm \(String(format: "%.1f", topMemGB))GB."
        }
        
        return desc
    }
}

// MARK: - I/O Bottleneck Rule

/// Detects high disk I/O
public struct IOBottleneckRule: ExplainRule {
    public let id = "io_bottleneck"
    public let name = "I/O Bottleneck"
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        let totalIO = metrics.diskReadRate + metrics.diskWriteRate
        guard totalIO > 100 else { return nil }
        
        let description = generateDescription(metrics: metrics, correlations: context.correlations)
        let severity: ExplainSeverity = totalIO > 200 ? .critical : .warning
        
        return ExplainInsight(
            symptom: "Disk I/O cao (\(String(format: "%.0f", totalIO)) MB/s)",
            rootCause: "Đọc: \(String(format: "%.0f", metrics.diskReadRate))MB/s, Ghi: \(String(format: "%.0f", metrics.diskWriteRate))MB/s",
            explanation: description,
            confidence: 0.8,
            type: .ioBottleneck,
            severity: severity,
            suggestedActions: [
                ExplainAction(
                    title: "Đợi hoàn thành",
                    description: "I/O thường giảm sau vài phút",
                    impact: "",
                    actionType: .reduceLoad(suggestions: ["Tránh copy files lớn khác", "Đợi Spotlight index xong"])
                )
            ],
            relatedMetrics: [
                MetricSnapshot(name: "Disk Read", value: metrics.diskReadRate, unit: "MB/s"),
                MetricSnapshot(name: "Disk Write", value: metrics.diskWriteRate, unit: "MB/s")
            ]
        )
    }
    
    private func generateDescription(metrics: NormalizedMetrics, correlations: [MetricCorrelation]) -> String {
        let diskCorrelations = correlations.filter { $0.metric == "Disk I/O" }
        
        if let topCorrelation = diskCorrelations.first {
            return topCorrelation.description
        }
        
        if metrics.diskWriteRate > metrics.diskReadRate * 2 {
            return "Đang ghi nhiều dữ liệu. Có thể là backup, download, hoặc app đang save files lớn."
        }
        
        if metrics.diskReadRate > metrics.diskWriteRate * 2 {
            return "Đang đọc nhiều dữ liệu. Có thể là app đang load files hoặc Spotlight đang index."
        }
        
        return "Disk đang hoạt động nặng với cả đọc và ghi. Hệ thống có thể chậm lại."
    }
}

// MARK: - Thermal Throttling Rule

/// Detects thermal throttling
public struct ThermalThrottlingRule: ExplainRule {
    public let id = "thermal_throttling"
    public let name = "Thermal Throttling"
    
    public init() {}
    
    public func evaluate(
        metrics: NormalizedMetrics,
        processes: [ProcessSnapshot],
        context: EvaluationContext
    ) -> ExplainInsight? {
        guard metrics.thermalState == .serious || metrics.thermalState == .critical else {
            return nil
        }
        
        let severity: ExplainSeverity = metrics.thermalState == .critical ? .critical : .warning
        let description = generateDescription(metrics: metrics)
        
        var actions: [ExplainAction] = []
        
        actions.append(ExplainAction(
            title: "Giảm tải CPU",
            description: "Đóng các app không cần thiết",
            impact: "Giúp CPU mát hơn",
            actionType: .reduceLoad(suggestions: [
                "Đóng browser tabs không dùng",
                "Pause downloads/uploads",
                "Quit heavy apps"
            ])
        ))
        
        actions.append(ExplainAction(
            title: "Cải thiện thông gió",
            description: "Đảm bảo Mac có không gian thoáng",
            impact: "Cải thiện tản nhiệt",
            actionType: .reduceLoad(suggestions: [
                "Không đặt Mac trên chăn/gối",
                "Dùng laptop stand",
                "Tránh ánh nắng trực tiếp"
            ])
        ))
        
        return ExplainInsight(
            symptom: "Mac đang quá nóng - CPU throttling",
            rootCause: "Nhiệt độ CPU: \(String(format: "%.0f", metrics.cpuTemperature))°C",
            explanation: description,
            confidence: 0.95,
            type: .thermalThrottling,
            severity: severity,
            suggestedActions: actions,
            relatedMetrics: [
                MetricSnapshot(name: "CPU Temperature", value: metrics.cpuTemperature, unit: "°C"),
                MetricSnapshot(name: "Fan Speed", value: Double(metrics.fanSpeed), unit: "RPM")
            ]
        )
    }
    
    private func generateDescription(metrics: NormalizedMetrics) -> String {
        var desc = "Mac đang \(metrics.thermalState.rawValue.lowercased()). "
        
        if metrics.thermalState == .critical {
            desc += "CPU đang bị giảm tốc độ mạnh để làm mát. Hiệu năng sẽ giảm đáng kể."
        } else {
            desc += "CPU có thể bị giảm hiệu năng để tránh quá nhiệt."
        }
        
        if metrics.fanSpeed > 0 {
            desc += " Fan đang chạy ở \(metrics.fanSpeed) RPM."
        }
        
        return desc
    }
}

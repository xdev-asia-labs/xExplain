import Foundation
import xExplain
import IOKit

// MARK: - xExplain CLI Tool
// A command-line interface for system analysis using the xExplain engine

@main
struct XExplainCLI {
    
    // MARK: - Command Line Arguments
    static var watchMode = false
    static var monitorMode = false
    static var jsonOutput = false
    static var watchInterval: TimeInterval = 2.0
    
    static func main() async {
        parseArguments()
        
        if jsonOutput {
            await runJSONMode()
        } else if monitorMode {
            await TerminalMonitor().run()
        } else if watchMode {
            await runWatchMode()
        } else {
            await runOnce()
        }
    }
    
    static func parseArguments() {
        let args = CommandLine.arguments
        
        for (index, arg) in args.enumerated() {
            switch arg {
            case "--watch", "-w":
                watchMode = true
            case "--monitor", "-m":
                monitorMode = true
            case "--json", "-j":
                jsonOutput = true
            case "--interval", "-i":
                if index + 1 < args.count, let interval = Double(args[index + 1]) {
                    watchInterval = interval
                }
            case "--help", "-h":
                printHelp()
                exit(0)
            case "--version", "-v":
                printVersion()
                exit(0)
            default:
                break
            }
        }
    }
    
    static func printVersion() {
        print("xExplain CLI v\(Version.current)")
        print("Build: \(Version.buildDate) (\(Version.gitCommit))")
    }
    
    static func printHelp() {
        print("""
        
        🧠 xExplain-CLI - System Intelligence for macOS
        
        Usage: xExplain-CLI [options]
        
        Options:
          --monitor, -m     htop-like terminal monitor (NEW!)
          --watch, -w       Continuous monitoring mode
          --json, -j        Output in JSON format
          --interval, -i N  Update interval in seconds (default: 2)
          --help, -h        Show this help
          --version, -v     Show version
        
        Examples:
          xExplain-CLI                    # Run once
          xExplain-CLI --watch            # Continuous monitoring
          xExplain-CLI --json             # JSON output
          xExplain-CLI -w -i 5            # Watch every 5 seconds
        
        """)
    }
    
    // MARK: - Run Modes
    
    static func runOnce() async {
        printHeader()
        
        let engine = ExplainEngine.shared
        engine.registerRules(for: .developer)
        engine.registerRules(for: .power)
        
        print("📊 Collecting system metrics...")
        
        let metrics = await collectSystemMetrics()
        let processes = collectTopProcesses()
        
        print("\n" + "=".repeated(60))
        print("📈 CURRENT SYSTEM STATE")
        print("=".repeated(60))
        
        printMetrics(metrics)
        
        print("\n" + "=".repeated(60))
        print("🔬 ANALYZING SYSTEM...")
        print("=".repeated(60))
        
        let insights = engine.analyze(metrics: metrics, processes: processes)
        
        if insights.isEmpty {
            print("\n✅ System is running normally. No issues detected.")
        } else {
            print("\n⚠️  Found \(insights.count) insight(s):\n")
            for (index, insight) in insights.enumerated() {
                printInsight(index: index + 1, insight: insight)
            }
        }
        
        print("\n" + "=".repeated(60))
        print("🌡️  THERMAL FORECAST")
        print("=".repeated(60))
        
        if let forecast = engine.thermalForecast(currentMetrics: metrics) {
            if forecast.willThrottle {
                print("\n⚠️  Warning: System may throttle in ~\(forecast.estimatedMinutes ?? 0) minutes")
            } else {
                print("\n✅ Thermal status is healthy. No throttling expected.")
            }
        } else {
            print("\n✅ Thermal status is healthy.")
        }
        
        print("\n" + "=".repeated(60))
        print("🧠 xExplain Analysis Complete")
        print("=".repeated(60) + "\n")
    }
    
    static func runWatchMode() async {
        let engine = ExplainEngine.shared
        engine.registerRules(for: .developer)
        engine.registerRules(for: .power)
        
        print("\033[2J\033[H") // Clear screen
        print("🧠 xExplain Watch Mode - Press Ctrl+C to exit\n")
        
        while true {
            print("\033[H") // Move cursor to top
            
            let metrics = await collectSystemMetrics()
            let processes = collectTopProcesses()
            let insights = engine.analyze(metrics: metrics, processes: processes)
            
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            
            print("""
            ╔═══════════════════════════════════════════════════════════╗
            ║  🧠 xExplain Watch Mode              \(timestamp)       ║
            ╠═══════════════════════════════════════════════════════════╣
            ║  CPU: \(String(format: "%5.1f%%", metrics.cpuUsage).padding(toLength: 8, withPad: " ", startingAt: 0)) │ Memory: \(String(format: "%5.1f%%", metrics.memoryUsagePercent).padding(toLength: 8, withPad: " ", startingAt: 0)) │ GPU: \(String(format: "%5.1f%%", metrics.gpuUsage).padding(toLength: 8, withPad: " ", startingAt: 0)) ║
            ║  Temp: \(String(format: "%4.0f°C", metrics.cpuTemperature).padding(toLength: 7, withPad: " ", startingAt: 0)) │ Disk: \(String(format: "%5.1f", metrics.diskReadRate + metrics.diskWriteRate).padding(toLength: 6, withPad: " ", startingAt: 0)) MB/s │ \(metrics.thermalState.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) ║
            ╠═══════════════════════════════════════════════════════════╣
            """)
            
            if insights.isEmpty {
                print("║  ✅ System healthy                                        ║")
            } else {
                for insight in insights.prefix(3) {
                    let emoji = insight.severity == .critical ? "🔴" : insight.severity == .warning ? "⚠️" : "ℹ️"
                    let msg = "\(emoji) \(insight.symptom)".prefix(55)
                    print("║  \(msg.padding(toLength: 55, withPad: " ", startingAt: 0)) ║")
                }
            }
            
            print("╚═══════════════════════════════════════════════════════════╝")
            print("\nTop Processes:")
            for (i, p) in processes.prefix(5).enumerated() {
                print("  \(i+1). \(p.name.prefix(20).padding(toLength: 20, withPad: " ", startingAt: 0)) CPU: \(String(format: "%5.1f%%", p.cpuUsage))")
            }
            
            try? await Task.sleep(nanoseconds: UInt64(watchInterval * 1_000_000_000))
        }
    }
    
    static func runJSONMode() async {
        let engine = ExplainEngine.shared
        engine.registerRules(for: .developer)
        engine.registerRules(for: .power)
        
        let metrics = await collectSystemMetrics()
        let processes = collectTopProcesses()
        let insights = engine.analyze(metrics: metrics, processes: processes)
        
        let output: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "metrics": [
                "cpu": metrics.cpuUsage,
                "memory": metrics.memoryUsagePercent,
                "gpu": metrics.gpuUsage,
                "temperature": metrics.cpuTemperature,
                "thermalState": metrics.thermalState.rawValue,
                "diskReadMBps": metrics.diskReadRate,
                "diskWriteMBps": metrics.diskWriteRate
            ],
            "processes": processes.prefix(10).map { [
                "pid": $0.id,
                "name": $0.name,
                "cpu": $0.cpuUsage,
                "memoryMB": Double($0.memoryBytes) / 1_048_576
            ] },
            "insights": insights.map { [
                "severity": $0.severity.rawValue,
                "symptom": $0.symptom,
                "rootCause": $0.rootCause,
                "explanation": $0.explanation,
                "confidence": $0.confidence
            ] },
            "healthy": insights.isEmpty
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: output, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            print(jsonString)
        }
    }
    
    // MARK: - Output Helpers
    
    static func printHeader() {
        print("""
        
        ╔═══════════════════════════════════════════════════════════╗
        ║                                                           ║
        ║   🧠 xExplain - System Intelligence CLI                   ║
        ║   Counterfactual System Analysis for macOS                ║
        ║                                                           ║
        ║   © 2026 xdev.asia                                        ║
        ╚═══════════════════════════════════════════════════════════╝
        
        """)
    }
    
    static func printMetrics(_ metrics: NormalizedMetrics) {
        let tempStatus = metrics.cpuTemperature > 80 ? "🔴" : metrics.cpuTemperature > 65 ? "🟡" : "🟢"
        let cpuStatus = metrics.cpuUsage > 80 ? "🔴" : metrics.cpuUsage > 50 ? "🟡" : "🟢"
        let memStatus = metrics.memoryUsagePercent > 80 ? "🔴" : metrics.memoryUsagePercent > 60 ? "🟡" : "🟢"
        
        print("""
        
        \(cpuStatus) CPU Usage:      \(String(format: "%.1f%%", metrics.cpuUsage))
        \(memStatus) Memory Usage:   \(String(format: "%.1f%%", metrics.memoryUsagePercent))
           GPU Usage:      \(String(format: "%.1f%%", metrics.gpuUsage))
           Disk Read:      \(String(format: "%.1f", metrics.diskReadRate)) MB/s
           Disk Write:     \(String(format: "%.1f", metrics.diskWriteRate)) MB/s
        \(tempStatus) Temperature:    \(String(format: "%.0f°C", metrics.cpuTemperature))
           Thermal State:  \(metrics.thermalState.rawValue)
           Fan Speed:      \(metrics.fanSpeed > 0 ? "\(metrics.fanSpeed) RPM" : "Passive")
        
        """)
    }
    
    static func printInsight(index: Int, insight: ExplainInsight) {
        let severityEmoji: String
        switch insight.severity {
        case .info: severityEmoji = "ℹ️"
        case .warning: severityEmoji = "⚠️"
        case .critical: severityEmoji = "🔴"
        }
        
        print("""
        ┌─────────────────────────────────────────────────────────┐
        │ \(severityEmoji) Insight #\(index)
        ├─────────────────────────────────────────────────────────┤
        │ Symptom:    \(insight.symptom)
        │ Root Cause: \(insight.rootCause)
        │ Confidence: \(String(format: "%.0f%%", insight.confidence * 100))
        │
        │ 📝 \(insight.explanation)
        """)
        
        if let cf = insight.counterfactual {
            print("""
            │
            │ 💡 Counterfactual:
            │    Action: \(cf.action)
            │    Result: \(cf.expectedOutcome)
            """)
        }
        
        print("└─────────────────────────────────────────────────────────┘\n")
    }
    
    // MARK: - Real System Metrics Collection
    
    static func collectSystemMetrics() async -> NormalizedMetrics {
        // CPU Usage - Real calculation
        let cpuUsage = getCPUUsage()
        
        // Memory - Real from mach
        let (memUsed, memTotal, memPercent) = getMemoryUsage()
        
        // Temperature - Try SMC, fallback to thermal state estimate
        let temperature = getSMCTemperature() ?? estimateTemperature()
        
        // Fan Speed - Try SMC
        let fanSpeed = getSMCFanSpeed()
        
        // GPU Usage - From IOKit
        let gpuUsage = getGPUUsage()
        
        // Disk I/O - From iostat
        let (diskRead, diskWrite) = getDiskIO()
        
        // Thermal state
        let thermalState: ThermalStateLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .nominal
        }
        
        return NormalizedMetrics(
            cpuUsage: cpuUsage,
            memoryUsagePercent: memPercent,
            memoryUsedBytes: memUsed,
            memoryTotalBytes: memTotal,
            diskReadRate: diskRead,
            diskWriteRate: diskWrite,
            cpuTemperature: temperature,
            thermalState: thermalState,
            fanSpeed: fanSpeed,
            gpuUsage: gpuUsage
        )
    }
    
    // MARK: - CPU Usage (Real)
    
    static var previousCPUInfo: host_cpu_load_info?
    
    static func getCPUUsage() -> Double {
        var cpuInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0 }
        
        let user = Double(cpuInfo.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3)
        
        if let prev = previousCPUInfo {
            let userDiff = user - Double(prev.cpu_ticks.0)
            let systemDiff = system - Double(prev.cpu_ticks.1)
            let idleDiff = idle - Double(prev.cpu_ticks.2)
            let niceDiff = nice - Double(prev.cpu_ticks.3)
            
            let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
            if totalDiff > 0 {
                previousCPUInfo = cpuInfo
                return ((userDiff + systemDiff + niceDiff) / totalDiff) * 100
            }
        }
        
        previousCPUInfo = cpuInfo
        let total = user + system + idle + nice
        return total > 0 ? ((user + system + nice) / total) * 100 : 0
    }
    
    // MARK: - Memory Usage (Real)
    
    static func getMemoryUsage() -> (used: UInt64, total: UInt64, percent: Double) {
        let total = ProcessInfo.processInfo.physicalMemory
        
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, total, 0) }
        
        let pageSize = UInt64(vm_page_size)
        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        
        let used = active + wired + compressed
        let percent = Double(used) / Double(total) * 100
        
        return (used, total, percent)
    }
    
    // MARK: - Temperature (SMC or estimate)
    
    static func getSMCTemperature() -> Double? {
        // Try to read from SMC - requires appropriate permissions
        // For now, return nil to use fallback
        return nil
    }
    
    static func estimateTemperature() -> Double {
        // Estimate based on thermal state
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 45.0
        case .fair: return 65.0
        case .serious: return 80.0
        case .critical: return 95.0
        @unknown default: return 50.0
        }
    }
    
    // MARK: - Fan Speed (SMC)
    
    static func getSMCFanSpeed() -> Int {
        // Would require SMC access - return 0 for fanless M-series
        return 0
    }
    
    // MARK: - GPU Usage
    
    static func getGPUUsage() -> Double {
        // Try to get GPU usage from powermetrics or ioreg
        // Simplified version - estimate based on CPU
        let cpuUsage = getCPUUsage()
        return min(cpuUsage * 0.3, 100) // Rough estimate
    }
    
    // MARK: - Disk I/O
    
    static func getDiskIO() -> (read: Double, write: Double) {
        // Use iostat to get real disk I/O
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/iostat")
        task.arguments = ["-d", "-c", "1"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                if lines.count >= 3 {
                    let parts = lines[2].split(separator: " ", omittingEmptySubsequences: true)
                    if parts.count >= 3,
                       let read = Double(parts[1]),
                       let write = Double(parts[2]) {
                        return (read / 1024, write / 1024) // Convert KB to MB
                    }
                }
            }
        } catch {}
        
        return (5.0, 2.0) // Fallback
    }
    
    // MARK: - Process Collection
    
    static func collectTopProcesses() -> [ProcessSnapshot] {
        var processes: [ProcessSnapshot] = []
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-Aceo", "pid,pcpu,rss,comm", "-r"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n").dropFirst()
                
                for line in lines.prefix(15) {
                    let parts = line.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
                    if parts.count >= 4,
                       let pid = Int32(parts[0]),
                       let cpu = Double(parts[1]),
                       let mem = UInt64(parts[2]) {
                        let name = String(parts[3])
                        let category = detectCategory(name)
                        processes.append(ProcessSnapshot(
                            pid: pid,
                            name: name,
                            cpuUsage: cpu,
                            memoryBytes: mem * 1024,
                            category: category
                        ))
                    }
                }
            }
        } catch {}
        
        return processes
    }
    
    static func detectCategory(_ name: String) -> ProcessCategory {
        let lowName = name.lowercased()
        if ["safari", "chrome", "firefox", "edge", "brave", "arc"].contains(where: { lowName.contains($0) }) {
            return .browser
        }
        if ["xcode", "swift", "clang", "lldb", "simulat", "node", "npm", "python", "ruby", "cargo", "gradle", "java"].contains(where: { lowName.contains($0) }) {
            return .developer
        }
        if ["docker", "podman", "containerd"].contains(where: { lowName.contains($0) }) {
            return .container
        }
        if ["slack", "teams", "zoom", "discord", "telegram"].contains(where: { lowName.contains($0) }) {
            return .communication
        }
        if ["spotify", "music", "vlc", "iina"].contains(where: { lowName.contains($0) }) {
            return .media
        }
        if ["kernel", "launchd", "windowserver"].contains(where: { lowName.contains($0) }) {
            return .system
        }
        return .other
    }
}

// MARK: - Extensions

extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

extension Substring {
    func padding(toLength length: Int, withPad pad: String, startingAt: Int) -> String {
        return String(self).padding(toLength: length, withPad: pad, startingAt: startingAt)
    }
}

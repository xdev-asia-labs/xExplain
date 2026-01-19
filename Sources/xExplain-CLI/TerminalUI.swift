import Foundation
import xExplain

// MARK: - Terminal UI Components

struct TerminalUI {
    
    // ANSI Colors
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    static let black = "\u{001B}[30m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
    
    static let bgBlack = "\u{001B}[40m"
    static let bgRed = "\u{001B}[41m"
    static let bgGreen = "\u{001B}[42m"
    static let bgYellow = "\u{001B}[43m"
    static let bgBlue = "\u{001B}[44m"
    static let bgMagenta = "\u{001B}[45m"
    static let bgCyan = "\u{001B}[46m"
    static let bgGray = "\u{001B}[100m"
    
    // Clear and cursor control
    static let clearScreen = "\u{001B}[2J\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    
    static func moveTo(_ row: Int, _ col: Int) -> String {
        return "\u{001B}[\(row);\(col)H"
    }
    
    // MARK: - Bar Charts
    
    static let barChars = ["▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
    
    static func horizontalBar(value: Double, width: Int, color: String = green) -> String {
        let clampedValue = max(0, min(100, value))
        let totalEighths = Int((clampedValue / 100.0) * Double(width) * 8)
        let fullBlocks = totalEighths / 8
        let remainder = totalEighths % 8
        
        var bar = String(repeating: "█", count: fullBlocks)
        if remainder > 0 && fullBlocks < width {
            bar += barChars[remainder - 1]
        }
        let emptyCount = max(0, width - bar.count)
        bar += String(repeating: " ", count: emptyCount)
        
        let barColor: String
        if clampedValue > 80 { barColor = red }
        else if clampedValue > 60 { barColor = yellow }
        else { barColor = color }
        
        return barColor + bar + reset
    }
    
    // MARK: - Sparkline (mini graph)
    
    static let sparkChars = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
    
    static func sparkline(values: [Double], width: Int, color: String = cyan) -> String {
        guard !values.isEmpty else { return String(repeating: "▁", count: width) }
        
        let maxVal = max(values.max() ?? 1, 1)
        let lastN = Array(values.suffix(width))
        
        var result = ""
        for val in lastN {
            let normalized = min(val / maxVal, 1.0)
            let index = Int(normalized * 7)
            result += sparkChars[index]
        }
        
        // Pad if needed
        if result.count < width {
            result = String(repeating: "▁", count: width - result.count) + result
        }
        
        return color + result + reset
    }
    
    // MARK: - Box Drawing
    
    static func box(x: Int, y: Int, width: Int, height: Int, title: String = "") -> String {
        var result = ""
        
        // Top
        result += moveTo(y, x)
        if title.isEmpty {
            result += "╭" + String(repeating: "─", count: width - 2) + "╮"
        } else {
            let titleStr = " \(title) "
            let leftPad = (width - titleStr.count - 2) / 2
            let rightPad = width - titleStr.count - leftPad - 2
            result += "╭" + String(repeating: "─", count: leftPad) + cyan + titleStr + reset + String(repeating: "─", count: rightPad) + "╮"
        }
        
        // Sides
        for row in 1..<(height - 1) {
            result += moveTo(y + row, x) + "│"
            result += moveTo(y + row, x + width - 1) + "│"
        }
        
        // Bottom
        result += moveTo(y + height - 1, x)
        result += "╰" + String(repeating: "─", count: width - 2) + "╯"
        
        return result
    }
}

// MARK: - Enhanced Terminal Monitor

class TerminalMonitor {
    let engine: ExplainEngine
    var interval: TimeInterval = 1.0
    var sortBy: SortColumn = .cpu
    
    // History for graphs
    var cpuHistory: [Double] = []
    var memHistory: [Double] = []
    var gpuHistory: [Double] = []
    var netDownHistory: [Double] = []
    var netUpHistory: [Double] = []
    
    enum SortColumn { case cpu, memory, name, pid }
    
    init() {
        engine = ExplainEngine.shared
        engine.registerRules(for: .developer)
        engine.registerRules(for: .power)
    }
    
    func run() async {
        print(TerminalUI.hideCursor, terminator: "")
        print(TerminalUI.clearScreen, terminator: "")
        
        signal(SIGINT) { _ in
            print(TerminalUI.showCursor)
            print(TerminalUI.clearScreen)
            exit(0)
        }
        
        while true {
            await render()
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    func render() async {
        let metrics = await XExplainCLI.collectSystemMetrics()
        var processes = XExplainCLI.collectTopProcesses()
        
        // Update history
        cpuHistory.append(metrics.cpuUsage)
        memHistory.append(metrics.memoryUsagePercent)
        gpuHistory.append(metrics.gpuUsage)
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        if memHistory.count > 60 { memHistory.removeFirst() }
        if gpuHistory.count > 60 { gpuHistory.removeFirst() }
        
        // Sort processes
        switch sortBy {
        case .cpu: processes.sort(by: { $0.cpuUsage > $1.cpuUsage })
        case .memory: processes.sort(by: { $0.memoryBytes > $1.memoryBytes })
        case .name: processes.sort(by: { $0.name < $1.name })
        case .pid: processes.sort(by: { $0.id < $1.id })
        }
        
        var output = TerminalUI.clearScreen
        
        // === HEADER ===
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        output += TerminalUI.moveTo(1, 1)
        output += TerminalUI.bgBlue + TerminalUI.white + TerminalUI.bold
        output += " 🧠 xExplain Monitor                                                  \(time) "
        output += TerminalUI.reset
        
        // === CPU BOX (left top) ===
        output += TerminalUI.box(x: 1, y: 2, width: 40, height: 8, title: "CPU")
        output += TerminalUI.moveTo(3, 3)
        output += "Usage: \(TerminalUI.bold)\(String(format: "%.1f%%", metrics.cpuUsage))\(TerminalUI.reset)"
        output += TerminalUI.moveTo(4, 3)
        output += TerminalUI.horizontalBar(value: metrics.cpuUsage, width: 35)
        output += TerminalUI.moveTo(5, 3)
        output += TerminalUI.dim + "History: " + TerminalUI.reset
        output += TerminalUI.sparkline(values: cpuHistory, width: 28)
        output += TerminalUI.moveTo(6, 3)
        let tempIcon = metrics.cpuTemperature > 80 ? "🔴" : metrics.cpuTemperature > 60 ? "🟡" : "🟢"
        output += "Temp: \(tempIcon) \(String(format: "%.0f°C", metrics.cpuTemperature))  "
        output += "State: \(metrics.thermalState.rawValue)"
        
        // === GPU BOX (right top) ===
        output += TerminalUI.box(x: 42, y: 2, width: 38, height: 8, title: "GPU")
        output += TerminalUI.moveTo(3, 44)
        output += "Usage: \(TerminalUI.bold)\(String(format: "%.1f%%", metrics.gpuUsage))\(TerminalUI.reset)"
        output += TerminalUI.moveTo(4, 44)
        output += TerminalUI.horizontalBar(value: metrics.gpuUsage, width: 33, color: TerminalUI.magenta)
        output += TerminalUI.moveTo(5, 44)
        output += TerminalUI.dim + "History: " + TerminalUI.reset
        output += TerminalUI.sparkline(values: gpuHistory, width: 24, color: TerminalUI.magenta)
        output += TerminalUI.moveTo(6, 44)
        output += "Metal: \(metrics.isUsingMetal ? "✓" : "–")  ANE: \(metrics.isUsingANE ? "✓" : "–")"
        
        // === MEMORY BOX (left middle) ===
        output += TerminalUI.box(x: 1, y: 10, width: 40, height: 6, title: "Memory")
        let memGB = Double(metrics.memoryUsedBytes) / 1_073_741_824
        let totalGB = Double(metrics.memoryTotalBytes) / 1_073_741_824
        output += TerminalUI.moveTo(11, 3)
        output += "Used: \(String(format: "%.1f", memGB)) / \(String(format: "%.0f", totalGB)) GB (\(String(format: "%.0f%%", metrics.memoryUsagePercent)))"
        output += TerminalUI.moveTo(12, 3)
        output += TerminalUI.horizontalBar(value: metrics.memoryUsagePercent, width: 35, color: TerminalUI.blue)
        output += TerminalUI.moveTo(13, 3)
        output += TerminalUI.dim + "Trend: " + TerminalUI.reset
        output += TerminalUI.sparkline(values: memHistory, width: 30, color: TerminalUI.blue)
        
        // === DISK/NET BOX (right middle) ===
        output += TerminalUI.box(x: 42, y: 10, width: 38, height: 6, title: "Disk / Network")
        output += TerminalUI.moveTo(11, 44)
        output += "Disk: ↓\(String(format: "%.1f", metrics.diskReadRate)) ↑\(String(format: "%.1f", metrics.diskWriteRate)) MB/s"
        output += TerminalUI.moveTo(12, 44)
        output += "Net:  ↓\(String(format: "%.1f", metrics.networkDownloadRate)) ↑\(String(format: "%.1f", metrics.networkUploadRate)) MB/s"
        output += TerminalUI.moveTo(13, 44)
        output += TerminalUI.dim + "Disk Usage: \(String(format: "%.0f%%", metrics.diskUsagePercent))" + TerminalUI.reset
        
        // === PROCESSES BOX ===
        output += TerminalUI.box(x: 1, y: 16, width: 79, height: 12, title: "Processes")
        
        // Header
        output += TerminalUI.moveTo(17, 3)
        output += TerminalUI.bgGray + TerminalUI.white
        let cpuMark = sortBy == .cpu ? "▼" : " "
        let memMark = sortBy == .memory ? "▼" : " "
        output += " PID   NAME                      CPU%\(cpuMark)    MEM\(memMark)     CATEGORY "
        output += TerminalUI.reset
        
        // Process rows
        for (index, process) in processes.prefix(9).enumerated() {
            output += TerminalUI.moveTo(18 + index, 3)
            let cpuColor = process.cpuUsage > 50 ? TerminalUI.red : process.cpuUsage > 20 ? TerminalUI.yellow : TerminalUI.green
            let memMB = Double(process.memoryBytes) / 1_048_576
            
            let pid = String(format: "%5d", process.id)
            let name = process.name.prefix(24).padding(toLength: 24, withPad: " ", startingAt: 0)
            let cpu = String(format: "%6.1f%%", process.cpuUsage)
            let mem = String(format: "%7.0f MB", memMB)
            let cat = process.category.rawValue.prefix(10)
            
            output += " \(pid)  \(name)  \(cpuColor)\(cpu)\(TerminalUI.reset)  \(mem)  \(TerminalUI.dim)\(cat)\(TerminalUI.reset)"
        }
        
        // === FOOTER ===
        output += TerminalUI.moveTo(28, 1)
        output += TerminalUI.dim
        output += " [q]Quit [c]CPU [m]Mem [n]Name [p]PID │ xExplain v\(Version.current)"
        output += TerminalUI.reset
        
        print(output, terminator: "")
        fflush(stdout)
    }
}

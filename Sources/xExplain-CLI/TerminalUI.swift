import Foundation
import xExplain

// MARK: - Terminal UI Components

struct TerminalUI {
    
    // ANSI Colors
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
    
    static let bgBlue = "\u{001B}[44m"
    static let bgGray = "\u{001B}[100m"
    
    // Clear and cursor control
    static let clearScreen = "\u{001B}[2J\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    static let saveCursor = "\u{001B}[s"
    static let restoreCursor = "\u{001B}[u"
    
    static func moveTo(_ row: Int, _ col: Int) -> String {
        return "\u{001B}[\(row);\(col)H"
    }
    
    static func clearLine() -> String {
        return "\u{001B}[2K"
    }
    
    // MARK: - Progress Bar
    
    static func progressBar(value: Double, width: Int = 30, filled: String = "█", empty: String = "░", color: String = green) -> String {
        let clampedValue = max(0, min(100, value))
        let filledCount = Int((clampedValue / 100.0) * Double(width))
        let emptyCount = width - filledCount
        
        let barColor: String
        if clampedValue > 80 {
            barColor = red
        } else if clampedValue > 60 {
            barColor = yellow
        } else {
            barColor = color
        }
        
        return barColor + String(repeating: filled, count: filledCount) + dim + String(repeating: empty, count: emptyCount) + reset
    }
    
    // MARK: - Gauge
    
    static func gauge(label: String, value: Double, unit: String = "%", width: Int = 25) -> String {
        let bar = progressBar(value: value, width: width)
        let valueStr = String(format: "%5.1f%@", value, unit)
        return "\(cyan)\(label.padding(toLength: 8, withPad: " ", startingAt: 0))\(reset)[\(bar)] \(bold)\(valueStr)\(reset)"
    }
    
    // MARK: - Box Drawing
    
    static func boxTop(width: Int, title: String = "") -> String {
        if title.isEmpty {
            return "╔" + String(repeating: "═", count: width - 2) + "╗"
        }
        let titleLen = title.count + 2
        let leftPad = (width - titleLen - 2) / 2
        let rightPad = width - titleLen - leftPad - 2
        return "╔" + String(repeating: "═", count: leftPad) + " \(bold)\(title)\(reset) " + String(repeating: "═", count: rightPad) + "╗"
    }
    
    static func boxBottom(width: Int) -> String {
        return "╚" + String(repeating: "═", count: width - 2) + "╝"
    }
    
    static func boxLine(content: String, width: Int) -> String {
        let visibleLen = content.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression).count
        let padding = max(0, width - visibleLen - 4)
        return "║ " + content + String(repeating: " ", count: padding) + " ║"
    }
    
    static func boxDivider(width: Int) -> String {
        return "╟" + String(repeating: "─", count: width - 2) + "╢"
    }
}

// MARK: - Terminal Monitor

class TerminalMonitor {
    let engine: ExplainEngine
    var interval: TimeInterval = 1.0
    var sortBy: SortColumn = .cpu
    var selectedRow: Int = 0
    var showHelp: Bool = false
    
    enum SortColumn {
        case cpu, memory, name, pid
    }
    
    init() {
        engine = ExplainEngine.shared
        engine.registerRules(for: .developer)
        engine.registerRules(for: .power)
    }
    
    func run() async {
        // Setup terminal
        print(TerminalUI.hideCursor, terminator: "")
        
        // Handle Ctrl+C
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
        let insights = engine.analyze(metrics: metrics, processes: processes)
        
        // Sort processes
        switch sortBy {
        case .cpu:
            processes.sort(by: { $0.cpuUsage > $1.cpuUsage })
        case .memory:
            processes.sort(by: { $0.memoryBytes > $1.memoryBytes })
        case .name:
            processes.sort(by: { $0.name < $1.name })
        case .pid:
            processes.sort(by: { $0.id < $1.id })
        }
        
        let width = 80
        var output = ""
        
        // Header
        output += TerminalUI.moveTo(1, 1)
        output += TerminalUI.bgBlue + TerminalUI.white + TerminalUI.bold
        output += " 🧠 xExplain Monitor ".padding(toLength: width, withPad: " ", startingAt: 0)
        output += TerminalUI.reset + "\n"
        
        // System gauges
        output += "\n"
        output += TerminalUI.gauge(label: "CPU", value: metrics.cpuUsage) + "\n"
        output += TerminalUI.gauge(label: "Memory", value: metrics.memoryUsagePercent) + "\n"
        output += TerminalUI.gauge(label: "GPU", value: metrics.gpuUsage) + "\n"
        
        // System info line
        let tempIcon = metrics.cpuTemperature > 80 ? "🔴" : metrics.cpuTemperature > 65 ? "🟡" : "🟢"
        output += "\n"
        output += "\(TerminalUI.cyan)Temp:\(TerminalUI.reset) \(tempIcon) \(String(format: "%.0f°C", metrics.cpuTemperature))  "
        output += "\(TerminalUI.cyan)Thermal:\(TerminalUI.reset) \(metrics.thermalState.rawValue)  "
        output += "\(TerminalUI.cyan)Disk:\(TerminalUI.reset) ↓\(String(format: "%.1f", metrics.diskReadRate)) ↑\(String(format: "%.1f", metrics.diskWriteRate)) MB/s\n"
        
        // Insights box
        if !insights.isEmpty {
            output += "\n"
            output += TerminalUI.boxTop(width: width, title: "⚠️ Insights")
            output += "\n"
            for insight in insights.prefix(3) {
                let icon = insight.severity == .critical ? "🔴" : insight.severity == .warning ? "⚠️" : "ℹ️"
                output += TerminalUI.boxLine(content: "\(icon) \(insight.symptom)", width: width)
                output += "\n"
            }
            output += TerminalUI.boxBottom(width: width)
            output += "\n"
        }
        
        // Process table header
        output += "\n"
        let cpuSort = sortBy == .cpu ? " ▼" : ""
        let memSort = sortBy == .memory ? " ▼" : ""
        output += TerminalUI.bgGray + TerminalUI.white
        output += "  PID   NAME                       CPU%\(cpuSort)      MEM\(memSort)    CATEGORY   "
        output += TerminalUI.reset + "\n"
        
        // Process list
        for (index, process) in processes.prefix(12).enumerated() {
            let cpuColor = process.cpuUsage > 50 ? TerminalUI.red : process.cpuUsage > 20 ? TerminalUI.yellow : TerminalUI.green
            let memMB = Double(process.memoryBytes) / 1_048_576
            
            if index == selectedRow {
                output += TerminalUI.bgGray
            }
            
            output += String(format: " %5d  ", process.id)
            output += process.name.prefix(25).padding(toLength: 25, withPad: " ", startingAt: 0)
            output += "  \(cpuColor)\(String(format: "%7.1f%%", process.cpuUsage))\(TerminalUI.reset)"
            output += String(format: "  %8.1f MB", memMB)
            output += "  \(TerminalUI.dim)\(process.category.rawValue.prefix(10))\(TerminalUI.reset)"
            
            if index == selectedRow {
                output += TerminalUI.reset
            }
            output += "\n"
        }
        
        // Footer
        output += "\n"
        output += TerminalUI.dim
        output += " [q] Quit  [c] Sort CPU  [m] Sort Mem  [n] Sort Name  [↑↓] Select  [k] Kill"
        output += TerminalUI.reset
        
        // Clear screen and print
        print(TerminalUI.clearScreen, terminator: "")
        print(output, terminator: "")
        fflush(stdout)
    }
}

# xExplain

> 🧠 System Intelligence Library for macOS - The "System Brain"

**xExplain** is a Swift Package that provides intelligent system analysis with **counterfactual reasoning**. It's the shared core for the xInsight ecosystem (xInsight, xInsight Dev, xThermal).

## Key Features

- **Counterfactual Analysis**: "What if I quit this app?" → "CPU will drop by 31%"
- **Confidence Scoring**: Know how reliable each insight is (0.0 - 1.0)
- **Audience Targeting**: Consumer, Developer, Power User insights
- **Thermal Forecasting**: Predict when throttling will occur
- **11 Built-in Rules**: CPU, Memory, I/O, Thermal, Dev Loop, Core Imbalance, ML Workload, etc.

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/xdev-asia/xExplain.git", from: "1.0.0")
]
```

## Quick Start

```swift
import xExplain

// Get the engine
let engine = ExplainEngine.shared

// Register developer rules (optional)
engine.registerRules(for: .developer)

// Analyze system state
let insights = engine.analyze(
    metrics: myNormalizedMetrics,
    processes: myProcessSnapshots
)

// Quick queries
if let cpuInsight = engine.whyCPU(metrics: m, processes: p) {
    print(cpuInsight.explanation)
    if let cf = cpuInsight.counterfactual {
        print("If you \(cf.action): \(cf.expectedOutcome)")
    }
}

// Thermal forecast
if let forecast = engine.thermalForecast(currentMetrics: metrics) {
    if forecast.willThrottle {
        print("Throttle in ~\(forecast.estimatedMinutes!) minutes")
    }
}
```

## Architecture

```
xExplain/
├── Core/
│   ├── ExplainEngine.swift        # Main analysis engine
│   ├── CorrelationEngine.swift    # Metric-process correlations
│   ├── AnomalyDetector.swift      # Statistical anomaly detection
│   ├── CounterfactualAnalyzer.swift # "What if" analysis
│   └── ConfidenceScorer.swift     # Confidence adjustment
├── Models/
│   ├── ExplainInsight.swift       # Core insight model
│   └── SystemModels.swift         # Metrics & process models
└── Rules/
    ├── RuleProtocol.swift
    ├── Consumer/                   # Basic insights
    ├── Developer/                  # Dev-focused insights
    └── Thermal/                    # Power user insights
```

## Built-in Rules

### Consumer (Always Active)
| Rule | Trigger | Description |
|------|---------|-------------|
| CPU Saturation | CPU > 80% | Identifies top CPU consumers |
| Memory Pressure | Memory pressure != normal | Finds memory hogs |
| I/O Bottleneck | Disk I/O > 100 MB/s | Explains high disk activity |
| Thermal Throttling | Thermal state serious/critical | Explains overheating |

### Developer (Register with `.developer`)
| Rule | Trigger | Description |
|------|---------|-------------|
| Core Imbalance | P-cores idle, E-cores busy | Single-thread bottleneck |
| Dev Loop | CPU spikes + dev tools | Hot reload loop detected |
| I/O Amplification | Reads >> Writes | File watcher overhead |
| ML Workload | High CPU + no Metal/ANE | AI fallback to CPU |

### Power User (Register with `.power`)
| Rule | Trigger | Description |
|------|---------|-------------|
| Silent Throttle | Frequency reduced | Apple's hidden throttling |
| Energy Inefficiency | Many low-CPU wake-ups | Battery drain pattern |
| Thermal Forecast | Rising temperature trend | Predict throttling time |

## Counterfactual Analysis

The key differentiator of xExplain:

```swift
struct ExplainInsight {
    let symptom: String           // "High CPU"
    let rootCause: String         // "Docker using 70%"
    let explanation: String       // Human-readable
    let confidence: Double        // 0.0 - 1.0
    let counterfactual: Counterfactual? // 👈 Key!
}

struct Counterfactual {
    let action: String            // "Quit Docker"
    let expectedOutcome: String   // "CPU will drop to ~30%"
    let quantifiedImpact: String? // "-40%"
    let confidence: Double        // 0.85
    let timeToEffect: TimeInterval? // 2.0 seconds
}
```

## License

MIT License - © 2026 xdev.asia

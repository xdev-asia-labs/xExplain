// xExplain - System Intelligence Library for macOS
// Copyright © 2026 xdev.asia. All rights reserved.

/// xExplain is the "System Brain" for macOS applications.
/// It provides intelligent system analysis with counterfactual reasoning.
///
/// ## Quick Start
/// ```swift
/// import xExplain
///
/// // Analyze system state
/// let insights = ExplainEngine.shared.analyze(
///     metrics: myMetrics,
///     processes: myProcesses
/// )
///
/// // Quick queries
/// let cpuInsight = ExplainEngine.shared.whyCPU(metrics: m, processes: p)
/// let thermalForecast = ExplainEngine.shared.thermalForecast(currentMetrics: m)
/// ```
///
/// ## Features
/// - **Counterfactual Analysis**: "What if I quit this app?"
/// - **Confidence Scoring**: Know how reliable each insight is
/// - **Audience Targeting**: Consumer, Developer, Power User insights
/// - **Thermal Forecasting**: Predict when throttling will occur

// MARK: - Core Engine
@_exported import Foundation

// Re-export all public types
public typealias Insight = ExplainInsight
public typealias InsightType = ExplainInsightType
public typealias Severity = ExplainSeverity
public typealias Action = ExplainAction
public typealias ActionType = ExplainActionType

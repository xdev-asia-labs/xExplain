import XCTest
@testable import xExplain

final class xExplainTests: XCTestCase {
    
    // MARK: - ExplainEngine Tests
    
    func testEngineInitialization() {
        let engine = ExplainEngine.shared
        XCTAssertNotNil(engine)
    }
    
    func testAnalyzeWithNormalMetrics() {
        let engine = ExplainEngine.shared
        let metrics = NormalizedMetrics(
            cpuUsage: 30,
            memoryUsagePercent: 50,
            memoryPressure: .normal,
            thermalState: .nominal
        )
        
        let insights = engine.analyze(metrics: metrics, processes: [])
        // Normal metrics should produce no critical insights
        XCTAssertTrue(insights.filter { $0.severity == .critical }.isEmpty)
    }
    
    func testAnalyzeWithHighCPU() {
        let engine = ExplainEngine.shared
        let metrics = NormalizedMetrics(
            cpuUsage: 95,
            memoryUsagePercent: 50,
            memoryPressure: .normal,
            thermalState: .nominal
        )
        
        let process = ProcessSnapshot(
            pid: 1234,
            name: "TestApp",
            cpuUsage: 80,
            memoryBytes: 1_000_000_000,
            category: .other
        )
        
        let insights = engine.analyze(metrics: metrics, processes: [process])
        
        // Should detect CPU saturation
        XCTAssertTrue(insights.contains { $0.type == .cpuSaturation })
    }
    
    // MARK: - Counterfactual Tests
    
    func testCounterfactualGeneration() {
        let analyzer = CounterfactualAnalyzer()
        let metrics = NormalizedMetrics(cpuUsage: 90)
        let process = ProcessSnapshot(
            pid: 1234,
            name: "HeavyApp",
            cpuUsage: 70
        )
        
        let insight = ExplainInsight(
            symptom: "High CPU",
            rootCause: "HeavyApp using 70%",
            explanation: "Test",
            confidence: 0.8,
            type: .cpuSaturation,
            severity: .warning
        )
        
        let enhanced = analyzer.enhance(
            insight: insight,
            metrics: metrics,
            processes: [process]
        )
        
        XCTAssertNotNil(enhanced.counterfactual)
    }
    
    // MARK: - Rule Tests
    
    func testCPUSaturationRule() {
        let rule = CPUSaturationRule()
        
        let highCPUMetrics = NormalizedMetrics(cpuUsage: 90)
        let process = ProcessSnapshot(pid: 1, name: "Test", cpuUsage: 75)
        let context = EvaluationContext()
        
        let insight = rule.evaluate(
            metrics: highCPUMetrics,
            processes: [process],
            context: context
        )
        
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.type, .cpuSaturation)
    }
    
    func testMemoryPressureRule() {
        let rule = MemoryPressureRule()
        
        let metrics = NormalizedMetrics(
            memoryUsagePercent: 90,
            memoryUsedBytes: 14_000_000_000,
            memoryTotalBytes: 16_000_000_000,
            memoryPressure: .warning
        )
        let process = ProcessSnapshot(
            pid: 1,
            name: "MemoryHog",
            memoryBytes: 8_000_000_000
        )
        let context = EvaluationContext()
        
        let insight = rule.evaluate(
            metrics: metrics,
            processes: [process],
            context: context
        )
        
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.type, .memoryPressure)
    }
    
    func testThermalForecastRule() {
        let rule = ThermalForecastRule()
        
        // Create rising temperature history
        var history: [NormalizedMetrics] = []
        for i in 0..<15 {
            history.append(NormalizedMetrics(
                cpuTemperature: 70 + Double(i) * 1.5,
                thermalState: .fair
            ))
        }
        
        let currentMetrics = NormalizedMetrics(
            cpuTemperature: 82,
            thermalState: .fair
        )
        
        let context = EvaluationContext(metricsHistory: history)
        
        let insight = rule.evaluate(
            metrics: currentMetrics,
            processes: [],
            context: context
        )
        
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.type, .thermalForecast)
    }
    
    // MARK: - Anomaly Detection Tests
    
    func testAnomalyDetection() {
        let detector = AnomalyDetector()
        
        // Normal history
        var history: [NormalizedMetrics] = []
        for _ in 0..<20 {
            history.append(NormalizedMetrics(cpuUsage: 30 + Double.random(in: -5...5)))
        }
        
        // Anomalous current value
        let current = NormalizedMetrics(cpuUsage: 95)
        
        let anomalies = detector.detect(current: current, history: history)
        
        XCTAssertFalse(anomalies.isEmpty)
        XCTAssertTrue(anomalies.contains { $0.metric == "CPU Usage" })
    }
    
    // MARK: - Model Tests
    
    func testExplainInsightCreation() {
        let insight = ExplainInsight(
            symptom: "Test symptom",
            rootCause: "Test cause",
            explanation: "Test explanation",
            confidence: 0.9,
            type: .cpuSaturation,
            severity: .warning
        )
        
        XCTAssertEqual(insight.symptom, "Test symptom")
        XCTAssertEqual(insight.confidence, 0.9)
        XCTAssertEqual(insight.type, .cpuSaturation)
    }
    
    func testCounterfactualCreation() {
        let counterfactual = Counterfactual(
            action: "Quit app",
            expectedOutcome: "CPU will drop",
            quantifiedImpact: "-50%",
            confidence: 0.85,
            timeToEffect: 2.0
        )
        
        XCTAssertEqual(counterfactual.action, "Quit app")
        XCTAssertEqual(counterfactual.quantifiedImpact, "-50%")
    }
}

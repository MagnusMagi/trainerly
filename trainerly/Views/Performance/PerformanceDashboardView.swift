import SwiftUI
import Combine

// MARK: - Performance Dashboard View
struct PerformanceDashboardView: View {
    @StateObject private var viewModel = PerformanceDashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingPerformanceReport = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    appPerformanceTab.tag(0)
                    mlPerformanceTab.tag(1)
                    memoryUsageTab.tag(2)
                    networkPerformanceTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: HStack {
                refreshButton
                reportButton
            })
            .onAppear {
                viewModel.startMonitoring()
            }
            .onDisappear {
                viewModel.stopMonitoring()
            }
            .sheet(isPresented: $showingPerformanceReport) {
                PerformanceReportView(report: viewModel.performanceReport)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Performance Overview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance Monitor")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Real-time app performance & ML optimization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isMonitoring ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isMonitoring ? "Monitoring" : "Stopped")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Performance Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                PerformanceStatCard(
                    title: "Frame Rate",
                    value: "\(Int(viewModel.currentPerformance.frameRate)) FPS",
                    icon: "speedometer",
                    color: viewModel.currentPerformance.frameRate >= 55 ? .green : .orange,
                    trend: .stable
                )
                PerformanceStatCard(
                    title: "CPU Usage",
                    value: "\(Int(viewModel.currentPerformance.cpuUsage * 100))%",
                    icon: "cpu",
                    color: viewModel.currentPerformance.cpuUsage <= 0.3 ? .green : .orange,
                    trend: .stable
                )
                PerformanceStatCard(
                    title: "Memory",
                    value: "\(Int(viewModel.currentPerformance.memoryUsage * 100))%",
                    icon: "memorychip",
                    color: viewModel.currentPerformance.memoryUsage <= 0.6 ? .green : .orange,
                    trend: .stable
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Tab Selection
    private var tabSelection: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { index in
                Button(action: {
                    selectedTab = index
                }) {
                    VStack(spacing: 4) {
                        Text(tabTitle(for: index))
                            .font(.caption)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                            .foregroundColor(selectedTab == index ? .trainerlyPrimary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == index ? Color.trainerlyPrimary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Tab Views
    private var appPerformanceTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // App Performance Overview
                AppPerformanceOverviewCard(performance: viewModel.currentPerformance)
                
                // Performance Metrics
                PerformanceMetricsCard(performance: viewModel.currentPerformance)
                
                // Performance Recommendations
                if !viewModel.appPerformanceRecommendations.isEmpty {
                    PerformanceRecommendationsCard(recommendations: viewModel.appPerformanceRecommendations)
                }
            }
            .padding()
        }
    }
    
    private var mlPerformanceTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // ML Performance Overview
                MLPerformanceOverviewCard(performance: viewModel.mlPerformance)
                
                // ML Metrics
                MLMetricsCard(performance: viewModel.mlPerformance)
                
                // ML Optimization
                MLOptimizationCard(viewModel: viewModel)
                
                // ML Recommendations
                if !viewModel.mlPerformanceRecommendations.isEmpty {
                    PerformanceRecommendationsCard(recommendations: viewModel.mlPerformanceRecommendations)
                }
            }
            .padding()
        }
    }
    
    private var memoryUsageTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Memory Usage Overview
                MemoryUsageOverviewCard(metrics: viewModel.memoryMetrics)
                
                // Memory Optimization
                MemoryOptimizationCard(viewModel: viewModel)
                
                // Memory Recommendations
                if !viewModel.memoryRecommendations.isEmpty {
                    PerformanceRecommendationsCard(recommendations: viewModel.memoryRecommendations)
                }
            }
            .padding()
        }
    }
    
    private var networkPerformanceTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Network Performance Overview
                NetworkPerformanceOverviewCard(metrics: viewModel.networkMetrics)
                
                // Network Optimization
                NetworkOptimizationCard(viewModel: viewModel)
                
                // Network Recommendations
                if !viewModel.networkRecommendations.isEmpty {
                    PerformanceRecommendationsCard(recommendations: viewModel.networkRecommendations)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Buttons
    private var refreshButton: some View {
        Button(action: {
            viewModel.refreshData()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(viewModel.isLoading)
    }
    
    private var reportButton: some View {
        Button(action: {
            showingPerformanceReport = true
        }) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title3)
        }
    }
    
    // MARK: - Helper Methods
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "App"
        case 1: return "ML"
        case 2: return "Memory"
        case 3: return "Network"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct PerformanceStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                TrendIndicator(trend: trend)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AppPerformanceOverviewCard: View {
    let performance: AppPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Performance Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricRow(title: "Frame Rate", value: "\(Int(performance.frameRate)) FPS", color: performance.frameRate >= 55 ? .green : .orange)
                PerformanceMetricRow(title: "CPU Usage", value: "\(Int(performance.cpuUsage * 100))%", color: performance.cpuUsage <= 0.3 ? .green : .orange)
                PerformanceMetricRow(title: "Battery Usage", value: "\(Int(performance.batteryUsage * 100))%", color: performance.batteryUsage <= 0.1 ? .green : .orange)
                PerformanceMetricRow(title: "Memory Usage", value: "\(Int(performance.memoryUsage * 100))%", color: performance.memoryUsage <= 0.6 ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceMetricRow: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

struct PerformanceMetricsCard: View {
    let performance: AppPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                MetricProgressRow(title: "Frame Rate", value: performance.frameRate, maxValue: 60, color: .green)
                MetricProgressRow(title: "CPU Usage", value: performance.cpuUsage, maxValue: 1.0, color: .blue)
                MetricProgressRow(title: "Memory Usage", value: performance.memoryUsage, maxValue: 1.0, color: .purple)
                MetricProgressRow(title: "Response Time", value: performance.responseTime, maxValue: 0.1, color: .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MetricProgressRow: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                ProgressView(value: value, total: maxValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 60)
                
                Text("\(Int((value / maxValue) * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MLPerformanceOverviewCard: View {
    let performance: MLPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML Performance Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricRow(title: "Inference Time", value: String(format: "%.2fs", performance.averageInferenceTime), color: performance.averageInferenceTime <= 0.2 ? .green : .orange)
                PerformanceMetricRow(title: "Accuracy", value: "\(Int(performance.accuracy * 100))%", color: performance.accuracy >= 0.8 ? .green : .orange)
                PerformanceMetricRow(title: "Efficiency", value: "\(Int(performance.modelEfficiency * 100))%", color: performance.modelEfficiency >= 0.9 ? .green : .orange)
                PerformanceMetricRow(title: "Active Models", value: "\(performance.activeModels)", color: .blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MLMetricsCard: View {
    let performance: MLPerformance
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                MetricProgressRow(title: "Inference Time", value: performance.averageInferenceTime, maxValue: 0.2, color: .green)
                MetricProgressRow(title: "Accuracy", value: performance.accuracy, maxValue: 1.0, color: .blue)
                MetricProgressRow(title: "Efficiency", value: performance.modelEfficiency, maxValue: 1.0, color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MLOptimizationCard: View {
    @ObservedObject var viewModel: PerformanceDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML Optimization")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                Task {
                    try? await viewModel.optimizeMLInference()
                }
            }) {
                HStack {
                    Image(systemName: "cpu")
                    Text("Optimize ML Inference")
                    Spacer()
                    if viewModel.isOptimizingML {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
            }
            .disabled(viewModel.isOptimizingML)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct MemoryUsageOverviewCard: View {
    let metrics: MemoryMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Usage Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricRow(title: "Total Usage", value: "\(Int(metrics.totalUsage * 100))%", color: metrics.totalUsage <= 0.7 ? .green : .orange)
                PerformanceMetricRow(title: "Available", value: "\(Int(metrics.availableMemory * 100))%", color: .blue)
                PerformanceMetricRow(title: "Cache Size", value: "\(Int(metrics.cacheSize * 100))%", color: metrics.cacheSize <= 0.2 ? .green : .orange)
                PerformanceMetricRow(title: "Pressure", value: metrics.memoryPressure.rawValue, color: memoryPressureColor(metrics.memoryPressure))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func memoryPressureColor(_ pressure: MemoryPressure) -> Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

struct MemoryOptimizationCard: View {
    @ObservedObject var viewModel: PerformanceDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Optimization")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                Task {
                    try? await viewModel.optimizeMemoryUsage()
                }
            }) {
                HStack {
                    Image(systemName: "memorychip")
                    Text("Optimize Memory Usage")
                    Spacer()
                    if viewModel.isOptimizingMemory {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .foregroundColor(.purple)
                .cornerRadius(8)
            }
            .disabled(viewModel.isOptimizingMemory)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct NetworkPerformanceOverviewCard: View {
    let metrics: NetworkMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Performance Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricRow(title: "Response Time", value: String(format: "%.2fs", metrics.averageResponseTime), color: metrics.averageResponseTime <= 0.5 ? .green : .orange)
                PerformanceMetricRow(title: "Error Rate", value: "\(Int(metrics.errorRate * 100))%", color: metrics.errorRate <= 0.05 ? .green : .orange)
                PerformanceMetricRow(title: "Cache Hit Rate", value: "\(Int(metrics.cacheHitRate * 100))%", color: metrics.cacheHitRate >= 0.7 ? .green : .orange)
                PerformanceMetricRow(title: "Requests", value: "\(metrics.requestCount)", color: .blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct NetworkOptimizationCard: View {
    @ObservedObject var viewModel: PerformanceDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Optimization")
                .font(.headline)
                .foregroundColor(.primary)
            
            Button(action: {
                Task {
                    try? await viewModel.optimizeNetworkRequests()
                }
            }) {
                HStack {
                    Image(systemName: "network")
                    Text("Optimize Network")
                    Spacer()
                    if viewModel.isOptimizingNetwork {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .foregroundColor(.orange)
                .cornerRadius(8)
            }
            .disabled(viewModel.isOptimizingNetwork)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceRecommendationsCard: View {
    let recommendations: [PerformanceRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Recommendations")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(recommendations, id: \.id) { recommendation in
                PerformanceRecommendationRow(recommendation: recommendation)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceRecommendationRow: View {
    let recommendation: PerformanceRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                PriorityBadge(priority: recommendation.priority)
            }
            
            Text(recommendation.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(recommendation.category.rawValue)
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
final class PerformanceDashboardViewModel: ObservableObject {
    @Published var isMonitoring: Bool = false
    @Published var currentPerformance: AppPerformance = AppPerformance()
    @Published var mlPerformance: MLPerformance = MLPerformance()
    @Published var memoryMetrics: MemoryMetrics = MemoryMetrics()
    @Published var networkMetrics: NetworkMetrics = NetworkMetrics()
    @Published var performanceReport: PerformanceReport?
    @Published var isLoading: Bool = false
    @Published var isOptimizingML: Bool = false
    @Published var isOptimizingMemory: Bool = false
    @Published var isOptimizingNetwork: Bool = false
    
    // Performance recommendations
    @Published var appPerformanceRecommendations: [PerformanceRecommendation] = []
    @Published var mlPerformanceRecommendations: [PerformanceRecommendation] = []
    @Published var memoryRecommendations: [PerformanceRecommendation] = []
    @Published var networkRecommendations: [PerformanceRecommendation] = []
    
    private let performanceService: PerformanceOptimizationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(performanceService: PerformanceOptimizationServiceProtocol = DependencyContainer.shared.performanceOptimizationService) {
        self.performanceService = performanceService
        
        // Subscribe to performance updates
        performanceService.$currentPerformance
            .assign(to: \.currentPerformance, on: self)
            .store(in: &cancellables)
        
        performanceService.$mlPerformance
            .assign(to: \.mlPerformance, on: self)
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        Task {
            try? await performanceService.startPerformanceMonitoring()
        }
    }
    
    func stopMonitoring() {
        performanceService.stopPerformanceMonitoring()
    }
    
    func refreshData() {
        Task {
            try? await generatePerformanceReport()
        }
    }
    
    func optimizeMLInference() async throws {
        isOptimizingML = true
        defer { isOptimizingML = false }
        
        let optimization = try await performanceService.optimizeMLInference()
        
        // Update recommendations
        await MainActor.run {
            mlPerformanceRecommendations = optimization.expectedImprovements.map { improvement in
                PerformanceRecommendation(
                    id: UUID().uuidString,
                    title: "ML Optimization Applied",
                    description: improvement,
                    priority: .medium,
                    category: .mlPerformance
                )
            }
        }
    }
    
    func optimizeMemoryUsage() async throws {
        isOptimizingMemory = true
        defer { isOptimizingMemory = false }
        
        let optimization = try await performanceService.optimizeMemoryUsage()
        
        // Update recommendations
        await MainActor.run {
            memoryRecommendations = optimization.expectedImprovements.map { improvement in
                PerformanceRecommendation(
                    id: UUID().uuidString,
                    title: "Memory Optimization Applied",
                    description: improvement,
                    priority: .medium,
                    category: .memoryUsage
                )
            }
        }
    }
    
    func optimizeNetworkRequests() async throws {
        isOptimizingNetwork = true
        defer { isOptimizingNetwork = false }
        
        let optimization = try await performanceService.optimizeNetworkRequests()
        
        // Update recommendations
        await MainActor.run {
            networkRecommendations = optimization.expectedImprovements.map { improvement in
                PerformanceRecommendation(
                    id: UUID().uuidString,
                    title: "Network Optimization Applied",
                    description: improvement,
                    priority: .medium,
                    category: .networkPerformance
                )
            }
        }
    }
    
    private func generatePerformanceReport() async throws {
        let report = try await performanceService.generatePerformanceReport()
        
        await MainActor.run {
            performanceReport = report
            
            // Update recommendations
            appPerformanceRecommendations = report.recommendations.filter { $0.category == .appPerformance }
            mlPerformanceRecommendations = report.recommendations.filter { $0.category == .mlPerformance }
            memoryRecommendations = report.recommendations.filter { $0.category == .memoryUsage }
            networkRecommendations = report.recommendations.filter { $0.category == .networkPerformance }
        }
    }
}

// MARK: - Supporting Types

struct PerformanceReportView: View {
    let report: PerformanceReport?
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let report = report {
                    VStack(spacing: 16) {
                        Text("Performance Report")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding()
                        
                        // Report content would go here
                        Text("Generated: \(report.timestamp, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    Text("No performance report available")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceDashboardView()
    }
}

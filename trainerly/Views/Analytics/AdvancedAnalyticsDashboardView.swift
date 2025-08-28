import SwiftUI
import Combine

// MARK: - Advanced Analytics Dashboard View
struct AdvancedAnalyticsDashboardView: View {
    @StateObject private var viewModel = AdvancedAnalyticsDashboardViewModel()
    @State private var selectedTab = 0
    @State private var selectedPeriod: AnalyticsPeriod = .month
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                periodSelector
                tabSelection
                TabView(selection: $selectedTab) {
                    predictionsTab.tag(0)
                    correlationsTab.tag(1)
                    insightsTab.tag(2)
                    trendsTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Advanced Analytics")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: refreshButton)
            .onAppear {
                viewModel.loadData(period: selectedPeriod)
            }
            .onChange(of: selectedPeriod) { newPeriod in
                viewModel.loadData(period: newPeriod)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // AI Insights Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI-Powered Insights")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("ML-driven performance analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.trainerlyPrimary)
            }
            .padding(.horizontal)
            
            // Quick Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                StatCard(
                    title: "Prediction Accuracy",
                    value: "\(Int(viewModel.predictionAccuracy * 100))%",
                    icon: "target",
                    color: .green
                )
                StatCard(
                    title: "Data Points",
                    value: "\(viewModel.dataPoints)",
                    icon: "chart.bar.fill",
                    color: .blue
                )
                StatCard(
                    title: "ML Models",
                    value: "\(viewModel.activeModels)",
                    icon: "cpu",
                    color: .purple
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack {
            Text("Analysis Period:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Picker("Period", selection: $selectedPeriod) {
                Text("Week").tag(AnalyticsPeriod.week)
                Text("Month").tag(AnalyticsPeriod.month)
                Text("Quarter").tag(AnalyticsPeriod.quarter)
                Text("Year").tag(AnalyticsPeriod.year)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 300)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
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
    private var predictionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance Predictions
                PredictionSection(
                    title: "Workout Performance",
                    predictions: viewModel.workoutPredictions,
                    isLoading: viewModel.isLoading
                )
                
                // Goal Achievement Predictions
                PredictionSection(
                    title: "Goal Achievement",
                    predictions: viewModel.goalPredictions,
                    isLoading: viewModel.isLoading
                )
                
                // Recovery Predictions
                PredictionSection(
                    title: "Recovery Optimization",
                    predictions: viewModel.recoveryPredictions,
                    isLoading: viewModel.isLoading
                )
            }
            .padding()
        }
    }
    
    private var correlationsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Sleep Performance Correlation
                CorrelationSection(
                    title: "Sleep & Performance",
                    correlation: viewModel.sleepPerformanceCorrelation,
                    isLoading: viewModel.isLoading
                )
                
                // Nutrition Recovery Correlation
                CorrelationSection(
                    title: "Nutrition & Recovery",
                    correlation: viewModel.nutritionRecoveryCorrelation,
                    isLoading: viewModel.isLoading
                )
                
                // Stress Performance Correlation
                CorrelationSection(
                    title: "Stress & Performance",
                    correlation: viewModel.stressPerformanceCorrelation,
                    isLoading: viewModel.isLoading
                )
            }
            .padding()
        }
    }
    
    private var insightsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // AI-Generated Insights
                ForEach(viewModel.aiInsights, id: \.id) { insight in
                    InsightCard(insight: insight)
                }
                
                if viewModel.aiInsights.isEmpty && !viewModel.isLoading {
                    EmptyStateView(
                        icon: "lightbulb",
                        title: "No Insights Yet",
                        description: "Complete more workouts to generate AI-powered insights"
                    )
                }
            }
            .padding()
        }
    }
    
    private var trendsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance Trends
                TrendSection(
                    title: "Performance Trends",
                    trends: viewModel.performanceTrends,
                    isLoading: viewModel.isLoading
                )
                
                // Health Trends
                TrendSection(
                    title: "Health Trends",
                    trends: viewModel.healthTrends,
                    isLoading: viewModel.isLoading
                )
                
                // Recovery Trends
                TrendSection(
                    title: "Recovery Trends",
                    trends: viewModel.recoveryTrends,
                    isLoading: viewModel.isLoading
                )
            }
            .padding()
        }
    }
    
    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: {
            viewModel.loadData(period: selectedPeriod)
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Predictions"
        case 1: return "Correlations"
        case 2: return "Insights"
        case 3: return "Trends"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
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

struct PredictionSection: View {
    let title: String
    let predictions: [Any]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if predictions.isEmpty {
                EmptyStateView(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No Predictions",
                    description: "Complete more workouts to generate predictions"
                )
            } else {
                ForEach(0..<min(predictions.count, 3), id: \.self) { index in
                    PredictionCard(prediction: predictions[index])
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct CorrelationSection: View {
    let title: String
    let correlation: Any?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing correlations...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if correlation == nil {
                EmptyStateView(
                    icon: "chart.bar.xaxis",
                    title: "No Correlations",
                    description: "Insufficient data for correlation analysis"
                )
            } else {
                CorrelationCard(correlation: correlation!)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct InsightCard: View {
    let insight: PersonalizedInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: insight.type))
                    .font(.title2)
                    .foregroundColor(color(for: insight.priority))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(insight.type.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                PriorityBadge(priority: insight.priority)
            }
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.primary)
            
            if insight.actionable, let action = insight.action {
                Button(action: {
                    // Handle action
                }) {
                    Text(action)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.trainerlyPrimary)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func iconName(for type: InsightType) -> String {
        switch type {
        case .performance: return "chart.line.uptrend.xyaxis"
        case .health: return "heart.fill"
        case .recovery: return "bed.double.fill"
        case .goal: return "target"
        }
    }
    
    private func color(for priority: InsightPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct TrendSection: View {
    let title: String
    let trends: [Any]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing trends...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if trends.isEmpty {
                EmptyStateView(
                    icon: "chart.xyaxis.line",
                    title: "No Trends",
                    description: "Complete more workouts to identify trends"
                )
            } else {
                ForEach(0..<min(trends.count, 3), id: \.self) { index in
                    TrendCard(trend: trends[index])
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct PredictionCard: View {
    let prediction: Any
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prediction Card")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("This would display prediction details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct CorrelationCard: View {
    let correlation: Any
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Correlation Card")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("This would display correlation details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct TrendCard: View {
    let trend: Any
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend Card")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("This would display trend details")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct PriorityBadge: View {
    let priority: InsightPriority
    
    var body: some View {
        Text(priority.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .blue
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - View Model

@MainActor
final class AdvancedAnalyticsDashboardViewModel: ObservableObject {
    @Published var predictionAccuracy: Double = 0.0
    @Published var dataPoints: Int = 0
    @Published var activeModels: Int = 0
    @Published var workoutPredictions: [Any] = []
    @Published var goalPredictions: [Any] = []
    @Published var recoveryPredictions: [Any] = []
    @Published var sleepPerformanceCorrelation: Any?
    @Published var nutritionRecoveryCorrelation: Any?
    @Published var stressPerformanceCorrelation: Any?
    @Published var aiInsights: [PersonalizedInsight] = []
    @Published var performanceTrends: [Any] = []
    @Published var healthTrends: [Any] = []
    @Published var recoveryTrends: [Any] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let analyticsEngine: AnalyticsEngineProtocol
    private let predictionService: PredictionServiceProtocol
    private let correlationService: CorrelationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        analyticsEngine: AnalyticsEngineProtocol = DependencyContainer.shared.analyticsEngine,
        predictionService: PredictionServiceProtocol = DependencyContainer.shared.predictionService,
        correlationService: CorrelationServiceProtocol = DependencyContainer.shared.correlationService
    ) {
        self.analyticsEngine = analyticsEngine
        self.predictionService = predictionService
        self.correlationService = correlationService
        
        setupBindings()
    }
    
    func loadData(period: AnalyticsPeriod) {
        isLoading = true
        
        Task {
            do {
                // Load analytics data
                try await loadAnalyticsData(period: period)
                
                // Load predictions
                try await loadPredictions(period: period)
                
                // Load correlations
                try await loadCorrelations(period: period)
                
                // Load insights
                try await loadInsights(period: period)
                
                // Load trends
                try await loadTrends(period: period)
                
                // Update summary stats
                updateSummaryStats()
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func setupBindings() {
        // Setup bindings for real-time updates
    }
    
    private func loadAnalyticsData(period: AnalyticsPeriod) async throws {
        // Load analytics data for the specified period
    }
    
    private func loadPredictions(period: AnalyticsPeriod) async throws {
        // Load predictions for the specified period
    }
    
    private func loadCorrelations(period: AnalyticsPeriod) async throws {
        // Load correlations for the specified period
    }
    
    private func loadInsights(period: AnalyticsPeriod) async throws {
        // Load AI-generated insights for the specified period
    }
    
    private func loadTrends(period: AnalyticsPeriod) async throws {
        // Load trends for the specified period
    }
    
    private func updateSummaryStats() {
        // Update summary statistics
        predictionAccuracy = 0.87
        dataPoints = 1247
        activeModels = 5
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Dependency Container Extension

extension DependencyContainer {
    static var shared: DependencyContainer {
        MainDependencyContainer()
    }
}

// MARK: - Preview

struct AdvancedAnalyticsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedAnalyticsDashboardView()
    }
}

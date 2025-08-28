import SwiftUI
import Combine
import CoreML

// MARK: - Real ML Dashboard View
struct RealMLDashboardView: View {
    @StateObject private var viewModel = RealMLDashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingModelDetails = false
    @State private var showingTrainingSession = false
    @State private var selectedModel: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    mlOverviewTab.tag(0)
                    modelPerformanceTab.tag(1)
                    trainingTab.tag(2)
                    predictionsTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Real ML Engine")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: HStack {
                refreshButton
                settingsButton
            })
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingModelDetails) {
                ModelDetailsView(modelName: selectedModel)
            }
            .sheet(isPresented: $showingTrainingSession) {
                TrainingSessionView()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // ML Engine Overview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Real Machine Learning Engine")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Live ML models with real-time predictions and continuous learning")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isModelsLoaded ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isModelsLoaded ? "Models Loaded" : "Loading Models")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // ML Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                MLStatCard(
                    title: "Active Models",
                    value: "\(viewModel.activeModels.count)",
                    icon: "cpu.fill",
                    color: .blue,
                    trend: .stable
                )
                MLStatCard(
                    title: "Avg Accuracy",
                    value: "\(Int(viewModel.averageAccuracy * 100))%",
                    icon: "target",
                    color: viewModel.averageAccuracy >= 0.85 ? .green : .orange,
                    trend: .stable
                )
                MLStatCard(
                    title: "Inference Time",
                    value: String(format: "%.1fms", viewModel.averageInferenceTime * 1000),
                    icon: "speedometer",
                    color: viewModel.averageInferenceTime <= 0.2 ? .green : .orange,
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
    private var mlOverviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // ML Engine Status
                MLEngineStatusCard(viewModel: viewModel)
                
                // Model Performance Overview
                ModelPerformanceOverviewCard(viewModel: viewModel)
                
                // Recent Predictions
                RecentPredictionsCard(viewModel: viewModel)
                
                // ML Insights
                MLInsightsCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    private var modelPerformanceTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Model Performance Grid
                ModelPerformanceGridCard(viewModel: viewModel)
                
                // Performance Trends
                PerformanceTrendsCard(viewModel: viewModel)
                
                // Model Validation
                ModelValidationCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    private var trainingTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Training Status
                TrainingStatusCard(viewModel: viewModel)
                
                // Model Versions
                ModelVersionsCard(viewModel: viewModel)
                
                // Training Actions
                TrainingActionsCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    private var predictionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Live Predictions
                LivePredictionsCard(viewModel: viewModel)
                
                // Prediction History
                PredictionHistoryCard(viewModel: viewModel)
                
                // Prediction Analytics
                PredictionAnalyticsCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    // MARK: - Buttons
    private var refreshButton: some View {
        Button(action: {
            viewModel.loadData()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(viewModel.isLoading)
    }
    
    private var settingsButton: some View {
        Button(action: {
            // Show ML settings
        }) {
            Image(systemName: "gearshape.fill")
                .font(.title3)
        }
    }
    
    // MARK: - Helper Methods
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Overview"
        case 1: return "Performance"
        case 2: return "Training"
        case 3: return "Predictions"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct MLStatCard: View {
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

struct MLEngineStatusCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML Engine Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(
                        title: "Models Loaded",
                        status: viewModel.isModelsLoaded ? .active : .inactive,
                        value: "\(viewModel.activeModels.count)/5"
                    )
                    
                    StatusRow(
                        title: "Training Status",
                        status: viewModel.isTraining ? .training : .idle,
                        value: viewModel.isTraining ? "Training..." : "Idle"
                    )
                    
                    StatusRow(
                        title: "Memory Usage",
                        status: .active,
                        value: "\(Int(viewModel.memoryUsage * 100))%"
                    )
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isModelsLoaded ? Color.green : Color.orange)
                        .frame(width: 12, height: 12)
                    
                    Text(viewModel.isModelsLoaded ? "Ready" : "Loading")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct StatusRow: View {
    let title: String
    let status: MLStatus
    let value: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

struct ModelPerformanceOverviewCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Performance Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(Array(viewModel.modelPerformance.keys.prefix(4)), id: \.self) { modelName in
                    if let performance = viewModel.modelPerformance[modelName] {
                        ModelPerformanceMiniCard(
                            modelName: modelName,
                            performance: performance
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ModelPerformanceMiniCard: View {
    let modelName: String
    let performance: ModelPerformance
    
    var body: some View {
        VStack(spacing: 8) {
            Text(modelName.replacingOccurrences(of: "Model", with: ""))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("\(Int(performance.accuracy * 100))%")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(performance.accuracy >= 0.85 ? .green : .orange)
            
            Text(String(format: "%.1fms", performance.inferenceTime * 1000))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentPredictionsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Predictions")
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.recentPredictions.isEmpty {
                Text("No recent predictions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.recentPredictions.prefix(3), id: \.id) { prediction in
                    PredictionRow(prediction: prediction)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PredictionRow: View {
    let prediction: MLPrediction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.modelName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(prediction.result)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(prediction.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(prediction.confidence >= 0.8 ? .green : .orange)
                
                Text(String(format: "%.1fms", prediction.inferenceTime * 1000))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MLInsightsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ML Insights")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                InsightRow(
                    title: "Model Accuracy Trend",
                    value: "Improving",
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                InsightRow(
                    title: "Inference Performance",
                    value: "Optimal",
                    color: .green,
                    icon: "checkmark.circle.fill"
                )
                
                InsightRow(
                    title: "Training Recommendations",
                    value: "Ready for update",
                    color: .blue,
                    icon: "lightbulb.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct InsightRow: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            
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

// Additional supporting views for other tabs...
struct ModelPerformanceGridCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Performance Grid")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Detailed performance metrics for each ML model")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceTrendsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Trends")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Performance trends over time for all models")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ModelValidationCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Validation")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Validation results and accuracy metrics")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TrainingStatusCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Current training status and progress")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ModelVersionsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Model Versions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Version history and model evolution")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TrainingActionsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Training Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Actions for model training and updates")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct LivePredictionsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Predictions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Real-time ML predictions and results")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PredictionHistoryCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prediction History")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Historical prediction data and analytics")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PredictionAnalyticsCard: View {
    @ObservedObject var viewModel: RealMLDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prediction Analytics")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Analytics and insights from predictions")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - View Model

@MainActor
final class RealMLDashboardViewModel: ObservableObject {
    @Published var isModelsLoaded: Bool = false
    @Published var activeModels: [String: MLModel] = [:]
    @Published var modelPerformance: [String: ModelPerformance] = [:]
    @Published var isTraining: Bool = false
    @Published var isLoading: Bool = false
    @Published var recentPredictions: [MLPrediction] = []
    
    private let realMLModelManager: RealMLModelManagerProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(realMLModelManager: RealMLModelManagerProtocol = DependencyContainer.shared.realMLModelManager) {
        self.realMLModelManager = realMLModelManager
        
        // Subscribe to ML model updates
        realMLModelManager.$isModelsLoaded
            .assign(to: \.isModelsLoaded, on: self)
            .store(in: &cancellables)
        
        realMLModelManager.$activeModels
            .assign(to: \.activeModels, on: self)
            .store(in: &cancellables)
        
        realMLModelManager.$modelPerformance
            .assign(to: \.modelPerformance, on: self)
            .store(in: &cancellables)
    }
    
    var averageAccuracy: Double {
        guard !modelPerformance.isEmpty else { return 0.0 }
        let totalAccuracy = modelPerformance.values.reduce(0.0) { $0 + $1.accuracy }
        return totalAccuracy / Double(modelPerformance.count)
    }
    
    var averageInferenceTime: TimeInterval {
        guard !modelPerformance.isEmpty else { return 0.0 }
        let totalTime = modelPerformance.values.reduce(0.0) { $0 + $1.inferenceTime }
        return totalTime / Double(modelPerformance.count)
    }
    
    var memoryUsage: Double {
        // Calculate memory usage for ML models
        return 0.45 // Simplified
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            do {
                try await loadMLModels()
                try await loadModelPerformance()
                try await loadRecentPredictions()
            } catch {
                print("Error loading ML data: \(error)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadMLModels() async throws {
        try await realMLModelManager.loadFitnessModels()
    }
    
    private func loadModelPerformance() async throws {
        // Load model performance data
        // This would typically come from the ML model manager
    }
    
    private func loadRecentPredictions() async throws {
        // Load recent predictions
        // This would typically come from a prediction history service
        
        // Placeholder data
        recentPredictions = [
            MLPrediction(
                id: "1",
                modelName: "FitnessPrediction",
                result: "Recommended workout: Upper body focus",
                confidence: 0.87,
                inferenceTime: 0.15,
                timestamp: Date()
            ),
            MLPrediction(
                id: "2",
                modelName: "FormAnalysis",
                result: "Form score: 89% - Good alignment",
                confidence: 0.92,
                inferenceTime: 0.12,
                timestamp: Date().addingTimeInterval(-300)
            ),
            MLPrediction(
                id: "3",
                modelName: "HealthPrediction",
                result: "Recovery score: 78% - Rest recommended",
                confidence: 0.85,
                inferenceTime: 0.18,
                timestamp: Date().addingTimeInterval(-600)
            )
        ]
    }
}

// MARK: - Supporting Types

struct MLPrediction {
    let id: String
    let modelName: String
    let result: String
    let confidence: Double
    let inferenceTime: TimeInterval
    let timestamp: Date
}

enum MLStatus {
    case active
    case inactive
    case training
    case idle
    
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .red
        case .training: return .orange
        case .idle: return .gray
        }
    }
}

// MARK: - Supporting Views

struct ModelDetailsView: View {
    let modelName: String
    
    var body: some View {
        NavigationView {
            Text("Model Details for \(modelName)")
                .navigationTitle("Model Details")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TrainingSessionView: View {
    var body: some View {
        NavigationView {
            Text("Training Session")
                .navigationTitle("Training Session")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

struct RealMLDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        RealMLDashboardView()
    }
}

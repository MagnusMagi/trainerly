import SwiftUI
import CoreML

// MARK: - Model Details View
struct ModelDetailsView: View {
    let model: MLModelInfo
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ModelDetailsViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Model Header
                    modelHeaderSection
                    
                    // Model Information
                    modelInfoSection
                    
                    // Performance Metrics
                    performanceMetricsSection
                    
                    // Model Actions
                    modelActionsSection
                    
                    // Recent Inferences
                    recentInferencesSection
                    
                    // Model Configuration
                    modelConfigurationSection
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") { dismiss() },
                trailing: refreshButton
            )
            .onAppear {
                viewModel.loadModelDetails(for: model)
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error occurred")
            }
        }
    }
    
    // MARK: - Model Header Section
    private var modelHeaderSection: some View {
        VStack(spacing: 16) {
            // Model Icon and Name
            HStack {
                Image(systemName: iconName(for: model.type))
                    .font(.system(size: 40))
                    .foregroundColor(.trainerlyPrimary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(model.type.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                StatusBadge(
                    isLoaded: model.isLoaded,
                    isValid: model.isValid
                )
            }
            
            // Version and Last Updated
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(model.version)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last Updated")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDate(model.lastUpdated))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
    
    // MARK: - Model Information Section
    private var modelInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Information")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                InfoCard(
                    title: "Input Shape",
                    value: model.inputShape.map(String.init).joined(separator: " × "),
                    icon: "arrow.down.circle",
                    color: .blue
                )
                
                InfoCard(
                    title: "Output Shape",
                    value: model.outputShape.map(String.init).joined(separator: " × "),
                    icon: "arrow.up.circle",
                    color: .green
                )
                
                InfoCard(
                    title: "Model Size",
                    value: viewModel.modelSize,
                    icon: "externaldrive",
                    color: .orange
                )
                
                InfoCard(
                    title: "Last Validation",
                    value: formatDate(model.lastValidation),
                    icon: "checkmark.shield",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Performance Metrics Section
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                MetricCard(
                    title: "Accuracy",
                    value: "\(Int(viewModel.accuracy * 100))%",
                    trend: viewModel.accuracyTrend,
                    icon: "target",
                    color: .green
                )
                
                MetricCard(
                    title: "Latency",
                    value: "\(viewModel.latency, specifier: "%.2f")ms",
                    trend: viewModel.latencyTrend,
                    icon: "clock",
                    color: .blue
                )
                
                MetricCard(
                    title: "Throughput",
                    value: "\(viewModel.throughput) req/s",
                    trend: viewModel.throughputTrend,
                    icon: "speedometer",
                    color: .orange
                )
                
                MetricCard(
                    title: "Memory Usage",
                    value: viewModel.memoryUsage,
                    trend: viewModel.memoryTrend,
                    icon: "memorychip",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Model Actions Section
    private var modelActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ActionButton(
                    title: "Test Model",
                    description: "Run inference with sample data",
                    icon: "play.circle",
                    color: .green,
                    isLoading: viewModel.isTestingModel,
                    action: {
                        viewModel.testModel(model: model)
                    }
                )
                
                ActionButton(
                    title: "Validate Model",
                    description: "Run validation tests",
                    icon: "checkmark.shield",
                    color: .blue,
                    isLoading: viewModel.isValidatingModel,
                    action: {
                        viewModel.validateModel(model: model)
                    }
                )
                
                ActionButton(
                    title: "Update Model",
                    description: "Download latest version",
                    icon: "arrow.down.circle",
                    color: .orange,
                    isLoading: viewModel.isUpdatingModel,
                    action: {
                        viewModel.updateModel(model: model)
                    }
                )
                
                ActionButton(
                    title: "Export Model",
                    description: "Export model data",
                    icon: "square.and.arrow.up",
                    color: .purple,
                    isLoading: viewModel.isExportingModel,
                    action: {
                        viewModel.exportModel(model: model)
                    }
                )
            }
        }
    }
    
    // MARK: - Recent Inferences Section
    private var recentInferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Inferences")
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.recentInferences.isEmpty {
                EmptyStateView(
                    icon: "brain.head.profile",
                    title: "No Recent Inferences",
                    description: "Run some tests to see inference results"
                )
            } else {
                ForEach(viewModel.recentInferences.prefix(5), id: \.timestamp) { inference in
                    InferenceResultCard(inference: inference)
                }
            }
        }
    }
    
    // MARK: - Model Configuration Section
    private var modelConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Model Configuration")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                ConfigurationRow(
                    title: "Compute Units",
                    value: viewModel.computeUnits,
                    icon: "cpu"
                )
                
                ConfigurationRow(
                    title: "Low Precision GPU",
                    value: viewModel.lowPrecisionGPU ? "Enabled" : "Disabled",
                    icon: "memorychip"
                )
                
                ConfigurationRow(
                    title: "Model Location",
                    value: viewModel.modelLocation,
                    icon: "folder"
                )
                
                ConfigurationRow(
                    title: "Cache Policy",
                    value: viewModel.cachePolicy,
                    icon: "archivebox"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: {
            viewModel.loadModelDetails(for: model)
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    private func iconName(for type: MLModelType) -> String {
        switch type {
        case .performancePrediction: return "chart.line.uptrend.xyaxis"
        case .formAnalysis: return "camera.viewfinder"
        case .injuryRisk: return "exclamationmark.triangle"
        case .recoveryOptimization: return "bed.double.fill"
        case .trainingOptimization: return "gearshape"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let isLoaded: Bool
    let isValid: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        if !isLoaded { return .red }
        if !isValid { return .orange }
        return .green
    }
    
    private var statusText: String {
        if !isLoaded { return "Not Loaded" }
        if !isValid { return "Invalid" }
        return "Active"
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
                
                TrendIndicator(trend: trend)
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct TrendIndicator: View {
    let trend: TrendDirection
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trendIcon)
                .font(.caption)
                .foregroundColor(trendColor)
            
            Text(trendText)
                .font(.caption2)
                .foregroundColor(trendColor)
        }
    }
    
    private var trendIcon: String {
        switch trend {
        case .improving: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
    
    private var trendColor: Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        }
    }
    
    private var trendText: String {
        switch trend {
        case .improving: return "↑"
        case .declining: return "↓"
        case .stable: return "→"
        }
    }
}

struct ActionButton: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
    }
}

struct InferenceResultCard: View {
    let inference: MLInferenceResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Inference #\(inference.modelName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatTimestamp(inference.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Processing Time:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(inference.processingTime, specifier: "%.3f")s")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("Confidence:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(inference.output.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

struct ConfigurationRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - View Model

@MainActor
final class ModelDetailsViewModel: ObservableObject {
    @Published var modelSize: String = "0 MB"
    @Published var accuracy: Double = 0.0
    @Published var latency: Double = 0.0
    @Published var throughput: Int = 0
    @Published var memoryUsage: String = "0 MB"
    @Published var accuracyTrend: TrendDirection = .stable
    @Published var latencyTrend: TrendDirection = .stable
    @Published var throughputTrend: TrendDirection = .stable
    @Published var memoryTrend: TrendDirection = .stable
    @Published var recentInferences: [MLInferenceResult] = []
    @Published var computeUnits: String = "CPU & GPU"
    @Published var lowPrecisionGPU: Bool = true
    @Published var modelLocation: String = "Local"
    @Published var cachePolicy: String = "Default"
    @Published var isLoading: Bool = false
    @Published var isTestingModel: Bool = false
    @Published var isValidatingModel: Bool = false
    @Published var isUpdatingModel: Bool = false
    @Published var isExportingModel: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let mlModelManager: MLModelManagerProtocol
    
    init(mlModelManager: MLModelManagerProtocol = DependencyContainer.shared.mlModelManager) {
        self.mlModelManager = mlModelManager
    }
    
    func loadModelDetails(for model: MLModelInfo) {
        isLoading = true
        
        Task {
            do {
                // Load model details
                try await loadModelMetrics(for: model)
                try await loadRecentInferences(for: model)
                try await loadModelConfiguration(for: model)
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadModelMetrics(for model: MLModelInfo) async throws {
        // Load model performance metrics
        // This would typically fetch from the ML model manager
        
        // Simulate loading metrics
        await MainActor.run {
            modelSize = "\(Int.random(in: 50...200)) MB"
            accuracy = Double.random(in: 0.75...0.95)
            latency = Double.random(in: 10...100)
            throughput = Int.random(in: 100...1000)
            memoryUsage = "\(Int.random(in: 20...80)) MB"
            
            // Set trends based on random values
            accuracyTrend = accuracy > 0.85 ? .improving : .stable
            latencyTrend = latency < 50 ? .improving : .stable
            throughputTrend = throughput > 500 ? .improving : .stable
            memoryTrend = memoryUsage.contains("40") ? .improving : .stable
        }
    }
    
    private func loadRecentInferences(for model: MLModelInfo) async throws {
        // Load recent inference results
        // This would typically fetch from the ML model manager
        
        // Simulate recent inferences
        await MainActor.run {
            recentInferences = (0..<3).map { index in
                MLInferenceResult(
                    modelName: model.name,
                    timestamp: Date().addingTimeInterval(-Double(index * 3600)),
                    input: .performancePrediction(PerformancePredictionInput(
                        workoutData: WorkoutData(
                            type: .strength,
                            intensity: .moderate,
                            duration: 3600,
                            exercises: []
                        ),
                        userProfile: UserProfile(
                            fitnessLevel: .intermediate,
                            age: 30,
                            weight: 70.0,
                            height: 175.0,
                            goals: []
                        ),
                        healthMetrics: HealthMetrics(
                            heartRate: 75.0,
                            sleepHours: 7.5,
                            stressLevel: 30.0,
                            energyLevel: 80.0
                        ),
                        recentPerformance: RecentPerformance(
                            averageIntensity: 0.7,
                            consistency: 0.8,
                            improvement: 0.1
                        )
                    )),
                    output: .performancePrediction(PerformancePredictionOutput(
                        predictedDuration: 2700,
                        predictedCalories: 300,
                        predictedDifficulty: .intermediate,
                        predictedForm: 0.85,
                        confidence: 0.87,
                        processingTime: 0.045
                    )),
                    processingTime: 0.045
                )
            }
        }
    }
    
    private func loadModelConfiguration(for model: MLModelInfo) async throws {
        // Load model configuration
        // This would typically fetch from the ML model manager
        
        await MainActor.run {
            computeUnits = "CPU & GPU"
            lowPrecisionGPU = true
            modelLocation = "Local"
            cachePolicy = "Default"
        }
    }
    
    func testModel(model: MLModelInfo) {
        isTestingModel = true
        
        Task {
            do {
                // Test the model with sample data
                try await performModelTest(model: model)
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isTestingModel = false
            }
        }
    }
    
    func validateModel(model: MLModelInfo) {
        isValidatingModel = true
        
        Task {
            do {
                // Validate the model
                try await mlModelManager.validateModel(modelName: model.name)
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isValidatingModel = false
            }
        }
    }
    
    func updateModel(model: MLModelInfo) {
        isUpdatingModel = true
        
        Task {
            do {
                // Update the model
                // This would typically download and update the model
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isUpdatingModel = false
            }
        }
    }
    
    func exportModel(model: MLModelInfo) {
        isExportingModel = true
        
        Task {
            do {
                // Export the model
                // This would typically export model data
                try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isExportingModel = false
            }
        }
    }
    
    private func performModelTest(model: MLModelInfo) async throws {
        // Perform model test
        // This would typically run inference with test data
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Types

extension MLInferenceResult {
    var output: MLModelOutput {
        // This is a computed property to access the output
        // In a real implementation, this would be stored directly
        return .performancePrediction(PerformancePredictionOutput(
            predictedDuration: 2700,
            predictedCalories: 300,
            predictedDifficulty: .intermediate,
            predictedForm: 0.85,
            confidence: 0.87,
            processingTime: 0.045
        ))
    }
}

// MARK: - Preview

struct ModelDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleModel = MLModelInfo(
            name: "SampleModel",
            type: .performancePrediction,
            version: "1.0.0",
            isLoaded: true,
            isValid: true,
            lastUpdated: Date(),
            lastValidation: Date(),
            inputShape: [1, 64, 64, 3],
            outputShape: [1, 10]
        )
        
        ModelDetailsView(model: sampleModel)
    }
}

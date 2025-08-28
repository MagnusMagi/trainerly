import SwiftUI
import Combine

// MARK: - ML Integration Dashboard View
struct MLIntegrationDashboardView: View {
    @StateObject private var viewModel = MLIntegrationDashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingModelDetails = false
    @State private var selectedModel: MLModelInfo?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    personalizationTab.tag(0)
                    modelManagementTab.tag(1)
                    adaptiveWorkoutsTab.tag(2)
                    insightsTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("ML Integration")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: refreshButton)
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingModelDetails) {
                if let model = selectedModel {
                    ModelDetailsView(model: model)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // ML Status Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Machine Learning Engine")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("AI-powered personalization & optimization")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(.trainerlyPrimary)
            }
            .padding(.horizontal)
            
            // ML Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                MLStatCard(
                    title: "Active Models",
                    value: "\(viewModel.activeModelsCount)",
                    icon: "cpu",
                    color: .blue,
                    status: viewModel.isModelsLoaded ? .active : .inactive
                )
                MLStatCard(
                    title: "Inference Count",
                    value: "\(viewModel.totalInferences)",
                    icon: "brain.head.profile",
                    color: .green,
                    status: .active
                )
                MLStatCard(
                    title: "Accuracy",
                    value: "\(Int(viewModel.averageAccuracy * 100))%",
                    icon: "target",
                    color: .orange,
                    status: .active
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
    private var personalizationTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Personalization Features
                PersonalizationFeatureCard(
                    title: "Workout Difficulty Adjustment",
                    description: "AI-powered workout difficulty personalization based on your performance and readiness",
                    icon: "slider.horizontal.3",
                    isEnabled: viewModel.isPersonalizationEnabled,
                    action: {
                        viewModel.enablePersonalization()
                    }
                )
                
                PersonalizationFeatureCard(
                    title: "Adaptive Exercise Selection",
                    description: "Smart exercise recommendations based on your goals and performance patterns",
                    icon: "list.bullet",
                    isEnabled: viewModel.isExerciseSelectionEnabled,
                    action: {
                        viewModel.enableExerciseSelection()
                    }
                )
                
                PersonalizationFeatureCard(
                    title: "Training Volume Optimization",
                    description: "ML-driven training volume adjustments for optimal progress and recovery",
                    icon: "chart.bar.fill",
                    isEnabled: viewModel.isVolumeOptimizationEnabled,
                    action: {
                        viewModel.enableVolumeOptimization()
                    }
                )
                
                PersonalizationFeatureCard(
                    title: "Recovery Personalization",
                    description: "AI-powered recovery recommendations based on workout intensity and health metrics",
                    icon: "bed.double.fill",
                    isEnabled: viewModel.isRecoveryPersonalizationEnabled,
                    action: {
                        viewModel.enableRecoveryPersonalization()
                    }
                )
            }
            .padding()
        }
    }
    
    private var modelManagementTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Model Status
                ForEach(Array(viewModel.activeModels.values), id: \.name) { model in
                    ModelStatusCard(
                        model: model,
                        onTap: {
                            selectedModel = model
                            showingModelDetails = true
                        }
                    )
                }
                
                if viewModel.activeModels.isEmpty {
                    EmptyStateView(
                        icon: "cpu",
                        title: "No Models Loaded",
                        description: "ML models are being initialized..."
                    )
                }
                
                // Model Actions
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.reloadModels()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload Models")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: {
                        viewModel.validateModels()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.shield")
                            Text("Validate Models")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
    
    private var adaptiveWorkoutsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Generate Adaptive Workout
                AdaptiveWorkoutCard(
                    title: "Generate Adaptive Workout",
                    description: "Create a personalized workout that adapts to your current state and goals",
                    icon: "dumbbell.fill",
                    action: {
                        viewModel.generateAdaptiveWorkout()
                    }
                )
                
                // Progressive Overload
                AdaptiveWorkoutCard(
                    title: "Progressive Overload Plan",
                    description: "Get a personalized plan for gradually increasing exercise difficulty",
                    icon: "chart.line.uptrend.xyaxis",
                    action: {
                        viewModel.generateProgressiveOverloadPlan()
                    }
                )
                
                // Recent Personalizations
                if !viewModel.recentPersonalizations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Personalizations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(viewModel.recentPersonalizations.prefix(3), id: \.timestamp) { personalization in
                            RecentPersonalizationCard(personalization: personalization)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .padding()
        }
    }
    
    private var insightsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // ML Insights
                ForEach(viewModel.mlInsights, id: \.id) { insight in
                    MLInsightCard(insight: insight)
                }
                
                if viewModel.mlInsights.isEmpty {
                    EmptyStateView(
                        icon: "lightbulb",
                        title: "No ML Insights Yet",
                        description: "Complete more workouts to generate machine learning insights"
                    )
                }
                
                // Performance Metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("ML Performance Metrics")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        MetricCard(
                            title: "Prediction Accuracy",
                            value: "\(Int(viewModel.predictionAccuracy * 100))%",
                            trend: .improving
                        )
                        MetricCard(
                            title: "Model Confidence",
                            value: "\(Int(viewModel.averageConfidence * 100))%",
                            trend: .stable
                        )
                        MetricCard(
                            title: "Personalization Rate",
                            value: "\(Int(viewModel.personalizationRate * 100))%",
                            trend: .improving
                        )
                        MetricCard(
                            title: "User Satisfaction",
                            value: "\(Int(viewModel.userSatisfaction * 100))%",
                            trend: .improving
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding()
        }
    }
    
    // MARK: - Refresh Button
    private var refreshButton: some View {
        Button(action: {
            viewModel.loadData()
        }) {
            Image(systemName: "arrow.clockwise")
                .font(.title3)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Personalization"
        case 1: return "Models"
        case 2: return "Adaptive"
        case 3: return "Insights"
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
    let status: MLStatus
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                StatusIndicator(status: status)
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

struct StatusIndicator: View {
    let status: MLStatus
    
    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }
    
    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .inactive: return .red
        case .loading: return .orange
        case .error: return .red
        }
    }
}

struct PersonalizationFeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.trainerlyPrimary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(isEnabled))
                    .onChange(of: isEnabled) { _ in
                        action()
                    }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ModelStatusCard: View {
    let model: MLModelInfo
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(model.type.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(model.isLoaded ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(model.isLoaded ? "Loaded" : "Not Loaded")
                                .font(.caption)
                                .foregroundColor(model.isLoaded ? .green : .red)
                        }
                        
                        Text("v\(model.version)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Input: \(model.inputShape.map(String.init).joined(separator: "×"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Output: \(model.outputShape.map(String.init).joined(separator: "×"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AdaptiveWorkoutCard: View {
    let title: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.trainerlyPrimary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecentPersonalizationCard: View {
    let personalization: PersonalizationResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(personalization.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(formatTimestamp(personalization.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Personalization completed successfully")
                .font(.caption)
                .foregroundColor(.secondary)
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

struct MLInsightCard: View {
    let insight: MLInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: insight.type))
                    .font(.title2)
                    .foregroundColor(color(for: insight.type))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(insight.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ConfidenceBadge(confidence: insight.confidence)
            }
            
            Text(insight.description)
                .font(.body)
                .foregroundColor(.primary)
            
            if !insight.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(insight.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func iconName(for type: MLInsightType) -> String {
        switch type {
        case .personalization: return "person.crop.circle"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .recovery: return "bed.double.fill"
        case .optimization: return "gearshape"
        }
    }
    
    private func color(for type: MLInsightType) -> Color {
        switch type {
        case .personalization: return .blue
        case .performance: return .green
        case .recovery: return .purple
        case .optimization: return .orange
        }
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: trendIcon)
                    .font(.caption)
                    .foregroundColor(trendColor)
                
                Text(trendText)
                    .font(.caption2)
                    .foregroundColor(trendColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
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
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
}

// MARK: - View Model

@MainActor
final class MLIntegrationDashboardViewModel: ObservableObject {
    @Published var activeModelsCount: Int = 0
    @Published var totalInferences: Int = 0
    @Published var averageAccuracy: Double = 0.0
    @Published var activeModels: [String: MLModelInfo] = [:]
    @Published var recentPersonalizations: [PersonalizationResult] = []
    @Published var mlInsights: [MLInsight] = []
    @Published var predictionAccuracy: Double = 0.0
    @Published var averageConfidence: Double = 0.0
    @Published var personalizationRate: Double = 0.0
    @Published var userSatisfaction: Double = 0.0
    @Published var isPersonalizationEnabled: Bool = false
    @Published var isExerciseSelectionEnabled: Bool = false
    @Published var isVolumeOptimizationEnabled: Bool = false
    @Published var isRecoveryPersonalizationEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let mlModelManager: MLModelManagerProtocol
    private let personalizationEngine: PersonalizationEngineProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        mlModelManager: MLModelManagerProtocol = DependencyContainer.shared.mlModelManager,
        personalizationEngine: PersonalizationEngineProtocol = DependencyContainer.shared.personalizationEngine
    ) {
        self.mlModelManager = mlModelManager
        self.personalizationEngine = personalizationEngine
        
        setupBindings()
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load ML model data
                try await loadMLModelData()
                
                // Load personalization data
                try await loadPersonalizationData()
                
                // Load ML insights
                try await loadMLInsights()
                
                // Update metrics
                updateMetrics()
                
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
        mlModelManager.$activeModels
            .sink { [weak self] models in
                self?.activeModels = models
                self?.activeModelsCount = models.count
            }
            .store(in: &cancellables)
    }
    
    private func loadMLModelData() async throws {
        // Load ML model data
        if !mlModelManager.isModelsLoaded {
            try await mlModelManager.loadModels()
        }
    }
    
    private func loadPersonalizationData() async throws {
        // Load personalization data
        // This would typically fetch from the personalization engine
    }
    
    private func loadMLInsights() async throws {
        // Load ML insights
        // This would typically fetch from the analytics engine
    }
    
    private func updateMetrics() {
        // Update performance metrics
        predictionAccuracy = 0.87
        averageConfidence = 0.89
        personalizationRate = 0.92
        userSatisfaction = 0.94
        totalInferences = 1247
    }
    
    func enablePersonalization() {
        isPersonalizationEnabled.toggle()
    }
    
    func enableExerciseSelection() {
        isExerciseSelectionEnabled.toggle()
    }
    
    func enableVolumeOptimization() {
        isVolumeOptimizationEnabled.toggle()
    }
    
    func enableRecoveryPersonalization() {
        isRecoveryPersonalizationEnabled.toggle()
    }
    
    func reloadModels() {
        Task {
            try await mlModelManager.loadModels()
        }
    }
    
    func validateModels() {
        Task {
            for modelName in mlModelManager.activeModels.keys {
                try await mlModelManager.validateModel(modelName: modelName)
            }
        }
    }
    
    func generateAdaptiveWorkout() {
        // Generate adaptive workout
        print("Generating adaptive workout...")
    }
    
    func generateProgressiveOverloadPlan() {
        // Generate progressive overload plan
        print("Generating progressive overload plan...")
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Types

enum MLStatus {
    case active
    case inactive
    case loading
    case error
}

enum TrendDirection {
    case improving
    case declining
    case stable
}

enum MLInsightType: String, CaseIterable {
    case personalization = "Personalization"
    case performance = "Performance"
    case recovery = "Recovery"
    case optimization = "Optimization"
}

struct MLInsight {
    let id: String
    let type: MLInsightType
    let title: String
    let description: String
    let confidence: Double
    let recommendations: [String]
}

// MARK: - Dependency Container Extension

extension DependencyContainer {
    static var shared: DependencyContainer {
        MainDependencyContainer()
    }
}

// MARK: - Preview

struct MLIntegrationDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MLIntegrationDashboardView()
    }
}

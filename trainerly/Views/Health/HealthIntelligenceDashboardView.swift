import SwiftUI
import Combine

// MARK: - Health Intelligence Dashboard View
struct HealthIntelligenceDashboardView: View {
    @StateObject private var viewModel = HealthIntelligenceDashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingHealthDetail = false
    @State private var selectedHealthMetric: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    healthPatternsTab.tag(0)
                    biometricCorrelationsTab.tag(1)
                    healthInsightsTab.tag(2)
                    recoveryReadinessTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Health Intelligence")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: refreshButton)
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingHealthDetail) {
                if let metric = selectedHealthMetric {
                    HealthDetailView(metric: metric)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Health Intelligence Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Intelligence Engine")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("AI-powered health insights & biometric analysis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "heart.text.square")
                    .font(.title2)
                    .foregroundColor(.trainerlyPrimary)
            }
            .padding(.horizontal)
            
            // Health Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                HealthStatCard(
                    title: "Health Score",
                    value: "\(Int(viewModel.overallHealthScore * 100))%",
                    icon: "heart.fill",
                    color: .red,
                    trend: viewModel.healthScoreTrend
                )
                HealthStatCard(
                    title: "Sleep Quality",
                    value: "\(Int(viewModel.sleepQuality * 100))%",
                    icon: "bed.double.fill",
                    color: .purple,
                    trend: viewModel.sleepQualityTrend
                )
                HealthStatCard(
                    title: "Recovery",
                    value: "\(Int(viewModel.recoveryReadiness * 100))%",
                    icon: "leaf.fill",
                    color: .green,
                    trend: viewModel.recoveryReadinessTrend
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
    private var healthPatternsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Health Patterns Overview
                HealthPatternsOverviewCard(patterns: viewModel.healthPatterns)
                
                // Pattern Details
                ForEach(viewModel.healthPatterns, id: \.type) { pattern in
                    HealthPatternCard(pattern: pattern)
                }
                
                if viewModel.healthPatterns.isEmpty {
                    EmptyStateView(
                        icon: "heart.text.square",
                        title: "No Health Patterns Yet",
                        description: "Complete more health tracking to identify patterns"
                    )
                }
            }
            .padding()
        }
    }
    
    private var biometricCorrelationsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Correlation Overview
                BiometricCorrelationOverviewCard(correlations: viewModel.biometricCorrelations)
                
                // Individual Correlations
                ForEach(viewModel.biometricCorrelations, id: \.type) { correlation in
                    BiometricCorrelationCard(correlation: correlation)
                }
                
                if viewModel.biometricCorrelations.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Correlations Yet",
                        description: "More data needed to identify biometric correlations"
                    )
                }
            }
            .padding()
        }
    }
    
    private var healthInsightsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Health Insights
                ForEach(viewModel.healthInsights, id: \.id) { insight in
                    HealthInsightCard(insight: insight)
                }
                
                if viewModel.healthInsights.isEmpty {
                    EmptyStateView(
                        icon: "lightbulb",
                        title: "No Health Insights Yet",
                        description: "Complete more health tracking to generate insights"
                    )
                }
                
                // Health Recommendations
                if !viewModel.healthRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Health Recommendations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(viewModel.healthRecommendations.prefix(5), id: \.id) { recommendation in
                            HealthRecommendationCard(recommendation: recommendation)
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
    
    private var recoveryReadinessTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Recovery Readiness Overview
                RecoveryReadinessOverviewCard(assessment: viewModel.recoveryReadinessAssessment)
                
                // Recovery Factors
                if let assessment = viewModel.recoveryReadinessAssessment {
                    RecoveryFactorsCard(assessment: assessment)
                }
                
                // Recovery Recommendations
                if !viewModel.recoveryRecommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recovery Recommendations")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(viewModel.recoveryRecommendations, id: \.id) { recommendation in
                            RecoveryRecommendationCard(recommendation: recommendation)
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
        case 0: return "Patterns"
        case 1: return "Correlations"
        case 2: return "Insights"
        case 3: return "Recovery"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct HealthStatCard: View {
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

struct HealthPatternsOverviewCard: View {
    let patterns: [HealthPattern]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Patterns Overview")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(patterns.prefix(4), id: \.type) { pattern in
                    PatternSummaryCard(pattern: pattern)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PatternSummaryCard: View {
    let pattern: HealthPattern
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName(for: pattern.type))
                .font(.title2)
                .foregroundColor(color(for: pattern.type))
            
            Text(pattern.type.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(Int(pattern.score * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconName(for type: HealthPatternType) -> String {
        switch type {
        case .sleep: return "bed.double.fill"
        case .heartRate: return "heart.fill"
        case .activity: return "figure.walk"
        case .recovery: return "leaf.fill"
        case .stress: return "brain.head.profile"
        case .nutrition: return "fork.knife"
        }
    }
    
    private func color(for type: HealthPatternType) -> Color {
        switch type {
        case .sleep: return .purple
        case .heartRate: return .red
        case .activity: return .blue
        case .recovery: return .green
        case .stress: return .orange
        case .nutrition: return .yellow
        }
    }
}

struct HealthPatternCard: View {
    let pattern: HealthPattern
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: pattern.type))
                    .font(.title2)
                    .foregroundColor(color(for: pattern.type))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(pattern.type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(pattern.score * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    TrendIndicator(trend: pattern.trend)
                }
            }
            
            if !pattern.insights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(pattern.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(insight)
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
    
    private func iconName(for type: HealthPatternType) -> String {
        switch type {
        case .sleep: return "bed.double.fill"
        case .heartRate: return "heart.fill"
        case .activity: return "figure.walk"
        case .recovery: return "leaf.fill"
        case .stress: return "brain.head.profile"
        case .nutrition: return "fork.knife"
        }
    }
    
    private func color(for type: HealthPatternType) -> Color {
        switch type {
        case .sleep: return .purple
        case .heartRate: return .red
        case .activity: return .blue
        case .recovery: return .green
        case .stress: return .orange
        case .nutrition: return .yellow
        }
    }
}

struct BiometricCorrelationOverviewCard: View {
    let correlations: [BiometricCorrelation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Biometric Correlations")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(correlations.prefix(4), id: \.type) { correlation in
                    CorrelationSummaryCard(correlation: correlation)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct CorrelationSummaryCard: View {
    let correlation: BiometricCorrelation
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName(for: correlation.type))
                .font(.title2)
                .foregroundColor(color(for: correlation.type))
            
            Text(correlation.type.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(Int(correlation.strength * 100))%")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconName(for type: BiometricCorrelationType) -> String {
        switch type {
        case .sleepPerformance: return "bed.double.fill"
        case .heartRateRecovery: return "heart.fill"
        case .activitySleep: return "figure.walk"
        case .stressRecovery: return "brain.head.profile"
        case .nutritionRecovery: return "fork.knife"
        case .formProgress: return "figure.strengthtraining.traditional"
        }
    }
    
    private func color(for type: BiometricCorrelationType) -> Color {
        switch type {
        case .sleepPerformance: return .purple
        case .heartRateRecovery: return .red
        case .activitySleep: return .blue
        case .stressRecovery: return .orange
        case .nutritionRecovery: return .yellow
        case .formProgress: return .green
        }
    }
}

struct BiometricCorrelationCard: View {
    let correlation: BiometricCorrelation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: correlation.type))
                    .font(.title2)
                    .foregroundColor(color(for: correlation.type))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(correlation.type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(correlation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(Int(correlation.strength * 100))%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    ConfidenceBadge(confidence: correlation.confidence)
                }
            }
            
            if !correlation.insights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Insights:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    ForEach(correlation.insights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(insight)
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
    
    private func iconName(for type: BiometricCorrelationType) -> String {
        switch type {
        case .sleepPerformance: return "bed.double.fill"
        case .heartRateRecovery: return "heart.fill"
        case .activitySleep: return "figure.walk"
        case .stressRecovery: return "brain.head.profile"
        case .nutritionRecovery: return "fork.knife"
        case .formProgress: return "figure.strengthtraining.traditional"
        }
    }
    
    private func color(for type: BiometricCorrelationType) -> Color {
        switch type {
        case .sleepPerformance: return .purple
        case .heartRateRecovery: return .red
        case .activitySleep: return .blue
        case .stressRecovery: return .orange
        case .nutritionRecovery: return .yellow
        case .formProgress: return .green
        }
    }
}

struct HealthInsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName(for: insight.category))
                    .font(.title2)
                    .foregroundColor(color(for: insight.category))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(insight.category.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    PriorityBadge(priority: insight.priority)
                    ConfidenceBadge(confidence: insight.confidence)
                }
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
    
    private func iconName(for category: InsightCategory) -> String {
        switch category {
        case .sleep: return "bed.double.fill"
        case .heartRate: return "heart.fill"
        case .activity: return "figure.walk"
        case .recovery: return "leaf.fill"
        case .nutrition: return "fork.knife"
        case .stress: return "brain.head.profile"
        }
    }
    
    private func color(for category: InsightCategory) -> Color {
        switch category {
        case .sleep: return .purple
        case .heartRate: return .red
        case .activity: return .blue
        case .recovery: return .green
        case .nutrition: return .yellow
        case .stress: return .orange
        }
    }
}

struct HealthRecommendationCard: View {
    let recommendation: HealthRecommendation
    
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
            
            HStack {
                Text(recommendation.category.rawValue)
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
                
                Text("\(Int(recommendation.impact.rawValue * 100))% impact")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecoveryReadinessOverviewCard: View {
    let assessment: RecoveryReadinessAssessment?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Readiness")
                .font(.headline)
                .foregroundColor(.primary)
            
            if let assessment = assessment {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overall Readiness")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(Int(assessment.readinessScore * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ReadinessStatusBadge(score: assessment.readinessScore)
                    }
                }
                
                // Recovery Factors
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    RecoveryFactorCard(title: "Sleep", value: assessment.sleepQuality, icon: "bed.double.fill", color: .purple)
                    RecoveryFactorCard(title: "HRV", value: assessment.heartRateVariability, icon: "heart.fill", color: .red)
                    RecoveryFactorCard(title: "Fatigue", value: 1.0 - assessment.muscleFatigue, icon: "figure.strengthtraining.traditional", color: .orange)
                    RecoveryFactorCard(title: "Stress", value: 1.0 - assessment.stressLevel, icon: "brain.head.profile", color: .blue)
                }
            } else {
                EmptyStateView(
                    icon: "leaf.fill",
                    title: "No Recovery Data",
                    description: "Complete more workouts to assess recovery readiness"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct RecoveryFactorCard: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(Int(value * 100))%")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct RecoveryFactorsCard: View {
    let assessment: RecoveryReadinessAssessment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Factors")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                RecoveryFactorRow(title: "Sleep Quality", value: assessment.sleepQuality, color: .purple)
                RecoveryFactorRow(title: "Heart Rate Variability", value: assessment.heartRateVariability, color: .red)
                RecoveryFactorRow(title: "Muscle Fatigue", value: 1.0 - assessment.muscleFatigue, color: .orange)
                RecoveryFactorRow(title: "Stress Level", value: 1.0 - assessment.stressLevel, color: .blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct RecoveryFactorRow: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 8) {
                ProgressView(value: value)
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(width: 60)
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RecoveryRecommendationCard: View {
    let recommendation: RecoveryRecommendation
    
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
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Components

struct ReadinessStatusBadge: View {
    let score: Double
    
    var body: some View {
        Text(statusText)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }
    
    private var statusText: String {
        if score >= 0.8 { return "Ready" }
        else if score >= 0.6 { return "Moderate" }
        else { return "Rest" }
    }
    
    private var statusColor: Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .orange }
        else { return .red }
    }
}

struct PriorityBadge: View {
    let priority: InsightPriority
    
    var body: some View {
        Text(priorityText)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor)
            .cornerRadius(6)
    }
    
    private var priorityText: String {
        switch priority {
        case .high: return "High"
        case .medium: return "Med"
        case .low: return "Low"
        }
    }
    
    private var priorityColor: Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
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
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        if confidence >= 0.8 { return .green }
        else if confidence >= 0.6 { return .orange }
        else { return .red }
    }
}

// MARK: - View Model

@MainActor
final class HealthIntelligenceDashboardViewModel: ObservableObject {
    @Published var overallHealthScore: Double = 0.0
    @Published var sleepQuality: Double = 0.0
    @Published var recoveryReadiness: Double = 0.0
    @Published var healthScoreTrend: TrendDirection = .stable
    @Published var sleepQualityTrend: TrendDirection = .stable
    @Published var recoveryReadinessTrend: TrendDirection = .stable
    @Published var healthPatterns: [HealthPattern] = []
    @Published var biometricCorrelations: [BiometricCorrelation] = []
    @Published var healthInsights: [HealthInsight] = []
    @Published var healthRecommendations: [HealthRecommendation] = []
    @Published var recoveryReadinessAssessment: RecoveryReadinessAssessment?
    @Published var recoveryRecommendations: [RecoveryRecommendation] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let healthIntelligenceService: HealthIntelligenceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(healthIntelligenceService: HealthIntelligenceServiceProtocol = DependencyContainer.shared.healthIntelligenceService) {
        self.healthIntelligenceService = healthIntelligenceService
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            do {
                // Load health intelligence data
                try await loadHealthIntelligenceData()
                
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
    
    private func loadHealthIntelligenceData() async throws {
        // This would typically fetch from the health intelligence service
        // For now, we'll create sample data
        
        await MainActor.run {
            // Sample health patterns
            healthPatterns = [
                HealthPattern(
                    id: UUID().uuidString,
                    type: .sleep,
                    score: 0.85,
                    trend: .improving,
                    description: "Sleep quality has improved over the last week",
                    insights: ["Consistent bedtime routine", "Deep sleep increased by 15%"]
                ),
                HealthPattern(
                    id: UUID().uuidString,
                    type: .heartRate,
                    score: 0.78,
                    trend: .stable,
                    description: "Heart rate patterns are consistent",
                    insights: ["Resting HR decreased by 3 BPM", "Recovery rate improved"]
                ),
                HealthPattern(
                    id: UUID().uuidString,
                    type: .activity,
                    score: 0.92,
                    trend: .improving,
                    description: "Activity levels are excellent",
                    insights: ["Daily steps target met", "Workout consistency improved"]
                ),
                HealthPattern(
                    id: UUID().uuidString,
                    type: .recovery,
                    score: 0.76,
                    trend: .stable,
                    description: "Recovery patterns are good",
                    insights: ["Sleep quality supports recovery", "Stress levels managed well"]
                )
            ]
            
            // Sample biometric correlations
            biometricCorrelations = [
                BiometricCorrelation(
                    id: UUID().uuidString,
                    type: .sleepPerformance,
                    strength: 0.87,
                    confidence: 0.89,
                    description: "Sleep quality strongly correlates with workout performance",
                    insights: ["Better sleep leads to 15% performance improvement", "Deep sleep crucial for recovery"]
                ),
                BiometricCorrelation(
                    id: UUID().uuidString,
                    type: .heartRateRecovery,
                    strength: 0.73,
                    confidence: 0.82,
                    description: "Heart rate recovery indicates training readiness",
                    insights: ["Faster HR recovery = better readiness", "HRV trends show improvement"]
                ),
                BiometricCorrelation(
                    id: UUID().uuidString,
                    type: .activitySleep,
                    strength: 0.68,
                    confidence: 0.75,
                    description: "Activity levels influence sleep quality",
                    insights: ["Moderate activity improves sleep", "Intense evening workouts may disrupt sleep"]
                )
            ]
            
            // Sample health insights
            healthInsights = [
                HealthInsight(
                    id: UUID().uuidString,
                    title: "Sleep Optimization Opportunity",
                    description: "Your sleep quality has improved, but there's potential for even better recovery",
                    category: .sleep,
                    priority: .medium,
                    confidence: 0.85,
                    recommendations: ["Maintain current bedtime routine", "Consider adding 30 minutes of sleep"]
                ),
                HealthInsight(
                    id: UUID().uuidString,
                    title: "Heart Rate Recovery Improvement",
                    description: "Your heart rate recovery has improved, indicating better cardiovascular fitness",
                    category: .heartRate,
                    priority: .low,
                    confidence: 0.78,
                    recommendations: ["Continue current training intensity", "Monitor recovery patterns"]
                )
            ]
            
            // Sample health recommendations
            healthRecommendations = [
                HealthRecommendation(
                    id: UUID().uuidString,
                    title: "Optimize Sleep Schedule",
                    description: "Maintain consistent 10:30 PM bedtime for optimal recovery",
                    category: .sleep,
                    priority: .medium,
                    impact: .high,
                    timeframe: 7 * 24 * 3600
                ),
                HealthRecommendation(
                    id: UUID().uuidString,
                    title: "Monitor Heart Rate Variability",
                    description: "Track HRV trends to optimize training intensity",
                    category: .heartRate,
                    priority: .low,
                    impact: .medium,
                    timeframe: 3 * 24 * 3600
                )
            ]
            
            // Sample recovery readiness assessment
            recoveryReadinessAssessment = RecoveryReadinessAssessment(
                userId: "user123",
                timestamp: Date(),
                readinessScore: 0.78,
                sleepQuality: 0.85,
                heartRateVariability: 0.72,
                muscleFatigue: 0.35,
                stressLevel: 0.28,
                recommendations: []
            )
            
            // Sample recovery recommendations
            recoveryRecommendations = [
                RecoveryRecommendation(
                    id: UUID().uuidString,
                    title: "Light Recovery Session",
                    description: "Consider a gentle yoga or stretching session today",
                    priority: .medium,
                    category: .activity
                ),
                RecoveryRecommendation(
                    id: UUID().uuidString,
                    title: "Sleep Optimization",
                    description: "Aim for 8 hours of sleep tonight for optimal recovery",
                    priority: .high,
                    category: .sleep
                )
            ]
        }
    }
    
    private func updateMetrics() {
        // Update performance metrics
        overallHealthScore = 0.78
        sleepQuality = 0.85
        recoveryReadiness = 0.78
        
        // Set trends
        healthScoreTrend = .improving
        sleepQualityTrend = .improving
        recoveryReadinessTrend = .stable
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Supporting Types

struct HealthPattern {
    let id: String
    let type: HealthPatternType
    let score: Double
    let trend: TrendDirection
    let description: String
    let insights: [String]
}

enum HealthPatternType: String, CaseIterable {
    case sleep = "Sleep"
    case heartRate = "Heart Rate"
    case activity = "Activity"
    case recovery = "Recovery"
    case stress = "Stress"
    case nutrition = "Nutrition"
}

struct BiometricCorrelation {
    let id: String
    let type: BiometricCorrelationType
    let strength: Double
    let confidence: Double
    let description: String
    let insights: [String]
}

enum BiometricCorrelationType: String, CaseIterable {
    case sleepPerformance = "Sleep-Performance"
    case heartRateRecovery = "HR-Recovery"
    case activitySleep = "Activity-Sleep"
    case stressRecovery = "Stress-Recovery"
    case nutritionRecovery = "Nutrition-Recovery"
    case formProgress = "Form-Progress"
}

// MARK: - Dependency Container Extension

extension DependencyContainer {
    static var shared: DependencyContainer {
        MainDependencyContainer()
    }
}

// MARK: - Preview

struct HealthIntelligenceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HealthIntelligenceDashboardView()
    }
}

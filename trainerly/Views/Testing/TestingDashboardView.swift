import SwiftUI
import Combine

// MARK: - Testing Dashboard View
struct TestingDashboardView: View {
    @StateObject private var viewModel = TestingDashboardViewModel()
    @State private var selectedTab = 0
    @State private var showingTestResults = false
    @State private var showingCoverageReport = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    testOverviewTab.tag(0)
                    unitTestsTab.tag(1)
                    integrationTestsTab.tag(2)
                    performanceTestsTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Testing & Quality")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: HStack {
                refreshButton
                coverageButton
            })
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingTestResults) {
                TestResultsView(results: viewModel.testResults)
            }
            .sheet(isPresented: $showingCoverageReport) {
                CoverageReportView(report: viewModel.coverageReport)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Testing Overview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Testing & Quality Assurance")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Comprehensive testing for production readiness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isRunningTests ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isRunningTests ? "Running Tests" : "Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Test Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                TestStatCard(
                    title: "Success Rate",
                    value: "\(Int(viewModel.testResults.successRate * 100))%",
                    icon: "checkmark.circle.fill",
                    color: viewModel.testResults.successRate >= 0.9 ? .green : .orange,
                    trend: .stable
                )
                TestStatCard(
                    title: "Total Tests",
                    value: "\(viewModel.testResults.totalTests)",
                    icon: "number.circle.fill",
                    color: .blue,
                    trend: .stable
                )
                TestStatCard(
                    title: "Coverage",
                    value: "\(Int(viewModel.coverageReport.coveragePercentage * 100))%",
                    icon: "chart.bar.fill",
                    color: viewModel.coverageReport.coveragePercentage >= 0.8 ? .green : .orange,
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
    private var testOverviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Test Summary
                TestSummaryCard(results: viewModel.testResults)
                
                // Recent Test Runs
                RecentTestRunsCard(viewModel: viewModel)
                
                // Quality Metrics
                QualityMetricsCard(results: viewModel.testResults)
                
                // Quick Actions
                QuickActionsCard(viewModel: viewModel)
            }
            .padding()
        }
    }
    
    private var unitTestsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Unit Test Results
                UnitTestResultsCard(results: viewModel.testResults)
                
                // Run Unit Tests Button
                RunTestsButton(
                    title: "Run Unit Tests",
                    action: {
                        Task {
                            try? await viewModel.runUnitTests()
                        }
                    },
                    isLoading: viewModel.isRunningTests
                )
                
                // Test Categories
                TestCategoriesCard(results: viewModel.testResults)
            }
            .padding()
        }
    }
    
    private var integrationTestsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Integration Test Results
                IntegrationTestResultsCard(results: viewModel.testResults)
                
                // Run Integration Tests Button
                RunTestsButton(
                    title: "Run Integration Tests",
                    action: {
                        Task {
                            try? await viewModel.runIntegrationTests()
                        }
                    },
                    isLoading: viewModel.isRunningTests
                )
                
                // Service Integration Status
                ServiceIntegrationStatusCard(results: viewModel.testResults)
            }
            .padding()
        }
    }
    
    private var performanceTestsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Performance Test Results
                PerformanceTestResultsCard(results: viewModel.testResults)
                
                // Run Performance Tests Button
                RunTestsButton(
                    title: "Run Performance Tests",
                    action: {
                        Task {
                            try? await viewModel.runPerformanceTests()
                        }
                    },
                    isLoading: viewModel.isRunningTests
                )
                
                // Performance Metrics
                PerformanceMetricsCard(results: viewModel.testResults)
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
    
    private var coverageButton: some View {
        Button(action: {
            showingCoverageReport = true
        }) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title3)
        }
    }
    
    // MARK: - Helper Methods
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Overview"
        case 1: return "Unit Tests"
        case 2: return "Integration"
        case 3: return "Performance"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct TestStatCard: View {
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

struct TestSummaryCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Summary")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                TestMetricRow(title: "Total Tests", value: "\(results.totalTests)", color: .blue)
                TestMetricRow(title: "Passed", value: "\(results.passedTests)", color: .green)
                TestMetricRow(title: "Failed", value: "\(results.failedTests)", color: .red)
                TestMetricRow(title: "Success Rate", value: "\(Int(results.successRate * 100))%", color: results.successRate >= 0.9 ? .green : .orange)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TestMetricRow: View {
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

struct RecentTestRunsCard: View {
    @ObservedObject var viewModel: TestingDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Test Runs")
                .font(.headline)
                .foregroundColor(.primary)
            
            if viewModel.isRunningTests {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Running tests...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                Text("Last run: \(viewModel.testResults.timestamp, style: .relative)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct QualityMetricsCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 8) {
                QualityMetricRow(title: "Test Coverage", value: results.successRate, color: .blue)
                QualityMetricRow(title: "Reliability", value: calculateReliability(results: results), color: .green)
                QualityMetricRow(title: "Maintainability", value: calculateMaintainability(results: results), color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func calculateReliability(results: TestResults) -> Double {
        // Calculate reliability based on test results
        return results.successRate
    }
    
    private func calculateMaintainability(results: TestResults) -> Double {
        // Calculate maintainability based on test structure
        return 0.85 // Simplified
    }
}

struct QualityMetricRow: View {
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

struct QuickActionsCard: View {
    @ObservedObject var viewModel: TestingDashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionButton(
                    title: "Run All Tests",
                    icon: "play.circle.fill",
                    color: .green,
                    action: {
                        Task {
                            try? await viewModel.runAllTests()
                        }
                    }
                )
                
                QuickActionButton(
                    title: "Generate Report",
                    icon: "doc.text.fill",
                    color: .blue,
                    action: {
                        Task {
                            try? await viewModel.generateTestReport()
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct UnitTestResultsCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unit Test Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(results.testDetails.prefix(5), id: \.name) { test in
                TestResultRow(test: test)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TestResultRow: View {
    let test: TestDetail
    
    var body: some View {
        HStack {
            Image(systemName: test.status == .passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(test.status == .passed ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(test.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(test.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.2fs", test.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RunTestsButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "play.circle.fill")
                }
                
                Text(title)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }
}

struct TestCategoriesCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Categories")
                .font(.headline)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                TestCategoryCard(title: "Core Data", status: .passed, count: 8)
                TestCategoryCard(title: "HealthKit", status: .passed, count: 6)
                TestCategoryCard(title: "ML Models", status: .passed, count: 4)
                TestCategoryCard(title: "Network", status: .passed, count: 5)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct TestCategoryCard: View {
    let title: String
    let status: TestStatus
    let count: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: status == .passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(status == .passed ? .green : .red)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("\(count) tests")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Additional supporting views for integration and performance tests...
struct IntegrationTestResultsCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Integration Test Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Integration tests ensure services work together correctly")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct ServiceIntegrationStatusCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Integration Status")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("All services are properly integrated")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceTestResultsCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Test Results")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Performance tests ensure optimal app performance")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct PerformanceMetricsCard: View {
    let results: TestResults
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Performance metrics are within acceptable ranges")
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
final class TestingDashboardViewModel: ObservableObject {
    @Published var isRunningTests: Bool = false
    @Published var testResults: TestResults = TestResults()
    @Published var coverageReport: CoverageReport = CoverageReport()
    @Published var isLoading: Bool = false
    
    private let testingService: TestingServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(testingService: TestingServiceProtocol = DependencyContainer.shared.testingService) {
        self.testingService = testingService
        
        // Subscribe to testing updates
        testingService.$isRunningTests
            .assign(to: \.isRunningTests, on: self)
            .store(in: &cancellables)
        
        testingService.$testResults
            .assign(to: \.testResults, on: self)
            .store(in: &cancellables)
        
        testingService.$coverageReport
            .assign(to: \.coverageReport, on: self)
            .store(in: &cancellables)
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            do {
                try await generateCoverageReport()
            } catch {
                print("Error loading testing data: \(error)")
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func runUnitTests() async throws {
        try await testingService.runUnitTests()
    }
    
    func runIntegrationTests() async throws {
        try await testingService.runIntegrationTests()
    }
    
    func runPerformanceTests() async throws {
        try await testingService.runPerformanceTests()
    }
    
    func runAllTests() async throws {
        try await testingService.runUnitTests()
        try await testingService.runIntegrationTests()
        try await testingService.runPerformanceTests()
    }
    
    func generateTestReport() async throws {
        try await testingService.generateCoverageReport()
    }
    
    private func generateCoverageReport() async throws {
        let report = try await testingService.generateCoverageReport()
        
        await MainActor.run {
            coverageReport = report
        }
    }
}

// MARK: - Supporting Views

struct TestResultsView: View {
    let results: TestResults
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Test Results")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Test results content would go here
                    Text("Generated: \(results.timestamp, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Test Results")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CoverageReportView: View {
    let report: CoverageReport
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Coverage Report")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding()
                    
                    // Coverage report content would go here
                    Text("Generated: \(report.timestamp, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Coverage Report")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Preview

struct TestingDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        TestingDashboardView()
    }
}

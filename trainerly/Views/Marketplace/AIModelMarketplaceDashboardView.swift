import SwiftUI
import Combine
import CoreML

// MARK: - AI Model Marketplace Dashboard View
struct AIModelMarketplaceDashboardView: View {
    @StateObject private var viewModel = AIModelMarketplaceDashboardViewModel()
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingFilters = false
    @State private var selectedCategory: ModelCategory?
    @State private var showingModelDetails = false
    @State private var selectedModel: MarketplaceModel?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                tabSelection
                TabView(selection: $selectedTab) {
                    discoverTab.tag(0)
                    myModelsTab.tag(1)
                    featuredTab.tag(2)
                    categoriesTab.tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("AI Model Marketplace")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: HStack {
                searchButton
                filterButton
                refreshButton
            })
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingModelDetails) {
                if let model = selectedModel {
                    ModelDetailsView(model: model, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterView(
                    selectedCategory: $selectedCategory,
                    filters: $viewModel.currentFilters
                )
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Marketplace Overview
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Model Marketplace")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Discover and install cutting-edge AI models for fitness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isMarketplaceEnabled ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(viewModel.isMarketplaceEnabled ? "Marketplace Active" : "Connecting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Search Bar
            searchBar
            
            // Marketplace Stats
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                MarketplaceStatCard(
                    title: "Available Models",
                    value: "\(viewModel.availableModels.count)",
                    icon: "brain.head.profile",
                    color: .blue,
                    trend: .stable
                )
                MarketplaceStatCard(
                    title: "My Models",
                    value: "\(viewModel.userModels.count)",
                    icon: "folder",
                    color: .green,
                    trend: .stable
                )
                MarketplaceStatCard(
                    title: "Featured",
                    value: "\(viewModel.featuredModels.count)",
                    icon: "star.fill",
                    color: .orange,
                    trend: .stable
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search AI models...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    Task {
                        try? await viewModel.searchModels(query: searchText)
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
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
    private var discoverTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Category Pills
                categoryPills
                
                // Models Grid
                modelsGrid
            }
            .padding()
        }
    }
    
    private var myModelsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if viewModel.userModels.isEmpty {
                    emptyMyModelsView
                } else {
                    userModelsList
                }
            }
            .padding()
        }
    }
    
    private var featuredTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                featuredModelsList
            }
            .padding()
        }
    }
    
    private var categoriesTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                categoriesGrid
            }
            .padding()
        }
    }
    
    // MARK: - Supporting Views
    
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ModelCategory.allCases, id: \.self) { category in
                    CategoryPill(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: {
                            selectedCategory = selectedCategory == category ? nil : category
                            Task {
                                try? await viewModel.discoverModels(category: selectedCategory)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var modelsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(viewModel.availableModels) { model in
                ModelCard(
                    model: model,
                    action: {
                        selectedModel = model
                        showingModelDetails = true
                    }
                )
            }
        }
    }
    
    private var emptyMyModelsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Models Installed")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Discover and install AI models from the marketplace to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Discover Models") {
                selectedTab = 0
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var userModelsList: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.userModels) { model in
                UserModelCard(model: model)
            }
        }
    }
    
    private var featuredModelsList: some View {
        LazyVStack(spacing: 16) {
            ForEach(viewModel.featuredModels) { model in
                FeaturedModelCard(
                    model: model,
                    action: {
                        selectedModel = model
                        showingModelDetails = true
                    }
                )
            }
        }
    }
    
    private var categoriesGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
            ForEach(ModelCategory.allCases, id: \.self) { category in
                CategoryCard(
                    category: category,
                    modelCount: viewModel.getModelCount(for: category),
                    action: {
                        selectedCategory = category
                        selectedTab = 0
                        Task {
                            try? await viewModel.discoverModels(category: category)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Buttons
    private var searchButton: some View {
        Button(action: {
            // Focus search bar
        }) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
        }
    }
    
    private var filterButton: some View {
        Button(action: {
            showingFilters = true
        }) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title3)
        }
    }
    
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
        case 0: return "Discover"
        case 1: return "My Models"
        case 2: return "Featured"
        case 3: return "Categories"
        default: return ""
        }
    }
}

// MARK: - Supporting Views

struct MarketplaceStatCard: View {
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

struct CategoryPill: View {
    let category: ModelCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.trainerlyPrimary : Color(.systemGray6))
                .cornerRadius(20)
        }
    }
}

struct ModelCard: View {
    let model: MarketplaceModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Model Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Text(model.category.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", model.rating))
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                        
                        Text(model.price.type.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Model Description
                Text(model.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                // Model Footer
                HStack {
                    Text(model.developer.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(formatFileSize(model.size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct UserModelCard: View {
    let model: UserModel
    
    var body: some View {
        HStack(spacing: 16) {
            // Model Icon
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.trainerlyPrimary)
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            // Model Info
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("v\(model.version) • \(model.category.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Installed \(model.installationDate, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Performance
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(model.performance.accuracy * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text("\(String(format: "%.2f", model.performance.inferenceTime))s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct FeaturedModelCard: View {
    let model: MarketplaceModel
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                // Featured Badge
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Featured")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Model Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(model.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(model.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Model Stats
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", model.rating))
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    Text("\(model.downloadCount) downloads")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
}

struct CategoryCard: View {
    let category: ModelCategory
    let modelCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 32))
                    .foregroundColor(.trainerlyPrimary)
                
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("\(modelCount) models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    private func categoryIcon(for category: ModelCategory) -> String {
        switch category {
        case .fitness: return "figure.run"
        case .nutrition: return "leaf.fill"
        case .recovery: return "bed.double.fill"
        case .formAnalysis: return "eye.fill"
        case .healthPrediction: return "heart.fill"
        case .workoutGeneration: return "dumbbell.fill"
        case .emotionalIntelligence: return "brain.head.profile"
        case .biometricAnalysis: return "waveform.path.ecg"
        case .socialFitness: return "person.2.fill"
        case .gamification: return "gamecontroller.fill"
        }
    }
}

// MARK: - Filter View

struct FilterView: View {
    @Binding var selectedCategory: ModelCategory?
    @Binding var filters: ModelFilters
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        Text("All Categories").tag(nil as ModelCategory?)
                        ForEach(ModelCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category as ModelCategory?)
                        }
                    }
                }
                
                Section("Price") {
                    Picker("Price Range", selection: $filters.priceRange) {
                        Text("Any Price").tag(nil as PriceRange?)
                        ForEach(PriceRange.allCases, id: \.self) { priceRange in
                            Text(priceRange.rawValue).tag(priceRange as PriceRange?)
                        }
                    }
                }
                
                Section("Rating") {
                    HStack {
                        Text("Minimum Rating")
                        Spacer()
                        Text("\(Int(filters.rating ?? 0))+")
                    }
                    
                    Slider(value: Binding(
                        get: { filters.rating ?? 0 },
                        set: { filters.rating = $0 }
                    ), in: 0...5, step: 0.5)
                }
                
                Section("Sort By") {
                    Picker("Sort By", selection: $filters.sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    
                    Picker("Sort Order", selection: $filters.sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Reset") {
                    resetFilters()
                },
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
    
    private func resetFilters() {
        selectedCategory = nil
        filters = ModelFilters(
            category: nil,
            priceRange: nil,
            rating: nil,
            size: nil,
            requirements: nil,
            tags: nil,
            sortBy: .relevance,
            sortOrder: .descending
        )
    }
}

// MARK: - Model Details View

struct ModelDetailsView: View {
    let model: MarketplaceModel
    @ObservedObject var viewModel: AIModelMarketplaceDashboardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDownload = false
    @State private var downloadProgress = 0.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Model Header
                    modelHeader
                    
                    // Model Description
                    modelDescription
                    
                    // Technical Specs
                    technicalSpecs
                    
                    // Developer Info
                    developerInfo
                    
                    // Reviews
                    reviewsSection
                    
                    // Download Button
                    downloadButton
                }
                .padding()
            }
            .navigationTitle("Model Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private var modelHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.name)
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Text(model.category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", model.rating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("(\(model.reviewCount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var modelDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            
            Text(model.description)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
    
    private var technicalSpecs: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Technical Specifications")
                .font(.headline)
            
            VStack(spacing: 4) {
                SpecRow(title: "Version", value: model.version)
                SpecRow(title: "Size", value: formatFileSize(model.size))
                SpecRow(title: "Requirements", value: model.requirements.minimumIOSVersion)
            }
        }
    }
    
    private var developerInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Developer")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(model.developer.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(model.developer.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reviews")
                .font(.headline)
            
            Text("No reviews yet")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var downloadButton: some View {
        Button(action: {
            showingDownload = true
            Task {
                try? await downloadModel()
            }
        }) {
            HStack {
                if showingDownload {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle.fill")
                }
                
                Text(showingDownload ? "Downloading..." : "Download Model")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.trainerlyPrimary)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(showingDownload)
    }
    
    private func downloadModel() async throws {
        let result = try await viewModel.downloadModel(modelId: model.id)
        
        await MainActor.run {
            showingDownload = false
            dismiss()
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SpecRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - View Model

@MainActor
final class AIModelMarketplaceDashboardViewModel: ObservableObject {
    @Published var isMarketplaceEnabled: Bool = false
    @Published var availableModels: [MarketplaceModel] = []
    @Published var userModels: [UserModel] = []
    @Published var featuredModels: [MarketplaceModel] = []
    @Published var isLoading: Bool = false
    @Published var currentFilters = ModelFilters(
        category: nil,
        priceRange: nil,
        rating: nil,
        size: nil,
        requirements: nil,
        tags: nil,
        sortBy: .relevance,
        sortOrder: .descending
    )
    
    private let marketplaceService: AIModelMarketplaceServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(marketplaceService: AIModelMarketplaceServiceProtocol = DependencyContainer.shared.aiModelMarketplaceService) {
        self.marketplaceService = marketplaceService
        
        // Subscribe to marketplace updates
        marketplaceService.$isMarketplaceEnabled
            .assign(to: \.isMarketplaceEnabled, on: self)
            .store(in: &cancellables)
        
        marketplaceService.$availableModels
            .assign(to: \.availableModels, on: self)
            .store(in: &cancellables)
        
        marketplaceService.$userModels
            .assign(to: \.userModels, on: self)
            .store(in: &cancellables)
        
        marketplaceService.$featuredModels
            .assign(to: \.featuredModels, on: self)
            .store(in: &cancellables)
    }
    
    func loadData() {
        isLoading = true
        
        Task {
            // Load marketplace data
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    func searchModels(query: String) async throws {
        let results = try await marketplaceService.searchModels(query: query, filters: currentFilters)
        
        await MainActor.run {
            availableModels = results
        }
    }
    
    func discoverModels(category: ModelCategory?) async throws {
        let models = try await marketplaceService.discoverModels(category: category)
        
        await MainActor.run {
            availableModels = models
        }
    }
    
    func getModelCount(for category: ModelCategory) -> Int {
        return availableModels.filter { $0.category == category }.count
    }
}

// MARK: - Preview

struct AIModelMarketplaceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AIModelMarketplaceDashboardView()
    }
}

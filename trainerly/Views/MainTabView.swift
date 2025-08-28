import SwiftUI

// Import the new views
@_exported import class UIKit.UIImage

// MARK: - Main Tab View
struct MainTabView: View {
    
    // MARK: - Properties
    @StateObject private var coordinator: MainTabCoordinator
    @State private var selectedTab: Tab = .home
    
    // MARK: - Initialization
    init(coordinator: MainTabCoordinator) {
        self._coordinator = StateObject(wrappedValue: coordinator)
    }
    
    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home Tab
            HomeView(coordinator: coordinator.createHomeCoordinator())
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(Tab.home)
            
            // Workouts Tab
            WorkoutsView(coordinator: coordinator.createWorkoutsCoordinator())
                .tabItem {
                    Image(systemName: "dumbbell.fill")
                    Text("Workouts")
                }
                .tag(Tab.workouts)
            
            // AI Coach Tab
            AICoachChatView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Coach")
                }
                .tag(Tab.aiCoach)
            
            // Progress Tab
            ProgressView(coordinator: coordinator.createProgressCoordinator())
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }
                .tag(Tab.progress)
            
                               // Gamification Tab
                   GamificationDashboardView()
                       .tabItem {
                           Image(systemName: "trophy.fill")
                           Text("Gamification")
                       }
                       .tag(Tab.gamification)
                   
                               // Advanced Analytics Tab
            AdvancedAnalyticsDashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Analytics")
                }
                .tag(Tab.analytics)
            
            // ML Integration Tab
            MLIntegrationDashboardView()
                .tabItem {
                    Image(systemName: "cpu")
                    Text("ML")
                }
                .tag(Tab.mlIntegration)
            
            // Health Intelligence Tab
            HealthIntelligenceDashboardView()
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Health")
                }
                .tag(Tab.healthIntelligence)
            
            // Performance Tab
            PerformanceDashboardView()
                .tabItem {
                    Image(systemName: "speedometer")
                    Text("Performance")
                }
                .tag(Tab.performance)
            
            // Testing Tab
            TestingDashboardView()
                .tabItem {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Testing")
                }
                .tag(Tab.testing)
            
            // Real ML Tab
            RealMLDashboardView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Real ML")
                }
                .tag(Tab.realML)
            
            // Advanced ML Features Tab
            AdvancedMLFeaturesDashboardView()
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Advanced ML")
                }
                .tag(Tab.advancedMLFeatures)
            
            // AI Model Marketplace Tab
            AIModelMarketplaceDashboardView()
                .tabItem {
                    Image(systemName: "cart.fill")
                    Text("Marketplace")
                }
                .tag(Tab.marketplace)
            
            // Quantum ML Tab
            Text("Quantum ML Dashboard")
                .tabItem {
                    Image(systemName: "atom")
                    Text("Quantum ML")
                }
                .tag(Tab.quantumML)
            
            // Brain-Computer Interface Tab
            Text("BCI Dashboard")
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("BCI")
                }
                .tag(Tab.bci)
            
            // Global AI Hub Tab
            Text("Global AI Hub")
                .tabItem {
                    Image(systemName: "globe")
                    Text("Global Hub")
                }
                .tag(Tab.globalHub)
            
            // Quantum-Brain Interface Tab
            Text("Quantum-Brain Interface")
                .tabItem {
                    Image(systemName: "brain.head.profile.fill")
                    Text("Quantum-Brain")
                }
                .tag(Tab.quantumBrain)
            
            // Multidimensional Fitness Tab
            Text("Multidimensional Fitness")
                .tabItem {
                    Image(systemName: "cube.transparent")
                    Text("4D/5D Fitness")
                }
                .tag(Tab.multidimensional)
            
            // Universal AI Consciousness Tab
            Text("Universal AI Consciousness")
                .tabItem {
                    Image(systemName: "infinity")
                    Text("Universal AI")
                }
                .tag(Tab.universalConsciousness)
            
            // Cosmic Fitness Tab
            Text("Cosmic Fitness")
                .tabItem {
                    Image(systemName: "sparkles")
                    Text("Cosmic")
                }
                .tag(Tab.cosmicFitness)
            
            // Multiversal Fitness Tab
            Text("Multiversal Fitness")
                .tabItem {
                    Image(systemName: "network")
                    Text("Multiversal")
                }
                .tag(Tab.multiversalFitness)
            
            // Deployment & Launch Tab
            Text("Deployment & Launch")
                .tabItem {
                    Image(systemName: "rocket")
                    Text("Launch")
                }
                .tag(Tab.deployment)
            
            // Evolution & Growth Tab
            Text("Evolution & Growth")
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Evolution")
                }
                .tag(Tab.evolution)
            
            // Social Tab
            SocialView(coordinator: coordinator.createSocialCoordinator())
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("Social")
                }
                .tag(Tab.social)
            
            // Profile Tab
            ProfileView(coordinator: coordinator.createProfileCoordinator())
                .tabItem {
                    Image(systemName: "person.circle.fill")
                    Text("Profile")
                }
                .tag(Tab.profile)
        }
        .accentColor(.trainerlyPrimary)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    // MARK: - Setup
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.systemGray
        ]
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.trainerlyPrimary
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor.trainerlyPrimary
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// MARK: - Tab Enum
               enum Tab: Int, CaseIterable {
            case home = 0
            case workouts = 1
            case aiCoach = 2
            case progress = 3
            case gamification = 4
            case analytics = 5
            case mlIntegration = 6
            case healthIntelligence = 7
            case performance = 8
            case testing = 9
            case realML = 10
            case advancedMLFeatures = 11
            case marketplace = 12
            case quantumML = 13
            case bci = 14
            case globalHub = 15
            case quantumBrain = 16
            case multidimensional = 17
            case universalConsciousness = 18
            case cosmicFitness = 19
            case multiversalFitness = 20
            case deployment = 21
            case evolution = 22
            case social = 23
            case profile = 24
        }

// MARK: - Placeholder Views (will be implemented next)
struct HomeView: View {
    let coordinator: HomeCoordinator
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Good morning! 👋")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    
                    Text("Ready for today's workout?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Quick Stats
                QuickStatsView()
                
                // Today's Workout
                TodaysWorkoutCard()
                
                // AI Coach Message
                AICoachMessageCard()
                
                Spacer()
            }
            .navigationTitle("Trainerly")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct WorkoutsView: View {
    let coordinator: WorkoutsCoordinator
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Workouts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your personalized workout library")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProgressView: View {
    let coordinator: ProgressCoordinator
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Progress")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your fitness journey")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SocialView: View {
    let coordinator: SocialCoordinator
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Social")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Connect with fitness friends")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileView: View {
    let coordinator: ProfileCoordinator
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Profile")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Manage your account")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Home Tab Components
struct QuickStatsView: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Stats")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All") {
                    // Navigate to detailed stats
                }
                .font(.subheadline)
                .foregroundColor(.trainerlyPrimary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "Steps", value: "8,432", icon: "figure.walk", color: .blue)
                StatCard(title: "Calories", value: "324", icon: "flame.fill", color: .orange)
                StatCard(title: "Exercise", value: "45m", icon: "clock.fill", color: .green)
                StatCard(title: "Heart Rate", value: "72", icon: "heart.fill", color: .red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct TodaysWorkoutCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Workout")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Upper Body Strength")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Start") {
                    // Start workout
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.trainerlyPrimary)
                .foregroundColor(.white)
                .cornerRadius(20)
                .fontWeight(.semibold)
            }
            
            HStack(spacing: 20) {
                WorkoutDetail(icon: "clock", value: "45 min", label: "Duration")
                WorkoutDetail(icon: "dumbbell", value: "8", label: "Exercises")
                WorkoutDetail(icon: "flame", value: "280", label: "Calories")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct WorkoutDetail: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.trainerlyPrimary)
                .font(.title3)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AICoachMessageCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .foregroundColor(.trainerlyPrimary)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Coach")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Great job yesterday! Ready to crush today's upper body session? 💪")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Color Extensions
extension Color {
    static let trainerlyPrimary = Color("TrainerlyPrimary", default: .blue)
}

extension UIColor {
    static let trainerlyPrimary = UIColor(named: "TrainerlyPrimary") ?? UIColor.systemBlue
}

// MARK: - Preview
#Preview {
    MainTabView(coordinator: MainTabCoordinator(dependencyContainer: MainDependencyContainer()))
}

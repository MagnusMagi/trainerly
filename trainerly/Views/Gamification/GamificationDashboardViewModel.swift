import Foundation
import Combine
import SwiftUI

// MARK: - Gamification Dashboard ViewModel
@MainActor
final class GamificationDashboardViewModel: ObservableObject {
    @Published var currentXP: Int = 0
    @Published var currentLevel: UserLevel = .beginner
    @Published var currentRank: UserRank = .bronze
    @Published var currentStreak: Int = 0
    @Published var achievementsCount: Int = 0
    @Published var weeklyGoals: [WeeklyGoal] = []
    @Published var recentActivities: [Activity] = []
    @Published var milestones: [Milestone] = []
    @Published var recentAchievements: [Achievement] = []
    @Published var upcomingAchievements: [Achievement] = []
    @Published var leaderboardEntries: [LeaderboardEntry] = []
    @Published var friends: [User] = []
    @Published var groups: [Group] = []
    @Published var challenges: [Challenge] = []
    @Published var selectedLeaderboardScope: LeaderboardScope = .friends
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let gamificationService: GamificationServiceProtocol
    private let socialFeaturesService: SocialFeaturesServiceProtocol
    private let userRepository: UserRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Computed properties
    var levelProgress: Double {
        let currentLevelXP = getXPForLevel(currentLevel)
        let nextLevelXP = getXPForNextLevel(currentLevel)
        let progressInLevel = Double(currentXP - currentLevelXP)
        let levelRange = Double(nextLevelXP - currentLevelXP)
        return progressInLevel / levelRange
    }
    
    var xpToNextLevel: Int {
        let nextLevelXP = getXPForNextLevel(currentLevel)
        return nextLevelXP - currentXP
    }
    
    init(
        gamificationService: GamificationServiceProtocol = DependencyContainer.shared.gamificationService,
        socialFeaturesService: SocialFeaturesServiceProtocol = DependencyContainer.shared.socialFeaturesService,
        userRepository: UserRepositoryProtocol = DependencyContainer.shared.userRepository
    ) {
        self.gamificationService = gamificationService
        self.socialFeaturesService = socialFeaturesService
        self.userRepository = userRepository
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func loadData() {
        Task {
            isLoading = true
            
            do {
                let currentUser = try await userRepository.getCurrentUser()
                
                // Load gamification data
                let progress = try await gamificationService.getUserProgress(for: currentUser.id)
                updateGamificationData(progress)
                
                // Load achievements
                let achievements = try await gamificationService.checkAchievements(for: currentUser.id)
                updateAchievements(achievements)
                
                // Load leaderboard
                let leaderboard = try await gamificationService.getLeaderboard(scope: selectedLeaderboardScope, limit: 20)
                leaderboardEntries = leaderboard
                
                // Load social data
                let socialStats = try await socialFeaturesService.getSocialStats(for: currentUser.id)
                updateSocialData(socialStats)
                
                // Load weekly goals
                let goals = try await gamificationService.getWeeklyGoals(for: currentUser.id)
                weeklyGoals = goals
                
                // Load friends and groups
                await loadSocialData()
                
                // Load challenges
                await loadChallenges()
                
                // Generate sample data for demo
                generateSampleData()
                
            } catch {
                await handleError(error)
            }
            
            isLoading = false
        }
    }
    
    func addWeeklyGoal() {
        let newGoal = WeeklyGoal(
            id: UUID().uuidString,
            title: "New Goal",
            description: "Set your fitness target for this week",
            target: 5,
            current: 0,
            unit: "workouts",
            xpReward: 100,
            isCompleted: false,
            weekStart: Date()
        )
        
        weeklyGoals.append(newGoal)
        
        Task {
            do {
                let currentUser = try await userRepository.getCurrentUser()
                try await gamificationService.updateWeeklyGoal(newGoal, for: currentUser.id)
            } catch {
                await handleError(error)
            }
        }
    }
    
    func updateWeeklyGoal(_ goal: WeeklyGoal) {
        if let index = weeklyGoals.firstIndex(where: { $0.id == goal.id }) {
            weeklyGoals[index] = goal
            
            Task {
                do {
                    let currentUser = try await userRepository.getCurrentUser()
                    try await gamificationService.updateWeeklyGoal(goal, for: currentUser.id)
                } catch {
                    await handleError(error)
                }
            }
        }
    }
    
    func addFriend() {
        // This would typically show a friend search/add interface
        print("Add friend functionality")
    }
    
    func createGroup() {
        // This would typically show a group creation interface
        print("Create group functionality")
    }
    
    func joinChallenge() {
        // This would typically show available challenges
        print("Join challenge functionality")
    }
    
    func achievementProgress(for category: AchievementCategory) -> Double {
        let categoryAchievements = recentAchievements.filter { achievement in
            switch category {
            case .workout:
                return achievement.type == .firstWorkout || achievement.type == .personalRecord
            case .streak:
                return achievement.type == .streak
            case .social:
                return achievement.type == .socialButterfly
            case .form:
                return achievement.type == .formMaster
            }
        }
        
        let totalPossible = 5 // Assuming 5 achievements per category
        return Double(categoryAchievements.count) / Double(totalPossible)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to gamification service state changes
        gamificationService.$currentUserXP
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentXP, on: self)
            .store(in: &cancellables)
        
        gamificationService.$currentUserLevel
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentLevel, on: self)
            .store(in: &cancellables)
        
        gamificationService.$currentUserRank
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentRank, on: self)
            .store(in: &cancellables)
        
        gamificationService.$currentUserAchievements
            .receive(on: DispatchQueue.main)
            .assign(to: \.achievementsCount, on: self)
            .store(in: &cancellables)
        
        // Bind to social features service state changes
        socialFeaturesService.$currentUserFriends
            .receive(on: DispatchQueue.main)
            .assign(to: \.friends, on: self)
            .store(in: &cancellables)
        
        socialFeaturesService.$currentUserGroups
            .receive(on: DispatchQueue.main)
            .assign(to: \.groups, on: self)
            .store(in: &cancellables)
        
        socialFeaturesService.$currentUserChallenges
            .receive(on: DispatchQueue.main)
            .assign(to: \.challenges, on: self)
            .store(in: &cancellables)
    }
    
    private func updateGamificationData(_ progress: UserProgress) {
        currentXP = progress.totalXP
        currentLevel = progress.currentLevel
        currentRank = progress.currentRank
        currentStreak = progress.currentStreak
        achievementsCount = progress.achievementsCount
        
        // Update milestones
        milestones = [progress.nextMilestone]
    }
    
    private func updateAchievements(_ achievements: [Achievement]) {
        // Separate recent and upcoming achievements
        let unlocked = achievements.filter { $0.isUnlocked }
        let locked = achievements.filter { !$0.isUnlocked }
        
        recentAchievements = unlocked.sorted { $0.unlockedDate > $1.unlockedDate }
        upcomingAchievements = locked.prefix(5).map { $0 }
    }
    
    private func updateSocialData(_ stats: SocialStats) {
        // Update social-related data
        // This would typically update friends, groups, etc.
    }
    
    private func loadSocialData() async {
        do {
            let currentUser = try await userRepository.getCurrentUser()
            
            // Load friends
            // This would typically come from the social service
            // For now, we'll use sample data
            
            // Load groups
            // This would typically come from the social service
            // For now, we'll use sample data
            
        } catch {
            await handleError(error)
        }
    }
    
    private func loadChallenges() async {
        do {
            let currentUser = try await userRepository.getCurrentUser()
            
            // Load challenges
            // This would typically come from the gamification service
            // For now, we'll use sample data
            
        } catch {
            await handleError(error)
        }
    }
    
    private func generateSampleData() {
        // Generate sample weekly goals
        if weeklyGoals.isEmpty {
            weeklyGoals = [
                WeeklyGoal(
                    id: "1",
                    title: "Workout Consistency",
                    description: "Complete 4 workouts this week",
                    target: 4,
                    current: 2,
                    unit: "workouts",
                    xpReward: 150,
                    isCompleted: false,
                    weekStart: Date()
                ),
                WeeklyGoal(
                    id: "2",
                    title: "Cardio Training",
                    description: "Complete 3 cardio sessions",
                    target: 3,
                    current: 1,
                    unit: "sessions",
                    xpReward: 100,
                    isCompleted: false,
                    weekStart: Date()
                )
            ]
        }
        
        // Generate sample recent activities
        if recentActivities.isEmpty {
            recentActivities = [
                Activity(
                    title: "Workout Completed",
                    description: "Upper body strength training",
                    icon: "dumbbell.fill",
                    color: .blue,
                    xpGained: 75,
                    timestamp: Date().addingTimeInterval(-3600)
                ),
                Activity(
                    title: "Streak Extended",
                    description: "7-day workout streak maintained",
                    icon: "flame.fill",
                    color: .orange,
                    xpGained: 50,
                    timestamp: Date().addingTimeInterval(-7200)
                ),
                Activity(
                    title: "Achievement Unlocked",
                    description: "First Steps achievement earned",
                    icon: "star.fill",
                    color: .purple,
                    xpGained: 100,
                    timestamp: Date().addingTimeInterval(-10800)
                )
            ]
        }
        
        // Generate sample friends
        if friends.isEmpty {
            friends = [
                User(
                    id: "friend1",
                    profile: UserProfile(
                        firstName: "Sarah",
                        lastName: "Johnson",
                        email: "sarah@example.com",
                        age: 28,
                        weight: 65.0,
                        height: 165.0,
                        fitnessLevel: .intermediate,
                        goals: [.strength, .endurance],
                        activityLevel: .moderate,
                        primaryMuscleGroup: .fullBody,
                        avatarURL: nil
                    ),
                    preferences: UserPreferences(
                        availableEquipment: [.dumbbells, .resistanceBands],
                        preferredLocation: .home,
                        dietaryRestrictions: [.vegetarian],
                        notificationPreferences: NotificationPreferences()
                    ),
                    totalXP: 2500,
                    level: .intermediate,
                    rank: .silver,
                    achievements: [],
                    friends: [],
                    weeklyGoals: []
                ),
                User(
                    id: "friend2",
                    profile: UserProfile(
                        firstName: "Mike",
                        lastName: "Chen",
                        email: "mike@example.com",
                        age: 32,
                        weight: 80.0,
                        height: 180.0,
                        fitnessLevel: .advanced,
                        goals: [.strength, .muscleGain],
                        activityLevel: .high,
                        primaryMuscleGroup: .upperBody,
                        avatarURL: nil
                    ),
                    preferences: UserPreferences(
                        availableEquipment: [.barbell, .bench, .rack],
                        preferredLocation: .gym,
                        dietaryRestrictions: [],
                        notificationPreferences: NotificationPreferences()
                    ),
                    totalXP: 4500,
                    level: .advanced,
                    rank: .gold,
                    achievements: [],
                    friends: [],
                    weeklyGoals: []
                )
            ]
        }
        
        // Generate sample groups
        if groups.isEmpty {
            groups = [
                Group(
                    id: "group1",
                    name: "Morning Warriors",
                    description: "Early bird fitness enthusiasts",
                    type: .general,
                    maxMembers: 50,
                    members: ["user1", "friend1", "friend2"],
                    createdBy: "user1",
                    createdAt: Date().addingTimeInterval(-86400 * 7),
                    isPrivate: false
                ),
                Group(
                    id: "group2",
                    name: "Strength Squad",
                    description: "Focus on building strength and muscle",
                    type: .strength,
                    maxMembers: 30,
                    members: ["user1", "friend2"],
                    createdBy: "friend2",
                    createdAt: Date().addingTimeInterval(-86400 * 3),
                    isPrivate: true
                )
            ]
        }
        
        // Generate sample challenges
        if challenges.isEmpty {
            challenges = [
                Challenge(
                    id: "challenge1",
                    title: "30-Day Fitness Challenge",
                    description: "Complete a workout every day for 30 days",
                    type: .workoutStreak,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86400 * 30),
                    maxParticipants: 100,
                    participants: ["user1", "friend1", "friend2"],
                    xpReward: 500,
                    requirements: ChallengeRequirements(
                        workoutCount: 30,
                        distance: nil,
                        calories: nil,
                        strengthGoal: nil,
                        duration: nil
                    ),
                    createdBy: "user1",
                    createdAt: Date()
                ),
                Challenge(
                    id: "challenge2",
                    title: "Distance Runner",
                    description: "Run 100km this month",
                    type: .distance,
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(86400 * 30),
                    maxParticipants: 50,
                    participants: ["user1", "friend1"],
                    xpReward: 300,
                    requirements: ChallengeRequirements(
                        workoutCount: nil,
                        distance: 100.0,
                        calories: nil,
                        strengthGoal: nil,
                        duration: nil
                    ),
                    createdBy: "friend1",
                    createdAt: Date()
                )
            ]
        }
    }
    
    private func getXPForLevel(_ level: UserLevel) -> Int {
        switch level {
        case .beginner:
            return 0
        case .intermediate:
            return 1000
        case .advanced:
            return 5000
        case .expert:
            return 15000
        case .master:
            return 50000
        }
    }
    
    private func getXPForNextLevel(_ level: UserLevel) -> Int {
        switch level {
        case .beginner:
            return 1000
        case .intermediate:
            return 5000
        case .advanced:
            return 15000
        case .expert:
            return 50000
        case .master:
            return 100000
        }
    }
    
    private func handleError(_ error: Error) async {
        errorMessage = error.localizedDescription
        showingError = true
    }
}

// MARK: - Dependency Container Extension
extension DependencyContainer {
    static var shared: DependencyContainer {
        // This would typically come from your app's dependency injection container
        // For now, return a placeholder
        fatalError("DependencyContainer.shared not implemented")
    }
}

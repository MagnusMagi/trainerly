import Foundation
import Combine

// MARK: - Gamification Service Protocol
protocol GamificationServiceProtocol: ObservableObject {
    var currentUserXP: Int { get }
    var currentUserLevel: UserLevel { get }
    var currentUserAchievements: [Achievement] { get }
    var currentUserRank: UserRank { get }
    
    func awardXP(_ amount: Int, for action: XPAction, userId: String) async throws
    func checkAchievements(for userId: String) async throws -> [Achievement]
    func unlockAchievement(_ achievement: Achievement, for userId: String) async throws
    func getLeaderboard(scope: LeaderboardScope, limit: Int) async throws -> [LeaderboardEntry]
    func createChallenge(_ challenge: Challenge) async throws
    func joinChallenge(_ challengeId: String, userId: String) async throws
    func completeChallenge(_ challengeId: String, userId: String) async throws
    func getUserProgress(for userId: String) async throws -> UserProgress
    func getDailyStreak(for userId: String) async throws -> Int
    func getWeeklyGoals(for userId: String) async throws -> [WeeklyGoal]
    func updateWeeklyGoal(_ goal: WeeklyGoal, for userId: String) async throws
}

// MARK: - Gamification Service
final class GamificationService: NSObject, GamificationServiceProtocol {
    @Published var currentUserXP: Int = 0
    @Published var currentUserLevel: UserLevel = .beginner
    @Published var currentUserAchievements: [Achievement] = []
    @Published var currentUserRank: UserRank = .bronze
    
    private let userRepository: UserRepositoryProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let progressAnalyticsService: ProgressAnalyticsServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    private var xpMultipliers: [XPAction: Double] = [:]
    private var achievementDefinitions: [AchievementType: AchievementDefinition] = [:]
    
    init(
        userRepository: UserRepositoryProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        progressAnalyticsService: ProgressAnalyticsServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        self.progressAnalyticsService = progressAnalyticsService
        self.cacheService = cacheService
        
        super.init()
        
        setupXPMultipliers()
        setupAchievementDefinitions()
    }
    
    // MARK: - Public Methods
    
    func awardXP(_ amount: Int, for action: XPAction, userId: String) async throws {
        let multiplier = xpMultipliers[action] ?? 1.0
        let finalXP = Int(Double(amount) * multiplier)
        
        // Update user XP in repository
        try await userRepository.addXP(finalXP, for: userId)
        
        // Update local state if this is the current user
        if let currentUser = try? await userRepository.getCurrentUser(),
           currentUser.id == userId {
            currentUserXP += finalXP
            currentUserLevel = calculateUserLevel(xp: currentUserXP)
            currentUserRank = calculateUserRank(xp: currentUserXP)
        }
        
        // Check for level up
        if let levelUp = checkForLevelUp(userId: userId) {
            try await handleLevelUp(levelUp, for: userId)
        }
        
        // Check for achievements
        let newAchievements = try await checkAchievements(for: userId)
        for achievement in newAchievements {
            try await unlockAchievement(achievement, for: userId)
        }
    }
    
    func checkAchievements(for userId: String) async throws -> [Achievement] {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let progress = try await progressAnalyticsService.getProgressOverview(for: userId)
        
        var unlockedAchievements: [Achievement] = []
        
        for (type, definition) in achievementDefinitions {
            if !user.achievements.contains(where: { $0.type == type }) {
                if let achievement = try await checkAchievementCondition(
                    type: type,
                    definition: definition,
                    user: user,
                    workouts: workouts,
                    progress: progress
                ) {
                    unlockedAchievements.append(achievement)
                }
            }
        }
        
        return unlockedAchievements
    }
    
    func unlockAchievement(_ achievement: Achievement, for userId: String) async throws {
        // Add achievement to user
        try await userRepository.addAchievement(achievement, for: userId)
        
        // Award bonus XP for achievement
        let bonusXP = achievement.xpReward
        try await awardXP(bonusXP, for: .achievement, userId: userId)
        
        // Update local state if this is the current user
        if let currentUser = try? await userRepository.getCurrentUser(),
           currentUser.id == userId {
            currentUserAchievements.append(achievement)
        }
        
        // Send notification
        // This would typically go through a notification service
        print("🏆 Achievement Unlocked: \(achievement.title) - +\(bonusXP) XP!")
    }
    
    func getLeaderboard(scope: LeaderboardScope, limit: Int) async throws -> [LeaderboardEntry] {
        let cacheKey = "leaderboard_\(scope.rawValue)_\(limit)"
        
        // Check cache first
        if let cached = cacheService.get(key: cacheKey) as? [LeaderboardEntry] {
            return cached
        }
        
        let users = try await userRepository.getUsers(limit: limit)
        let entries = users.enumerated().compactMap { index, user in
            LeaderboardEntry(
                rank: index + 1,
                userId: user.id,
                username: user.profile.firstName + " " + user.profile.lastName,
                xp: user.totalXP,
                level: user.level,
                avatar: user.profile.avatarURL
            )
        }.sorted { $0.xp > $1.xp }
        
        // Cache the result
        cacheService.set(entries, for: cacheKey, expiration: 300) // 5 minutes
        
        return entries
    }
    
    func createChallenge(_ challenge: Challenge) async throws {
        // Validate challenge
        guard challenge.startDate > Date() else {
            throw GamificationError.invalidChallengeDate
        }
        
        guard challenge.participants.count <= challenge.maxParticipants else {
            throw GamificationError.challengeFull
        }
        
        // Save challenge to repository
        try await userRepository.createChallenge(challenge)
        
        // Notify participants
        for participantId in challenge.participants {
            // This would typically go through a notification service
            print("🎯 Challenge Created: \(challenge.title) - Notifying \(participantId)")
        }
    }
    
    func joinChallenge(_ challengeId: String, userId: String) async throws {
        let challenge = try await userRepository.getChallenge(id: challengeId)
        
        guard challenge.participants.count < challenge.maxParticipants else {
            throw GamificationError.challengeFull
        }
        
        guard !challenge.participants.contains(userId) else {
            throw GamificationError.alreadyParticipating
        }
        
        // Add user to challenge
        try await userRepository.joinChallenge(challengeId, userId: userId)
        
        // Award joining XP
        try await awardXP(50, for: .challengeJoin, userId: userId)
    }
    
    func completeChallenge(_ challengeId: String, userId: String) async throws {
        let challenge = try await userRepository.getChallenge(id: challengeId)
        
        guard challenge.participants.contains(userId) else {
            throw GamificationError.notParticipating
        }
        
        // Mark challenge as completed
        try await userRepository.completeChallenge(challengeId, userId: userId)
        
        // Award completion XP
        let completionXP = challenge.xpReward
        try await awardXP(completionXP, for: .challengeComplete, userId: userId)
        
        // Check for challenge-specific achievements
        if let achievement = checkChallengeAchievement(challenge: challenge, userId: userId) {
            try await unlockAchievement(achievement, for: userId)
        }
    }
    
    func getUserProgress(for userId: String) async throws -> UserProgress {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 30)
        let achievements = try await checkAchievements(for: userId)
        
        let weeklyWorkouts = workouts.filter { 
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
        
        let monthlyWorkouts = workouts.filter { 
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.count
        
        let streak = try await getDailyStreak(for: userId)
        
        return UserProgress(
            userId: userId,
            totalXP: user.totalXP,
            currentLevel: user.level,
            currentRank: user.rank,
            weeklyWorkouts: weeklyWorkouts,
            monthlyWorkouts: monthlyWorkouts,
            currentStreak: streak,
            achievementsCount: user.achievements.count,
            recentAchievements: achievements.prefix(3).map { $0 },
            nextMilestone: calculateNextMilestone(xp: user.totalXP)
        )
    }
    
    func getDailyStreak(for userId: String) async throws -> Int {
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let sortedWorkouts = workouts.sorted { $0.date > $1.date }
        
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()
        
        for workout in sortedWorkouts {
            if calendar.isDate(workout.date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
    
    func getWeeklyGoals(for userId: String) async throws -> [WeeklyGoal] {
        let user = try await userRepository.getUser(id: userId)
        return user.weeklyGoals
    }
    
    func updateWeeklyGoal(_ goal: WeeklyGoal, for userId: String) async throws {
        try await userRepository.updateWeeklyGoal(goal, for: userId)
        
        // Check if goal is completed
        if goal.isCompleted {
            try await awardXP(goal.xpReward, for: .weeklyGoal, userId: userId)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupXPMultipliers() {
        xpMultipliers = [
            .workoutComplete: 1.0,
            .streak: 1.5,
            .personalRecord: 2.0,
            .achievement: 1.0,
            .challengeJoin: 1.0,
            .challengeComplete: 1.5,
            .weeklyGoal: 1.0,
            .formImprovement: 1.2,
            .socialInteraction: 0.8
        ]
    }
    
    private func setupAchievementDefinitions() {
        achievementDefinitions = [
            .firstWorkout: AchievementDefinition(
                title: "First Steps",
                description: "Complete your first workout",
                xpReward: 100,
                icon: "🎯",
                condition: { user, workouts, progress in
                    workouts.count >= 1
                }
            ),
            .streak: AchievementDefinition(
                title: "Consistency Champion",
                description: "Maintain a 7-day workout streak",
                xpReward: 250,
                icon: "🔥",
                condition: { user, workouts, progress in
                    // This would check actual streak logic
                    workouts.count >= 7
                }
            ),
            .personalRecord: AchievementDefinition(
                title: "New Personal Best",
                description: "Set a new personal record",
                xpReward: 150,
                icon: "🏆",
                condition: { user, workouts, progress in
                    // This would check for PRs
                    false
                }
            ),
            .formMaster: AchievementDefinition(
                title: "Form Master",
                description: "Achieve perfect form on 10 exercises",
                xpReward: 300,
                icon: "✨",
                condition: { user, workouts, progress in
                    // This would check form scores
                    false
                }
            ),
            .socialButterfly: AchievementDefinition(
                title: "Social Butterfly",
                description: "Participate in 5 challenges",
                xpReward: 200,
                icon: "🦋",
                condition: { user, workouts, progress in
                    // This would check challenge participation
                    false
                }
            )
        ]
    }
    
    private func calculateUserLevel(xp: Int) -> UserLevel {
        switch xp {
        case 0..<1000:
            return .beginner
        case 1000..<5000:
            return .intermediate
        case 5000..<15000:
            return .advanced
        case 15000..<50000:
            return .expert
        default:
            return .master
        }
    }
    
    private func calculateUserRank(xp: Int) -> UserRank {
        switch xp {
        case 0..<5000:
            return .bronze
        case 5000..<15000:
            return .silver
        case 15000..<30000:
            return .gold
        case 30000..<50000:
            return .platinum
        default:
            return .diamond
        }
    }
    
    private func checkForLevelUp(userId: String) -> LevelUp? {
        // This would check if user has leveled up
        // For now, return nil
        return nil
    }
    
    private func handleLevelUp(_ levelUp: LevelUp, for userId: String) async throws {
        // Award level up bonus
        try await awardXP(levelUp.bonusXP, for: .levelUp, userId: userId)
        
        // Send notification
        print("🎉 Level Up! You're now \(levelUp.newLevel.rawValue)! +\(levelUp.bonusXP) XP!")
    }
    
    private func checkAchievementCondition(
        type: AchievementType,
        definition: AchievementDefinition,
        user: User,
        workouts: [Workout],
        progress: ProgressOverview
    ) async throws -> Achievement? {
        guard definition.condition(user, workouts, progress) else {
            return nil
        }
        
        return Achievement(
            id: UUID().uuidString,
            type: type,
            title: definition.title,
            description: definition.description,
            xpReward: definition.xpReward,
            icon: definition.icon,
            unlockedDate: Date(),
            isUnlocked: true
        )
    }
    
    private func checkChallengeAchievement(challenge: Challenge, userId: String) -> Achievement? {
        // Check for challenge-specific achievements
        // For now, return nil
        return nil
    }
    
    private func calculateNextMilestone(xp: Int) -> Milestone {
        let nextLevelXP = getXPForNextLevel(currentXP: xp)
        let xpNeeded = nextLevelXP - xp
        
        return Milestone(
            type: .levelUp,
            title: "Next Level",
            description: "Reach the next level",
            progress: Double(xp) / Double(nextLevelXP),
            xpNeeded: xpNeeded
        )
    }
    
    private func getXPForNextLevel(currentXP: Int) -> Int {
        switch currentXP {
        case 0..<1000:
            return 1000
        case 1000..<5000:
            return 5000
        case 5000..<15000:
            return 15000
        case 15000..<50000:
            return 50000
        default:
            return 100000
        }
    }
}

// MARK: - Supporting Types

enum XPAction: String, Codable {
    case workoutComplete
    case streak
    case personalRecord
    case achievement
    case challengeJoin
    case challengeComplete
    case weeklyGoal
    case formImprovement
    case socialInteraction
    case levelUp
}

enum UserLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
    case master = "Master"
}

enum UserRank: String, Codable, CaseIterable {
    case bronze = "Bronze"
    case silver = "Silver"
    case gold = "Gold"
    case platinum = "Platinum"
    case diamond = "Diamond"
}

enum LeaderboardScope: String, Codable {
    case global
    case friends
    case company
    case studio
}

struct LeaderboardEntry: Identifiable, Codable {
    let id = UUID()
    let rank: Int
    let userId: String
    let username: String
    let xp: Int
    let level: UserLevel
    let avatar: URL?
}

struct Challenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let type: ChallengeType
    let startDate: Date
    let endDate: Date
    let maxParticipants: Int
    var participants: [String]
    let xpReward: Int
    let requirements: ChallengeRequirements
    let createdBy: String
    let createdAt: Date
}

enum ChallengeType: String, Codable {
    case workoutStreak
    case distance
    case calories
    case strength
    case endurance
    case social
}

struct ChallengeRequirements: Codable {
    let workoutCount: Int?
    let distance: Double?
    let calories: Int?
    let strengthGoal: String?
    let duration: TimeInterval?
}

struct UserProgress: Codable {
    let userId: String
    let totalXP: Int
    let currentLevel: UserLevel
    let currentRank: UserRank
    let weeklyWorkouts: Int
    let monthlyWorkouts: Int
    let currentStreak: Int
    let achievementsCount: Int
    let recentAchievements: [Achievement]
    let nextMilestone: Milestone
}

struct WeeklyGoal: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let target: Int
    var current: Int
    let unit: String
    let xpReward: Int
    var isCompleted: Bool
    let weekStart: Date
}

struct Milestone: Codable {
    let type: MilestoneType
    let title: String
    let description: String
    let progress: Double
    let xpNeeded: Int
}

enum MilestoneType: String, Codable {
    case levelUp
    case rankUp
    case achievement
    case challenge
}

struct LevelUp: Codable {
    let oldLevel: UserLevel
    let newLevel: UserLevel
    let bonusXP: Int
}

struct AchievementDefinition {
    let title: String
    let description: String
    let xpReward: Int
    let icon: String
    let condition: (User, [Workout], ProgressOverview) -> Bool
}

// MARK: - Error Types

enum GamificationError: LocalizedError {
    case invalidChallengeDate
    case challengeFull
    case alreadyParticipating
    case notParticipating
    case userNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidChallengeDate:
            return "Challenge start date must be in the future"
        case .challengeFull:
            return "Challenge has reached maximum participants"
        case .alreadyParticipating:
            return "User is already participating in this challenge"
        case .notParticipating:
            return "User is not participating in this challenge"
        case .userNotFound:
            return "User not found"
        }
    }
}

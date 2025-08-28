import Foundation
import Combine
import CoreML

// MARK: - Personalization Engine Protocol
protocol PersonalizationEngineProtocol: ObservableObject {
    var isProcessing: Bool { get }
    var lastPersonalization: PersonalizationResult? { get }
    
    func personalizeWorkoutDifficulty(workout: Workout, for user: User) async throws -> PersonalizedWorkout
    func generateAdaptiveWorkout(user: User, context: WorkoutContext) async throws -> AdaptiveWorkout
    func optimizeExerciseSelection(user: User, goals: [FitnessGoal]) async throws -> [Exercise]
    func adjustTrainingVolume(user: User, based on: PerformanceData) async throws -> TrainingVolumeAdjustment
    func personalizeRecoveryRecommendations(user: User, workout: Workout) async throws -> RecoveryRecommendations
    func generateProgressiveOverloadPlan(user: User, exercise: Exercise) async throws -> ProgressiveOverloadPlan
    func adaptWorkoutToUserFeedback(user: User, workout: Workout, feedback: UserFeedback) async throws -> AdaptedWorkout
}

// MARK: - Personalization Engine
final class PersonalizationEngine: NSObject, PersonalizationEngineProtocol {
    @Published var isProcessing: Bool = false
    @Published var lastPersonalization: PersonalizationResult?
    
    private let mlModelManager: MLModelManagerProtocol
    private let analyticsEngine: AnalyticsEngineProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let progressAnalyticsService: ProgressAnalyticsServiceProtocol
    private let cacheService: CacheServiceProtocol
    
    private var personalizationCache: [String: PersonalizationResult] = [:]
    private var userPreferences: [String: UserPreferences] = [:]
    
    init(
        mlModelManager: MLModelManagerProtocol,
        analyticsEngine: AnalyticsEngineProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        healthKitManager: HealthKitManagerProtocol,
        progressAnalyticsService: ProgressAnalyticsServiceProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.mlModelManager = mlModelManager
        self.analyticsEngine = analyticsEngine
        self.workoutRepository = workoutRepository
        self.userRepository = userRepository
        self.healthKitManager = healthKitManager
        self.progressAnalyticsService = progressAnalyticsService
        self.cacheService = cacheService
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    func personalizeWorkoutDifficulty(workout: Workout, for user: User) async throws -> PersonalizedWorkout {
        isProcessing = true
        defer { isProcessing = false }
        
        let cacheKey = "workout_personalization_\(user.id)_\(workout.id)"
        
        // Check cache first
        if let cached = personalizationCache[cacheKey] as? PersonalizedWorkout {
            return cached
        }
        
        // Gather user data for personalization
        let userProfile = try await buildUserProfile(user: user)
        let performanceData = try await gatherPerformanceData(user: user)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        let preferences = getUserPreferences(for: user.id)
        
        // Generate personalized workout using ML
        let personalizedWorkout = try await generatePersonalizedWorkout(
            workout: workout,
            userProfile: userProfile,
            performanceData: performanceData,
            healthMetrics: healthMetrics,
            preferences: preferences
        )
        
        // Cache the result
        personalizationCache[cacheKey] = personalizedWorkout
        lastPersonalization = PersonalizationResult(
            timestamp: Date(),
            type: .workoutDifficulty,
            data: personalizedWorkout
        )
        
        return personalizedWorkout
    }
    
    func generateAdaptiveWorkout(user: User, context: WorkoutContext) async throws -> AdaptiveWorkout {
        let userProfile = try await buildUserProfile(user: user)
        let performanceData = try await gatherPerformanceData(user: user)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        let recentWorkouts = try await workoutRepository.getWorkouts(for: user.id, limit: 10)
        
        let adaptiveWorkout = try await generateAdaptiveWorkout(
            userProfile: userProfile,
            performanceData: performanceData,
            healthMetrics: healthMetrics,
            recentWorkouts: recentWorkouts,
            context: context
        )
        
        return adaptiveWorkout
    }
    
    func optimizeExerciseSelection(user: User, goals: [FitnessGoal]) async throws -> [Exercise] {
        let userProfile = try await buildUserProfile(user: user)
        let performanceData = try await gatherPerformanceData(user: user)
        let availableExercises = try await getAvailableExercises()
        
        let optimizedExercises = try await selectOptimalExercises(
            userProfile: userProfile,
            performanceData: performanceData,
            goals: goals,
            availableExercises: availableExercises
        )
        
        return optimizedExercises
    }
    
    func adjustTrainingVolume(user: User, based on: PerformanceData) async throws -> TrainingVolumeAdjustment {
        let userProfile = try await buildUserProfile(user: user)
        let currentVolume = try await calculateCurrentTrainingVolume(user: user)
        
        let adjustment = try await calculateVolumeAdjustment(
            userProfile: userProfile,
            currentVolume: currentVolume,
            performanceData: performanceData
        )
        
        return adjustment
    }
    
    func personalizeRecoveryRecommendations(user: User, workout: Workout) async throws -> RecoveryRecommendations {
        let userProfile = try await buildUserProfile(user: user)
        let workoutIntensity = calculateWorkoutIntensity(workout: workout)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let recommendations = try await generateRecoveryRecommendations(
            userProfile: userProfile,
            workoutIntensity: workoutIntensity,
            healthMetrics: healthMetrics
        )
        
        return recommendations
    }
    
    func generateProgressiveOverloadPlan(user: User, exercise: Exercise) async throws -> ProgressiveOverloadPlan {
        let userProfile = try await buildUserProfile(user: user)
        let exerciseHistory = try await getExerciseHistory(user: user, exercise: exercise)
        let performanceData = try await gatherPerformanceData(user: user)
        
        let plan = try await createProgressiveOverloadPlan(
            userProfile: userProfile,
            exercise: exercise,
            exerciseHistory: exerciseHistory,
            performanceData: performanceData
        )
        
        return plan
    }
    
    func adaptWorkoutToUserFeedback(user: User, workout: Workout, feedback: UserFeedback) async throws -> AdaptedWorkout {
        let userProfile = try await buildUserProfile(user: user)
        let performanceData = try await gatherPerformanceData(user: user)
        
        let adaptedWorkout = try await adaptWorkoutBasedOnFeedback(
            workout: workout,
            userProfile: userProfile,
            performanceData: performanceData,
            feedback: feedback
        )
        
        return adaptedWorkout
    }
    
    // MARK: - Private Methods
    
    private func buildUserProfile(user: User) async throws -> UserProfile {
        let fitnessLevel = user.profile.fitnessLevel
        let age = user.profile.age
        let weight = user.profile.weight
        let height = user.profile.height
        let goals = user.profile.goals
        
        return UserProfile(
            fitnessLevel: fitnessLevel,
            age: age,
            weight: weight,
            height: height,
            goals: goals
        )
    }
    
    private func gatherPerformanceData(user: User) async throws -> PerformanceData {
        let workouts = try await workoutRepository.getWorkouts(for: user.id, limit: 50)
        let progress = try await progressAnalyticsService.getProgressOverview(for: user.id)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let performanceData = PerformanceData(
            recentWorkouts: workouts,
            progressOverview: progress,
            healthMetrics: healthMetrics,
            consistency: calculateConsistency(workouts: workouts),
            improvement: calculateImprovement(workouts: workouts),
            recovery: calculateRecovery(workouts: workouts, healthMetrics: healthMetrics)
        )
        
        return performanceData
    }
    
    private func getUserPreferences(for userId: String) -> UserPreferences {
        return userPreferences[userId] ?? UserPreferences.default
    }
    
    private func generatePersonalizedWorkout(
        workout: Workout,
        userProfile: UserProfile,
        performanceData: PerformanceData,
        healthMetrics: HealthStats,
        preferences: UserPreferences
    ) async throws -> PersonalizedWorkout {
        
        // Analyze current user state
        let readinessScore = calculateReadinessScore(healthMetrics: healthMetrics)
        let fatigueLevel = calculateFatigueLevel(performanceData: performanceData)
        let performanceTrend = analyzePerformanceTrend(performanceData: performanceData)
        
        // Use ML to predict optimal difficulty
        let mlInput = PerformancePredictionInput(
            workoutData: WorkoutData(
                type: workout.type,
                intensity: workout.intensity,
                duration: workout.duration,
                exercises: workout.exercises
            ),
            userProfile: userProfile,
            healthMetrics: healthMetrics,
            recentPerformance: RecentPerformance(
                averageIntensity: performanceData.averageIntensity,
                consistency: performanceData.consistency,
                improvement: performanceData.improvement
            )
        )
        
        let mlOutput = try await mlModelManager.performInference(
            modelName: "PerformancePredictionModel",
            input: .performancePrediction(mlInput)
        )
        
        // Extract ML predictions
        guard case .performancePrediction(let prediction) = mlOutput else {
            throw PersonalizationError.invalidMLOutput
        }
        
        // Generate personalized workout
        let personalizedExercises = try await personalizeExercises(
            exercises: workout.exercises,
            userProfile: userProfile,
            performanceData: performanceData,
            mlPrediction: prediction
        )
        
        let adjustedDifficulty = adjustDifficulty(
            base: workout.difficulty,
            readiness: readinessScore,
            fatigue: fatigueLevel,
            trend: performanceTrend,
            mlPrediction: prediction
        )
        
        let adjustedDuration = adjustDuration(
            base: workout.duration,
            readiness: readinessScore,
            fatigue: fatigueLevel,
            mlPrediction: prediction
        )
        
        let adjustedIntensity = adjustIntensity(
            base: workout.intensity,
            readiness: readinessScore,
            fatigue: fatigueLevel,
            mlPrediction: prediction
        )
        
        return PersonalizedWorkout(
            originalWorkout: workout,
            personalizedExercises: personalizedExercises,
            adjustedDifficulty: adjustedDifficulty,
            adjustedDuration: adjustedDuration,
            adjustedIntensity: adjustedIntensity,
            personalizationFactors: [
                PersonalizationFactor(type: .readiness, value: readinessScore),
                PersonalizationFactor(type: .fatigue, value: fatigueLevel.rawValue),
                PersonalizationFactor(type: .performance, value: performanceTrend.rawValue),
                PersonalizationFactor(type: .mlPrediction, value: prediction.confidence)
            ],
            recommendations: generatePersonalizationRecommendations(
                readiness: readinessScore,
                fatigue: fatigueLevel,
                trend: performanceTrend,
                prediction: prediction
            )
        )
    }
    
    private func generateAdaptiveWorkout(
        userProfile: UserProfile,
        performanceData: PerformanceData,
        healthMetrics: HealthStats,
        recentWorkouts: [Workout],
        context: WorkoutContext
    ) async throws -> AdaptiveWorkout {
        
        // Analyze user's current state and needs
        let readinessScore = calculateReadinessScore(healthMetrics: healthMetrics)
        let fatigueLevel = calculateFatigueLevel(performanceData: performanceData)
        let recoveryNeeds = calculateRecoveryNeeds(performanceData: performanceData)
        
        // Generate adaptive workout based on context
        let adaptiveExercises = try await generateAdaptiveExercises(
            userProfile: userProfile,
            performanceData: performanceData,
            context: context,
            readiness: readinessScore,
            fatigue: fatigueLevel,
            recoveryNeeds: recoveryNeeds
        )
        
        let optimalDuration = calculateOptimalDuration(
            context: context,
            readiness: readinessScore,
            fatigue: fatigueLevel
        )
        
        let optimalIntensity = calculateOptimalIntensity(
            context: context,
            readiness: readinessScore,
            fatigue: fatigueLevel,
            recoveryNeeds: recoveryNeeds
        )
        
        return AdaptiveWorkout(
            exercises: adaptiveExercises,
            duration: optimalDuration,
            intensity: optimalIntensity,
            context: context,
            adaptationFactors: [
                AdaptationFactor(type: .readiness, value: readinessScore),
                AdaptationFactor(type: .fatigue, value: fatigueLevel.rawValue),
                AdaptationFactor(type: .recovery, value: recoveryNeeds),
                AdaptationFactor(type: .context, value: context.rawValue)
            ],
            recommendations: generateAdaptationRecommendations(
                context: context,
                readiness: readinessScore,
                fatigue: fatigueLevel,
                recoveryNeeds: recoveryNeeds
            )
        )
    }
    
    private func selectOptimalExercises(
        userProfile: UserProfile,
        performanceData: PerformanceData,
        goals: [FitnessGoal],
        availableExercises: [Exercise]
    ) async throws -> [Exercise] {
        
        // Score exercises based on user profile and goals
        let scoredExercises = availableExercises.map { exercise in
            let score = calculateExerciseScore(
                exercise: exercise,
                userProfile: userProfile,
                performanceData: performanceData,
                goals: goals
            )
            return (exercise, score)
        }
        
        // Sort by score and select top exercises
        let sortedExercises = scoredExercises
            .sorted { $0.1 > $1.1 }
            .prefix(8) // Select top 8 exercises
            .map { $0.0 }
        
        return Array(sortedExercises)
    }
    
    private func calculateVolumeAdjustment(
        userProfile: UserProfile,
        currentVolume: TrainingVolume,
        performanceData: PerformanceData
    ) async throws -> TrainingVolumeAdjustment {
        
        // Analyze performance trends
        let performanceTrend = analyzePerformanceTrend(performanceData: performanceData)
        let recoveryQuality = calculateRecoveryQuality(performanceData: performanceData)
        let consistency = performanceData.consistency
        
        // Calculate optimal volume adjustment
        let volumeMultiplier = calculateVolumeMultiplier(
            trend: performanceTrend,
            recovery: recoveryQuality,
            consistency: consistency
        )
        
        let adjustedVolume = TrainingVolume(
            sets: Int(Double(currentVolume.sets) * volumeMultiplier),
            reps: Int(Double(currentVolume.reps) * volumeMultiplier),
            weight: currentVolume.weight * volumeMultiplier,
            duration: currentVolume.duration * volumeMultiplier
        )
        
        let adjustmentType: VolumeAdjustmentType
        if volumeMultiplier > 1.1 {
            adjustmentType = .increase
        } else if volumeMultiplier < 0.9 {
            adjustmentType = .decrease
        } else {
            adjustmentType = .maintain
        }
        
        return TrainingVolumeAdjustment(
            currentVolume: currentVolume,
            adjustedVolume: adjustedVolume,
            adjustmentType: adjustmentType,
            multiplier: volumeMultiplier,
            reasoning: generateVolumeAdjustmentReasoning(
                trend: performanceTrend,
                recovery: recoveryQuality,
                consistency: consistency
            )
        )
    }
    
    private func generateRecoveryRecommendations(
        userProfile: UserProfile,
        workoutIntensity: WorkoutIntensity,
        healthMetrics: HealthStats
    ) async throws -> RecoveryRecommendations {
        
        // Calculate recovery needs based on workout intensity and user profile
        let recoveryTime = calculateRecoveryTime(
            intensity: workoutIntensity,
            userProfile: userProfile
        )
        
        let recoveryActivities = selectRecoveryActivities(
            intensity: workoutIntensity,
            userProfile: userProfile
        )
        
        let nutritionRecommendations = generateNutritionRecommendations(
            intensity: workoutIntensity,
            userProfile: userProfile
        )
        
        let sleepRecommendations = generateSleepRecommendations(
            healthMetrics: healthMetrics,
            userProfile: userProfile
        )
        
        return RecoveryRecommendations(
            recoveryTime: recoveryTime,
            activities: recoveryActivities,
            nutrition: nutritionRecommendations,
            sleep: sleepRecommendations,
            reasoning: generateRecoveryReasoning(
                intensity: workoutIntensity,
                userProfile: userProfile,
                healthMetrics: healthMetrics
            )
        )
    }
    
    private func createProgressiveOverloadPlan(
        userProfile: UserProfile,
        exercise: Exercise,
        exerciseHistory: [ExerciseHistory],
        performanceData: PerformanceData
    ) async throws -> ProgressiveOverloadPlan {
        
        // Analyze exercise performance history
        let performanceTrend = analyzeExercisePerformanceTrend(exerciseHistory: exerciseHistory)
        let currentLevel = calculateCurrentExerciseLevel(exerciseHistory: exerciseHistory)
        let improvementRate = calculateImprovementRate(exerciseHistory: exerciseHistory)
        
        // Generate progressive overload plan
        let phases = generateProgressiveOverloadPhases(
            currentLevel: currentLevel,
            improvementRate: improvementRate,
            userProfile: userProfile
        )
        
        let timeline = calculateProgressiveOverloadTimeline(
            phases: phases,
            improvementRate: improvementRate
        )
        
        let milestones = generateProgressiveOverloadMilestones(
            phases: phases,
            timeline: timeline
        )
        
        return ProgressiveOverloadPlan(
            exercise: exercise,
            phases: phases,
            timeline: timeline,
            milestones: milestones,
            reasoning: generateProgressiveOverloadReasoning(
                currentLevel: currentLevel,
                improvementRate: improvementRate,
                userProfile: userProfile
            )
        )
    }
    
    private func adaptWorkoutBasedOnFeedback(
        workout: Workout,
        userProfile: UserProfile,
        performanceData: PerformanceData,
        feedback: UserFeedback
    ) async throws -> AdaptedWorkout {
        
        // Analyze user feedback
        let difficultyFeedback = analyzeDifficultyFeedback(feedback: feedback)
        let enjoymentFeedback = analyzeEnjoymentFeedback(feedback: feedback)
        let completionFeedback = analyzeCompletionFeedback(feedback: feedback)
        
        // Adapt workout based on feedback
        let adaptedExercises = try await adaptExercises(
            exercises: workout.exercises,
            feedback: feedback,
            userProfile: userProfile
        )
        
        let adaptedDifficulty = adaptDifficulty(
            base: workout.difficulty,
            feedback: feedback,
            performanceData: performanceData
        )
        
        let adaptedDuration = adaptDuration(
            base: workout.duration,
            feedback: feedback,
            performanceData: performanceData
        )
        
        return AdaptedWorkout(
            originalWorkout: workout,
            adaptedExercises: adaptedExercises,
            adaptedDifficulty: adaptedDifficulty,
            adaptedDuration: adaptedDuration,
            feedbackAnalysis: FeedbackAnalysis(
                difficulty: difficultyFeedback,
                enjoyment: enjoymentFeedback,
                completion: completionFeedback
            ),
            adaptationReasoning: generateAdaptationReasoning(
                feedback: feedback,
                performanceData: performanceData
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func calculateReadinessScore(healthMetrics: HealthStats) -> Double {
        let sleepScore = healthMetrics.sleepHours / 8.0
        let stressScore = 1.0 - (healthMetrics.stressLevel / 100.0)
        let energyScore = healthMetrics.energyLevel / 100.0
        
        let readiness = (sleepScore * 0.4) + (stressScore * 0.3) + (energyScore * 0.3)
        return min(max(readiness, 0.0), 1.0)
    }
    
    private func calculateFatigueLevel(performanceData: PerformanceData) -> FatigueLevel {
        let workoutFatigue = calculateWorkoutFatigue(performanceData: performanceData)
        let recoveryFatigue = calculateRecoveryFatigue(performanceData: performanceData)
        
        let totalFatigue = (workoutFatigue * 0.7) + (recoveryFatigue * 0.3)
        
        switch totalFatigue {
        case 0.0..<0.25: return .low
        case 0.25..<0.5: return .moderate
        case 0.5..<0.75: return .high
        default: return .veryHigh
        }
    }
    
    private func analyzePerformanceTrend(performanceData: PerformanceData) -> PerformanceTrend {
        // Analyze performance trend from recent data
        if performanceData.improvement > 0.1 { return .improving }
        else if performanceData.improvement < -0.1 { return .declining }
        else { return .stable }
    }
    
    // Additional helper methods would be implemented here...
    // For brevity, I'm showing the core structure
}

// MARK: - Supporting Types

struct PersonalizationResult {
    let timestamp: Date
    let type: PersonalizationType
    let data: Any
}

enum PersonalizationType {
    case workoutDifficulty
    case adaptiveWorkout
    case exerciseSelection
    case trainingVolume
    case recoveryRecommendations
    case progressiveOverload
    case workoutAdaptation
}

struct PersonalizedWorkout {
    let originalWorkout: Workout
    let personalizedExercises: [PersonalizedExercise]
    let adjustedDifficulty: Difficulty
    let adjustedDuration: TimeInterval
    let adjustedIntensity: WorkoutIntensity
    let personalizationFactors: [PersonalizationFactor]
    let recommendations: [PersonalizationRecommendation]
}

struct AdaptiveWorkout {
    let exercises: [Exercise]
    let duration: TimeInterval
    let intensity: WorkoutIntensity
    let context: WorkoutContext
    let adaptationFactors: [AdaptationFactor]
    let recommendations: [AdaptationRecommendation]
}

struct TrainingVolumeAdjustment {
    let currentVolume: TrainingVolume
    let adjustedVolume: TrainingVolume
    let adjustmentType: VolumeAdjustmentType
    let multiplier: Double
    let reasoning: String
}

struct RecoveryRecommendations {
    let recoveryTime: TimeInterval
    let activities: [RecoveryActivity]
    let nutrition: [NutritionRecommendation]
    let sleep: [SleepRecommendation]
    let reasoning: String
}

struct ProgressiveOverloadPlan {
    let exercise: Exercise
    let phases: [ProgressiveOverloadPhase]
    let timeline: TimeInterval
    let milestones: [ProgressiveOverloadMilestone]
    let reasoning: String
}

struct AdaptedWorkout {
    let originalWorkout: Workout
    let adaptedExercises: [Exercise]
    let adaptedDifficulty: Difficulty
    let adaptedDuration: TimeInterval
    let feedbackAnalysis: FeedbackAnalysis
    let adaptationReasoning: String
}

// Additional supporting types would be defined here...
// For brevity, I'm showing the core structure

enum PersonalizationError: Error, LocalizedError {
    case invalidMLOutput
    case insufficientData
    case personalizationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMLOutput:
            return "Invalid ML model output"
        case .insufficientData:
            return "Insufficient data for personalization"
        case .personalizationFailed(let reason):
            return "Personalization failed: \(reason)"
        }
    }
}

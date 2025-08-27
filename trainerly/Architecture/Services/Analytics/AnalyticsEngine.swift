import Foundation
import Combine
import CoreML

// MARK: - Analytics Engine Protocol
protocol AnalyticsEngineProtocol: ObservableObject {
    var isProcessing: Bool { get }
    var lastAnalysis: AnalyticsResult? { get }
    
    func analyzeUserProgress(userId: String, period: AnalyticsPeriod) async throws -> ProgressAnalysis
    func predictWorkoutPerformance(userId: String, workout: Workout) async throws -> PerformancePrediction
    func analyzeRecoveryPatterns(userId: String) async throws -> RecoveryAnalysis
    func predictGoalAchievement(userId: String, goal: FitnessGoal) async throws -> GoalPrediction
    func generatePersonalizedInsights(userId: String) async throws -> [PersonalizedInsight]
    func analyzePerformanceCorrelations(userId: String) async throws -> CorrelationAnalysis
    func optimizeTrainingFrequency(userId: String) async throws -> TrainingOptimization
    func predictInjuryRisk(userId: String) async throws -> InjuryRiskAssessment
}

// MARK: - Analytics Engine
final class AnalyticsEngine: NSObject, AnalyticsEngineProtocol {
    @Published var isProcessing: Bool = false
    @Published var lastAnalysis: AnalyticsResult?
    
    private let progressAnalyticsService: ProgressAnalyticsServiceProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let aiWorkoutGenerator: AIWorkoutGeneratorProtocol
    private let cacheService: CacheServiceProtocol
    
    private var mlModels: [String: MLModel] = [:]
    private var analyticsCache: [String: AnalyticsResult] = [:]
    
    init(
        progressAnalyticsService: ProgressAnalyticsServiceProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        healthKitManager: HealthKitManagerProtocol,
        aiWorkoutGenerator: AIWorkoutGeneratorProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.progressAnalyticsService = progressAnalyticsService
        self.workoutRepository = workoutRepository
        self.userRepository = userRepository
        self.healthKitManager = healthKitManager
        self.aiWorkoutGenerator = aiWorkoutGenerator
        self.cacheService = cacheService
        
        super.init()
        
        setupMLModels()
    }
    
    // MARK: - Public Methods
    
    func analyzeUserProgress(userId: String, period: AnalyticsPeriod) async throws -> ProgressAnalysis {
        isProcessing = true
        defer { isProcessing = false }
        
        let cacheKey = "progress_analysis_\(userId)_\(period.rawValue)"
        
        // Check cache first
        if let cached = analyticsCache[cacheKey] as? ProgressAnalysis {
            return cached
        }
        
        // Gather comprehensive data
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        let progress = try await progressAnalyticsService.getProgressOverview(for: userId)
        
        // Perform advanced analysis
        let analysis = try await performProgressAnalysis(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics,
            progress: progress,
            period: period
        )
        
        // Cache the result
        analyticsCache[cacheKey] = analysis
        lastAnalysis = analysis
        
        return analysis
    }
    
    func predictWorkoutPerformance(userId: String, workout: Workout) async throws -> PerformancePrediction {
        let user = try await userRepository.getUser(id: userId)
        let recentWorkouts = try await workoutRepository.getWorkouts(for: userId, limit: 20)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let prediction = try await generatePerformancePrediction(
            user: user,
            workout: workout,
            recentWorkouts: recentWorkouts,
            healthMetrics: healthMetrics
        )
        
        return prediction
    }
    
    func analyzeRecoveryPatterns(userId: String) async throws -> RecoveryAnalysis {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 50)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let analysis = try await analyzeRecovery(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return analysis
    }
    
    func predictGoalAchievement(userId: String, goal: FitnessGoal) async throws -> GoalPrediction {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let progress = try await progressAnalyticsService.getProgressOverview(for: userId)
        
        let prediction = try await generateGoalPrediction(
            user: user,
            goal: goal,
            workouts: workouts,
            progress: progress
        )
        
        return prediction
    }
    
    func generatePersonalizedInsights(userId: String) async throws -> [PersonalizedInsight] {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        let progress = try await progressAnalyticsService.getProgressOverview(for: userId)
        
        let insights = try await generateInsights(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics,
            progress: progress
        )
        
        return insights
    }
    
    func analyzePerformanceCorrelations(userId: String) async throws -> CorrelationAnalysis {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let analysis = try await performCorrelationAnalysis(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return analysis
    }
    
    func optimizeTrainingFrequency(userId: String) async throws -> TrainingOptimization {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let optimization = try await generateTrainingOptimization(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return optimization
    }
    
    func predictInjuryRisk(userId: String) async throws -> InjuryRiskAssessment {
        let user = try await userRepository.getUser(id: userId)
        let workouts = try await workoutRepository.getWorkouts(for: userId, limit: 100)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        
        let assessment = try await generateInjuryRiskAssessment(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return assessment
    }
    
    // MARK: - Private Methods
    
    private func setupMLModels() {
        // Load Core ML models for analytics
        // This would typically load trained models for:
        // - Performance prediction
        // - Recovery analysis
        // - Injury risk assessment
        // - Goal achievement prediction
        
        print("🤖 Loading ML models for analytics...")
    }
    
    private func performProgressAnalysis(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats,
        progress: ProgressOverview,
        period: AnalyticsPeriod
    ) async throws -> ProgressAnalysis {
        
        // Calculate advanced metrics
        let workoutIntensity = calculateWorkoutIntensity(workouts: workouts, period: period)
        let consistencyScore = calculateConsistencyScore(workouts: workouts, period: period)
        let improvementRate = calculateImprovementRate(workouts: workouts, period: period)
        let recoveryEfficiency = calculateRecoveryEfficiency(workouts: workouts, healthMetrics: healthMetrics)
        
        // Generate predictions
        let nextWeekPrediction = try await predictNextWeekPerformance(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        let monthlyProjection = try await projectMonthlyProgress(
            user: user,
            workouts: workouts,
            period: period
        )
        
        // Identify trends and patterns
        let trends = identifyTrends(workouts: workouts, period: period)
        let patterns = identifyPatterns(workouts: workouts, healthMetrics: healthMetrics)
        
        return ProgressAnalysis(
            userId: user.id,
            period: period,
            workoutIntensity: workoutIntensity,
            consistencyScore: consistencyScore,
            improvementRate: improvementRate,
            recoveryEfficiency: recoveryEfficiency,
            nextWeekPrediction: nextWeekPrediction,
            monthlyProjection: monthlyProjection,
            trends: trends,
            patterns: patterns,
            recommendations: generateProgressRecommendations(
                intensity: workoutIntensity,
                consistency: consistencyScore,
                improvement: improvementRate,
                recovery: recoveryEfficiency
            )
        )
    }
    
    private func generatePerformancePrediction(
        user: User,
        workout: Workout,
        recentWorkouts: [Workout],
        healthMetrics: HealthStats
    ) async throws -> PerformancePrediction {
        
        // Analyze recent performance trends
        let recentPerformance = analyzeRecentPerformance(workouts: recentWorkouts)
        let fatigueLevel = calculateFatigueLevel(workouts: recentWorkouts, healthMetrics: healthMetrics)
        let readinessScore = calculateReadinessScore(user: user, healthMetrics: healthMetrics)
        
        // Predict workout performance
        let predictedDuration = predictWorkoutDuration(workout: workout, readiness: readinessScore)
        let predictedCalories = predictCalorieBurn(workout: workout, user: user, readiness: readinessScore)
        let predictedDifficulty = predictWorkoutDifficulty(workout: workout, fatigue: fatigueLevel)
        
        // Generate recommendations
        let recommendations = generateWorkoutRecommendations(
            workout: workout,
            readiness: readinessScore,
            fatigue: fatigueLevel
        )
        
        return PerformancePrediction(
            workoutId: workout.id,
            predictedDuration: predictedDuration,
            predictedCalories: predictedCalories,
            predictedDifficulty: predictedDifficulty,
            readinessScore: readinessScore,
            fatigueLevel: fatigueLevel,
            recommendations: recommendations,
            confidence: calculatePredictionConfidence(recentWorkouts: recentWorkouts)
        )
    }
    
    private func analyzeRecovery(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats
    ) async throws -> RecoveryAnalysis {
        
        // Calculate recovery metrics
        let recoveryTime = calculateAverageRecoveryTime(workouts: workouts)
        let sleepQuality = analyzeSleepQuality(healthMetrics: healthMetrics)
        let stressLevel = analyzeStressLevel(healthMetrics: healthMetrics)
        let nutritionImpact = analyzeNutritionImpact(workouts: workouts, healthMetrics: healthMetrics)
        
        // Generate recovery insights
        let insights = generateRecoveryInsights(
            recoveryTime: recoveryTime,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            nutritionImpact: nutritionImpact
        )
        
        // Predict optimal recovery
        let optimalRecovery = predictOptimalRecovery(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return RecoveryAnalysis(
            userId: user.id,
            averageRecoveryTime: recoveryTime,
            sleepQuality: sleepQuality,
            stressLevel: stressLevel,
            nutritionImpact: nutritionImpact,
            insights: insights,
            optimalRecovery: optimalRecovery,
            recommendations: generateRecoveryRecommendations(
                recoveryTime: recoveryTime,
                sleepQuality: sleepQuality,
                stressLevel: stressLevel,
                nutritionImpact: nutritionImpact
            )
        )
    }
    
    private func generateGoalPrediction(
        user: User,
        goal: FitnessGoal,
        workouts: [Workout],
        progress: ProgressOverview
    ) async throws -> GoalPrediction {
        
        // Analyze current progress
        let currentProgress = calculateGoalProgress(goal: goal, workouts: workouts, progress: progress)
        let progressRate = calculateProgressRate(goal: goal, workouts: workouts, period: .month)
        
        // Predict achievement timeline
        let predictedTimeline = predictAchievementTimeline(
            goal: goal,
            currentProgress: currentProgress,
            progressRate: progressRate
        )
        
        // Calculate success probability
        let successProbability = calculateSuccessProbability(
            goal: goal,
            currentProgress: currentProgress,
            progressRate: progressRate,
            user: user
        )
        
        // Generate optimization strategies
        let strategies = generateOptimizationStrategies(
            goal: goal,
            currentProgress: currentProgress,
            progressRate: progressRate
        )
        
        return GoalPrediction(
            goalId: goal.id,
            currentProgress: currentProgress,
            progressRate: progressRate,
            predictedTimeline: predictedTimeline,
            successProbability: successProbability,
            strategies: strategies,
            recommendations: generateGoalRecommendations(
                goal: goal,
                currentProgress: currentProgress,
                progressRate: progressRate
            )
        )
    }
    
    private func generateInsights(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats,
        progress: ProgressOverview
    ) async throws -> [PersonalizedInsight] {
        
        var insights: [PersonalizedInsight] = []
        
        // Performance insights
        let performanceInsights = generatePerformanceInsights(
            user: user,
            workouts: workouts,
            progress: progress
        )
        insights.append(contentsOf: performanceInsights)
        
        // Health insights
        let healthInsights = generateHealthInsights(
            user: user,
            healthMetrics: healthMetrics,
            workouts: workouts
        )
        insights.append(contentsOf: healthInsights)
        
        // Recovery insights
        let recoveryInsights = generateRecoveryInsights(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        insights.append(contentsOf: recoveryInsights)
        
        // Goal insights
        let goalInsights = generateGoalInsights(
            user: user,
            progress: progress
        )
        insights.append(contentsOf: goalInsights)
        
        return insights.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func performCorrelationAnalysis(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats
    ) async throws -> CorrelationAnalysis {
        
        // Analyze correlations between different factors
        let sleepPerformanceCorrelation = analyzeSleepPerformanceCorrelation(
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        let nutritionRecoveryCorrelation = analyzeNutritionRecoveryCorrelation(
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        let stressPerformanceCorrelation = analyzeStressPerformanceCorrelation(
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        let workoutFrequencyCorrelation = analyzeWorkoutFrequencyCorrelation(
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return CorrelationAnalysis(
            userId: user.id,
            sleepPerformanceCorrelation: sleepPerformanceCorrelation,
            nutritionRecoveryCorrelation: nutritionRecoveryCorrelation,
            stressPerformanceCorrelation: stressPerformanceCorrelation,
            workoutFrequencyCorrelation: workoutFrequencyCorrelation,
            insights: generateCorrelationInsights(
                sleepCorrelation: sleepPerformanceCorrelation,
                nutritionCorrelation: nutritionRecoveryCorrelation,
                stressCorrelation: stressPerformanceCorrelation,
                frequencyCorrelation: workoutFrequencyCorrelation
            )
        )
    }
    
    private func generateTrainingOptimization(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats
    ) async throws -> TrainingOptimization {
        
        // Analyze current training patterns
        let currentFrequency = analyzeCurrentTrainingFrequency(workouts: workouts)
        let optimalFrequency = calculateOptimalTrainingFrequency(
            user: user,
            healthMetrics: healthMetrics
        )
        
        // Generate optimization recommendations
        let recommendations = generateTrainingOptimizationRecommendations(
            current: currentFrequency,
            optimal: optimalFrequency,
            user: user
        )
        
        // Predict optimal training schedule
        let optimalSchedule = predictOptimalTrainingSchedule(
            user: user,
            workouts: workouts,
            healthMetrics: healthMetrics
        )
        
        return TrainingOptimization(
            userId: user.id,
            currentFrequency: currentFrequency,
            optimalFrequency: optimalFrequency,
            recommendations: recommendations,
            optimalSchedule: optimalSchedule,
            expectedImprovements: predictTrainingImprovements(
                current: currentFrequency,
                optimal: optimalFrequency,
                user: user
            )
        )
    }
    
    private func generateInjuryRiskAssessment(
        user: User,
        workouts: [Workout],
        healthMetrics: HealthStats
    ) async throws -> InjuryRiskAssessment {
        
        // Analyze risk factors
        let overtrainingRisk = calculateOvertrainingRisk(workouts: workouts, healthMetrics: healthMetrics)
        let formRisk = calculateFormRisk(workouts: workouts)
        let recoveryRisk = calculateRecoveryRisk(workouts: workouts, healthMetrics: healthMetrics)
        let loadRisk = calculateLoadRisk(workouts: workouts, user: user)
        
        // Calculate overall risk
        let overallRisk = calculateOverallRisk(
            overtraining: overtrainingRisk,
            form: formRisk,
            recovery: recoveryRisk,
            load: loadRisk
        )
        
        // Generate prevention strategies
        let preventionStrategies = generatePreventionStrategies(
            overtrainingRisk: overtrainingRisk,
            formRisk: formRisk,
            recoveryRisk: recoveryRisk,
            loadRisk: loadRisk
        )
        
        return InjuryRiskAssessment(
            userId: user.id,
            overallRisk: overallRisk,
            overtrainingRisk: overtrainingRisk,
            formRisk: formRisk,
            recoveryRisk: recoveryRisk,
            loadRisk: loadRisk,
            preventionStrategies: preventionStrategies,
            recommendations: generateInjuryPreventionRecommendations(
                overallRisk: overallRisk,
                riskFactors: [overtrainingRisk, formRisk, recoveryRisk, loadRisk]
            )
        )
    }
    
    // MARK: - Calculation Methods
    
    private func calculateWorkoutIntensity(workouts: [Workout], period: AnalyticsPeriod) -> WorkoutIntensity {
        // Calculate average workout intensity over the specified period
        let periodWorkouts = filterWorkoutsByPeriod(workouts: workouts, period: period)
        let totalIntensity = periodWorkouts.reduce(0) { $0 + $1.intensity.rawValue }
        let averageIntensity = Double(totalIntensity) / Double(periodWorkouts.count)
        
        return WorkoutIntensity(rawValue: Int(averageIntensity)) ?? .moderate
    }
    
    private func calculateConsistencyScore(workouts: [Workout], period: AnalyticsPeriod) -> Double {
        // Calculate consistency score based on workout frequency and regularity
        let periodWorkouts = filterWorkoutsByPeriod(workouts: workouts, period: period)
        let expectedWorkouts = getExpectedWorkoutsForPeriod(period: period)
        let actualWorkouts = periodWorkouts.count
        
        return Double(actualWorkouts) / Double(expectedWorkouts)
    }
    
    private func calculateImprovementRate(workouts: [Workout], period: AnalyticsPeriod) -> Double {
        // Calculate improvement rate based on performance metrics
        let periodWorkouts = filterWorkoutsByPeriod(workouts: workouts, period: period)
        
        guard periodWorkouts.count >= 2 else { return 0.0 }
        
        let sortedWorkouts = periodWorkouts.sorted { $0.date < $1.date }
        let firstWorkout = sortedWorkouts.first!
        let lastWorkout = sortedWorkouts.last!
        
        let improvement = (lastWorkout.intensity.rawValue - firstWorkout.intensity.rawValue) / Double(periodWorkouts.count)
        return improvement
    }
    
    private func calculateRecoveryEfficiency(workouts: [Workout], healthMetrics: HealthStats) -> Double {
        // Calculate recovery efficiency based on sleep quality and workout frequency
        let sleepQuality = healthMetrics.sleepHours / 8.0 // Normalize to 8 hours
        let workoutFrequency = Double(workouts.count) / 7.0 // Workouts per week
        
        let recoveryEfficiency = (sleepQuality * 0.7) + (workoutFrequency * 0.3)
        return min(recoveryEfficiency, 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func filterWorkoutsByPeriod(workouts: [Workout], period: AnalyticsPeriod) -> [Workout] {
        let calendar = Calendar.current
        let now = Date()
        
        return workouts.filter { workout in
            switch period {
            case .week:
                return calendar.isDate(workout.date, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(workout.date, equalTo: now, toGranularity: .month)
            case .quarter:
                return calendar.isDate(workout.date, equalTo: now, toGranularity: .quarter)
            case .year:
                return calendar.isDate(workout.date, equalTo: now, toGranularity: .year)
            }
        }
    }
    
    private func getExpectedWorkoutsForPeriod(period: AnalyticsPeriod) -> Int {
        switch period {
        case .week: return 4
        case .month: return 16
        case .quarter: return 48
        case .year: return 192
        }
    }
    
    // Additional calculation methods would be implemented here...
    // For brevity, I'm showing the core structure
    
    private func analyzeRecentPerformance(workouts: [Workout]) -> RecentPerformance {
        // Implementation for analyzing recent workout performance
        return RecentPerformance(
            averageIntensity: .moderate,
            consistency: 0.8,
            improvement: 0.1
        )
    }
    
    private func calculateFatigueLevel(workouts: [Workout], healthMetrics: HealthStats) -> FatigueLevel {
        // Implementation for calculating fatigue level
        return .moderate
    }
    
    private func calculateReadinessScore(user: User, healthMetrics: HealthStats) -> Double {
        // Implementation for calculating readiness score
        return 0.75
    }
    
    private func predictWorkoutDuration(workout: Workout, readiness: Double) -> TimeInterval {
        // Implementation for predicting workout duration
        return workout.duration
    }
    
    private func predictCalorieBurn(workout: Workout, user: User, readiness: Double) -> Int {
        // Implementation for predicting calorie burn
        return workout.calories
    }
    
    private func predictWorkoutDifficulty(workout: Workout, fatigue: FatigueLevel) -> Difficulty {
        // Implementation for predicting workout difficulty
        return workout.difficulty
    }
    
    private func generateWorkoutRecommendations(
        workout: Workout,
        readiness: Double,
        fatigue: FatigueLevel
    ) -> [WorkoutRecommendation] {
        // Implementation for generating workout recommendations
        return []
    }
    
    private func calculatePredictionConfidence(recentWorkouts: [Workout]) -> Double {
        // Implementation for calculating prediction confidence
        return 0.85
    }
    
    // Additional helper methods would be implemented here...
    // For brevity, I'm showing the core structure
}

// MARK: - Supporting Types

struct AnalyticsResult {
    let timestamp: Date
    let type: AnalyticsType
    let data: Any
}

enum AnalyticsType {
    case progressAnalysis
    case performancePrediction
    case recoveryAnalysis
    case goalPrediction
    case personalizedInsights
    case correlationAnalysis
    case trainingOptimization
    case injuryRiskAssessment
}

struct ProgressAnalysis {
    let userId: String
    let period: AnalyticsPeriod
    let workoutIntensity: WorkoutIntensity
    let consistencyScore: Double
    let improvementRate: Double
    let recoveryEfficiency: Double
    let nextWeekPrediction: NextWeekPrediction
    let monthlyProjection: MonthlyProjection
    let trends: [TrendData]
    let patterns: [PerformancePattern]
    let recommendations: [ProgressRecommendation]
}

struct PerformancePrediction {
    let workoutId: String
    let predictedDuration: TimeInterval
    let predictedCalories: Int
    let predictedDifficulty: Difficulty
    let readinessScore: Double
    let fatigueLevel: FatigueLevel
    let recommendations: [WorkoutRecommendation]
    let confidence: Double
}

struct RecoveryAnalysis {
    let userId: String
    let averageRecoveryTime: TimeInterval
    let sleepQuality: SleepQuality
    let stressLevel: StressLevel
    let nutritionImpact: NutritionImpact
    let insights: [RecoveryInsight]
    let optimalRecovery: OptimalRecovery
    let recommendations: [RecoveryRecommendation]
}

struct GoalPrediction {
    let goalId: String
    let currentProgress: Double
    let progressRate: Double
    let predictedTimeline: TimeInterval
    let successProbability: Double
    let strategies: [OptimizationStrategy]
    let recommendations: [GoalRecommendation]
}

struct PersonalizedInsight {
    let id: String
    let type: InsightType
    let title: String
    let description: String
    let priority: InsightPriority
    let actionable: Bool
    let action: String?
}

enum InsightType {
    case performance
    case health
    case recovery
    case goal
}

enum InsightPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
}

struct CorrelationAnalysis {
    let userId: String
    let sleepPerformanceCorrelation: CorrelationData
    let nutritionRecoveryCorrelation: CorrelationData
    let stressPerformanceCorrelation: CorrelationData
    let workoutFrequencyCorrelation: CorrelationData
    let insights: [CorrelationInsight]
}

struct TrainingOptimization {
    let userId: String
    let currentFrequency: TrainingFrequency
    let optimalFrequency: TrainingFrequency
    let recommendations: [TrainingRecommendation]
    let optimalSchedule: TrainingSchedule
    let expectedImprovements: [ExpectedImprovement]
}

struct InjuryRiskAssessment {
    let userId: String
    let overallRisk: RiskLevel
    let overtrainingRisk: RiskLevel
    let formRisk: RiskLevel
    let recoveryRisk: RiskLevel
    let loadRisk: RiskLevel
    let preventionStrategies: [PreventionStrategy]
    let recommendations: [InjuryPreventionRecommendation]
}

// Additional supporting types would be defined here...
// For brevity, I'm showing the core structure

enum FatigueLevel: String, Codable {
    case low
    case moderate
    case high
    case veryHigh
}

enum SleepQuality: String, Codable {
    case poor
    case fair
    case good
    case excellent
}

enum StressLevel: String, Codable {
    case low
    case moderate
    case high
    case veryHigh
}

enum NutritionImpact: String, Codable {
    case negative
    case neutral
    case positive
    case veryPositive
}

enum RiskLevel: String, Codable {
    case low
    case moderate
    case high
    case veryHigh
}

struct RecentPerformance {
    let averageIntensity: WorkoutIntensity
    let consistency: Double
    let improvement: Double
}

struct NextWeekPrediction {
    let expectedWorkouts: Int
    let predictedIntensity: WorkoutIntensity
    let expectedCalories: Int
}

struct MonthlyProjection {
    let projectedProgress: Double
    let expectedAchievements: Int
    let projectedCalories: Int
}

struct PerformancePattern {
    let type: PatternType
    let frequency: Double
    let impact: PatternImpact
}

enum PatternType: String, Codable {
    case morningWorkouts
    case weekendIntensity
    case recoveryCycles
    case performancePeaks
}

enum PatternImpact: String, Codable {
    case positive
    case negative
    case neutral
}

struct WorkoutRecommendation {
    let type: RecommendationType
    let description: String
    let priority: Priority
}

struct RecoveryRecommendation {
    let type: RecommendationType
    let description: String
    let priority: Priority
}

struct GoalRecommendation {
    let type: RecommendationType
    let description: String
    let priority: Priority
}

struct CorrelationData {
    let correlation: Double
    let significance: Double
    let sampleSize: Int
}

struct CorrelationInsight {
    let factor1: String
    let factor2: String
    let correlation: Double
    let interpretation: String
}

struct TrainingFrequency {
    let workoutsPerWeek: Int
    let restDays: Int
    let intensity: WorkoutIntensity
}

struct TrainingSchedule {
    let weeklyPlan: [DaySchedule]
    let restDays: [Weekday]
    let intensityProgression: [IntensityProgression]
}

struct ExpectedImprovement {
    let metric: String
    let currentValue: Double
    let projectedValue: Double
    let timeframe: TimeInterval
}

struct PreventionStrategy {
    let type: StrategyType
    let description: String
    let effectiveness: Double
}

enum StrategyType: String, Codable {
    case loadManagement
    case recoveryOptimization
    case formImprovement
    case nutritionAdjustment
}

// Additional types would be defined here...
// For brevity, I'm showing the core structure

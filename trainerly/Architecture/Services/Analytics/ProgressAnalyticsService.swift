import Foundation
import Combine
import CoreData

// MARK: - Progress Analytics Service Protocol
protocol ProgressAnalyticsServiceProtocol {
    func getProgressOverview(for user: User, period: AnalyticsPeriod) async throws -> ProgressOverview
    func getWorkoutTrends(for user: User, period: AnalyticsPeriod) async throws -> WorkoutTrends
    func getStrengthProgress(for user: User, period: AnalyticsPeriod) async throws -> StrengthProgress
    func getCardioProgress(for user: User, period: AnalyticsPeriod) async throws -> CardioProgress
    func getFormImprovement(for user: User, period: AnalyticsPeriod) async throws -> FormImprovement
    func getPersonalRecords(for user: User) async throws -> [PersonalRecord]
    func getAchievements(for user: User) async throws -> [Achievement]
    func getRecommendations(for user: User) async throws -> [ProgressRecommendation]
    func generateProgressReport(for user: User, period: AnalyticsPeriod) async throws -> ProgressReport
}

// MARK: - Progress Analytics Service
final class ProgressAnalyticsService: ProgressAnalyticsServiceProtocol {
    
    // MARK: - Properties
    private let workoutRepository: WorkoutRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let aiWorkoutGenerator: AIWorkoutGeneratorProtocol
    private let coreDataStack: CoreDataStackProtocol
    
    // MARK: - Initialization
    init(
        workoutRepository: WorkoutRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        healthKitManager: HealthKitManagerProtocol,
        aiWorkoutGenerator: AIWorkoutGeneratorProtocol,
        coreDataStack: CoreDataStackProtocol
    ) {
        self.workoutRepository = workoutRepository
        self.userRepository = userRepository
        self.healthKitManager = healthKitManager
        self.aiWorkoutGenerator = aiWorkoutGenerator
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - Public Methods
    func getProgressOverview(for user: User, period: AnalyticsPeriod) async throws -> ProgressOverview {
        // Get workouts for the period
        let workouts = try await getWorkouts(for: user, period: period)
        
        // Calculate key metrics
        let totalWorkouts = workouts.count
        let totalDuration = workouts.reduce(0) { $0 + $1.duration }
        let totalCalories = workouts.reduce(0) { $0 + $1.calories }
        let averageFormScore = calculateAverageFormScore(workouts: workouts)
        
        // Calculate progress vs previous period
        let previousPeriod = period.previousPeriod
        let previousWorkouts = try await getWorkouts(for: user, period: previousPeriod)
        
        let progressMetrics = calculateProgressMetrics(
            current: ProgressMetrics(
                totalWorkouts: totalWorkouts,
                totalDuration: totalDuration,
                totalCalories: totalCalories,
                averageFormScore: averageFormScore
            ),
            previous: ProgressMetrics(
                totalWorkouts: previousWorkouts.count,
                totalDuration: previousWorkouts.reduce(0) { $0 + $1.duration },
                totalCalories: previousWorkouts.reduce(0) { $0 + $1.calories },
                averageFormScore: calculateAverageFormScore(workouts: previousWorkouts)
            )
        )
        
        return ProgressOverview(
            period: period,
            metrics: progressMetrics,
            topMuscleGroups: getTopMuscleGroups(workouts: workouts),
            workoutTypeDistribution: getWorkoutTypeDistribution(workouts: workouts),
            consistencyScore: calculateConsistencyScore(workouts: workouts, period: period)
        )
    }
    
    func getWorkoutTrends(for user: User, period: AnalyticsPeriod) async throws -> WorkoutTrends {
        let workouts = try await getWorkouts(for: user, period: period)
        
        // Group workouts by time intervals
        let groupedWorkouts = groupWorkoutsByTimeInterval(workouts: workouts, period: period)
        
        // Calculate trends
        let frequencyTrend = calculateFrequencyTrend(groupedWorkouts: groupedWorkouts)
        let durationTrend = calculateDurationTrend(groupedWorkouts: groupedWorkouts)
        let intensityTrend = calculateIntensityTrend(groupedWorkouts: groupedWorkouts)
        
        return WorkoutTrends(
            period: period,
            frequencyTrend: frequencyTrend,
            durationTrend: durationTrend,
            intensityTrend: intensityTrend,
            weeklyPattern: analyzeWeeklyPattern(workouts: workouts),
            monthlyComparison: await getMonthlyComparison(for: user, period: period)
        )
    }
    
    func getStrengthProgress(for user: User, period: AnalyticsPeriod) async throws -> StrengthProgress {
        let workouts = try await getWorkouts(for: user, period: period)
        let strengthWorkouts = workouts.filter { $0.type == .strength }
        
        // Analyze strength metrics
        let exerciseProgress = analyzeExerciseProgress(workouts: strengthWorkouts)
        let weightProgress = analyzeWeightProgress(workouts: strengthWorkouts)
        let volumeProgress = analyzeVolumeProgress(workouts: strengthWorkouts)
        
        return StrengthProgress(
            period: period,
            exerciseProgress: exerciseProgress,
            weightProgress: weightProgress,
            volumeProgress: volumeProgress,
            personalRecords: try await getPersonalRecords(for: user),
            recommendations: generateStrengthRecommendations(exerciseProgress: exerciseProgress)
        )
    }
    
    func getCardioProgress(for user: User, period: AnalyticsPeriod) async throws -> CardioProgress {
        let workouts = try await getWorkouts(for: user, period: period)
        let cardioWorkouts = workouts.filter { $0.type == .cardio || $0.type == .hiit }
        
        // Get HealthKit data for more accurate cardio metrics
        let healthStats = try await healthKitManager.fetchTodayStats()
        
        // Analyze cardio metrics
        let enduranceProgress = analyzeEnduranceProgress(workouts: cardioWorkouts)
        let heartRateProgress = analyzeHeartRateProgress(workouts: cardioWorkouts)
        let distanceProgress = analyzeDistanceProgress(workouts: cardioWorkouts)
        
        return CardioProgress(
            period: period,
            enduranceProgress: enduranceProgress,
            heartRateProgress: heartRateProgress,
            distanceProgress: distanceProgress,
            vo2Max: healthStats.vo2Max,
            restingHeartRate: healthStats.restingHeartRate,
            recommendations: generateCardioRecommendations(enduranceProgress: enduranceProgress)
        )
    }
    
    func getFormImprovement(for user: User, period: AnalyticsPeriod) async throws -> FormImprovement {
        let workouts = try await getWorkouts(for: user, period: period)
        
        // Analyze form scores over time
        let formScoreTrend = analyzeFormScoreTrend(workouts: workouts)
        let exerciseFormBreakdown = analyzeExerciseFormBreakdown(workouts: workouts)
        let improvementAreas = identifyImprovementAreas(formScoreTrend: formScoreTrend)
        
        return FormImprovement(
            period: period,
            formScoreTrend: formScoreTrend,
            exerciseFormBreakdown: exerciseFormBreakdown,
            improvementAreas: improvementAreas,
            recommendations: generateFormRecommendations(improvementAreas: improvementAreas)
        )
    }
    
    func getPersonalRecords(for user: User) async throws -> [PersonalRecord] {
        let workouts = try await workoutRepository.getWorkoutHistory(limit: 1000)
        let userWorkouts = workouts.filter { $0.user?.id == user.id }
        
        var personalRecords: [PersonalRecord] = []
        
        // Analyze each exercise for personal records
        let exerciseGroups = Dictionary(grouping: userWorkouts.flatMap { $0.exercises ?? [] }) { $0.exercise?.name ?? "" }
        
        for (exerciseName, workoutExercises) in exerciseGroups {
            if let maxWeight = workoutExercises.compactMap({ $0.weight }).max() {
                personalRecords.append(PersonalRecord(
                    exercise: exerciseName,
                    type: .maxWeight,
                    value: maxWeight,
                    date: workoutExercises.first?.startTime ?? Date(),
                    workout: workoutExercises.first?.workout
                ))
            }
            
            if let maxReps = workoutExercises.compactMap({ $0.reps }).max() {
                personalRecords.append(PersonalRecord(
                    exercise: exerciseName,
                    type: .maxReps,
                    value: Double(maxReps),
                    date: workoutExercises.first?.startTime ?? Date(),
                    workout: workoutExercises.first?.workout
                ))
            }
            
            if let maxDuration = workoutExercises.compactMap({ $0.duration }).max() {
                personalRecords.append(PersonalRecord(
                    exercise: exerciseName,
                    type: .maxDuration,
                    value: maxDuration,
                    date: workoutExercises.first?.startTime ?? Date(),
                    workout: workoutExercises.first?.workout
                ))
            }
        }
        
        return personalRecords.sorted { $0.date > $1.date }
    }
    
    func getAchievements(for user: User) async throws -> [Achievement] {
        // Get user's achievements from Core Data
        let context = coreDataStack.viewContext
        let fetchRequest: NSFetchRequest<Achievement> = Achievement.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "user.id == %@", user.id ?? "")
        
        let achievements = try context.fetch(fetchRequest)
        return achievements
    }
    
    func getRecommendations(for user: User) async throws -> [ProgressRecommendation] {
        var recommendations: [ProgressRecommendation] = []
        
        // Get recent progress data
        let recentProgress = try await getProgressOverview(for: user, period: .month)
        
        // Generate recommendations based on progress
        if recentProgress.metrics.consistencyScore < 0.7 {
            recommendations.append(ProgressRecommendation(
                type: .consistency,
                title: "Improve Workout Consistency",
                description: "Try to maintain a regular workout schedule for better results",
                priority: .high,
                actionItems: ["Set workout reminders", "Plan workouts in advance", "Start with shorter sessions"]
            ))
        }
        
        if recentProgress.metrics.averageFormScore < 80.0 {
            recommendations.append(ProgressRecommendation(
                type: .form,
                title: "Focus on Form Quality",
                description: "Better form leads to better results and fewer injuries",
                priority: .medium,
                actionItems: ["Use form analysis features", "Practice with lighter weights", "Consider working with a trainer"]
            ))
        }
        
        // Add AI-generated recommendations
        let aiRecommendations = try await generateAIRecommendations(for: user, progress: recentProgress)
        recommendations.append(contentsOf: aiRecommendations)
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    func generateProgressReport(for user: User, period: AnalyticsPeriod) async throws -> ProgressReport {
        let overview = try await getProgressOverview(for: user, period: period)
        let trends = try await getWorkoutTrends(for: user, period: period)
        let strengthProgress = try await getStrengthProgress(for: user, period: period)
        let cardioProgress = try await getCardioProgress(for: user, period: period)
        let formImprovement = try await getFormImprovement(for: user, period: period)
        let recommendations = try await getRecommendations(for: user)
        
        return ProgressReport(
            user: user,
            period: period,
            overview: overview,
            trends: trends,
            strengthProgress: strengthProgress,
            cardioProgress: cardioProgress,
            formImprovement: formImprovement,
            recommendations: recommendations,
            generatedAt: Date()
        )
    }
    
    // MARK: - Private Methods
    private func getWorkouts(for user: User, period: AnalyticsPeriod) async throws -> [Workout] {
        let allWorkouts = try await workoutRepository.getWorkoutHistory(limit: 1000)
        let userWorkouts = allWorkouts.filter { $0.user?.id == user.id }
        
        let startDate = period.startDate
        let endDate = period.endDate
        
        return userWorkouts.filter { workout in
            workout.startTime >= startDate && workout.startTime <= endDate
        }
    }
    
    private func calculateAverageFormScore(workouts: [Workout]) -> Double {
        let workoutsWithForm = workouts.filter { $0.averageFormScore > 0 }
        guard !workoutsWithForm.isEmpty else { return 0.0 }
        
        let totalScore = workoutsWithForm.reduce(0.0) { $0 + $1.averageFormScore }
        return totalScore / Double(workoutsWithForm.count)
    }
    
    private func calculateProgressMetrics(current: ProgressMetrics, previous: ProgressMetrics) -> ProgressMetrics {
        let workoutChange = calculatePercentageChange(current: current.totalWorkouts, previous: previous.totalWorkouts)
        let durationChange = calculatePercentageChange(current: current.totalDuration, previous: previous.totalDuration)
        let caloriesChange = calculatePercentageChange(current: current.totalCalories, previous: previous.totalCalories)
        let formChange = calculatePercentageChange(current: current.averageFormScore, previous: previous.averageFormScore)
        
        return ProgressMetrics(
            totalWorkouts: current.totalWorkouts,
            totalDuration: current.totalDuration,
            totalCalories: current.totalCalories,
            averageFormScore: current.averageFormScore,
            workoutChange: workoutChange,
            durationChange: durationChange,
            caloriesChange: caloriesChange,
            formChange: formChange
        )
    }
    
    private func calculatePercentageChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0.0 }
        return ((current - previous) / previous) * 100.0
    }
    
    private func getTopMuscleGroups(workouts: [Workout]) -> [MuscleGroupProgress] {
        // Analyze muscle group usage from workouts
        var muscleGroupCounts: [String: Int] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                if let muscleGroups = exercise.exercise?.muscleGroups {
                    for muscleGroup in muscleGroups {
                        muscleGroupCounts[muscleGroup, default: 0] += 1
                    }
                }
            }
        }
        
        return muscleGroupCounts.map { muscleGroup, count in
            MuscleGroupProgress(
                muscleGroup: MuscleGroup(rawValue: muscleGroup) ?? .fullBody,
                workoutCount: count,
                percentage: Double(count) / Double(workouts.count) * 100.0
            )
        }.sorted { $0.workoutCount > $1.workoutCount }
    }
    
    private func getWorkoutTypeDistribution(workouts: [Workout]) -> [WorkoutTypeDistribution] {
        var typeCounts: [WorkoutType: Int] = [:]
        
        for workout in workouts {
            if let type = workout.type {
                let workoutType = WorkoutType(rawValue: type) ?? .strength
                typeCounts[workoutType, default: 0] += 1
            }
        }
        
        return typeCounts.map { type, count in
            WorkoutTypeDistribution(
                type: type,
                count: count,
                percentage: Double(count) / Double(workouts.count) * 100.0
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func calculateConsistencyScore(workouts: [Workout], period: AnalyticsPeriod) -> Double {
        let expectedWorkouts = period.expectedWorkoutFrequency
        let actualWorkouts = workouts.count
        
        return min(Double(actualWorkouts) / Double(expectedWorkouts), 1.0)
    }
    
    private func groupWorkoutsByTimeInterval(workouts: [Workout], period: AnalyticsPeriod) -> [String: [Workout]] {
        var grouped: [String: [Workout]] = [:]
        
        for workout in workouts {
            let interval = period.getTimeInterval(for: workout.startTime)
            grouped[interval, default: []].append(workout)
        }
        
        return grouped
    }
    
    private func calculateFrequencyTrend(groupedWorkouts: [String: [Workout]]) -> TrendData {
        let sortedIntervals = groupedWorkouts.keys.sorted()
        let frequencies = sortedIntervals.map { groupedWorkouts[$0]?.count ?? 0 }
        
        return TrendData(
            values: frequencies,
            trend: calculateTrendDirection(values: frequencies),
            slope: calculateTrendSlope(values: frequencies)
        )
    }
    
    private func calculateDurationTrend(groupedWorkouts: [String: [Workout]]) -> TrendData {
        let sortedIntervals = groupedWorkouts.keys.sorted()
        let durations = sortedIntervals.map { interval in
            let workouts = groupedWorkouts[interval] ?? []
            return workouts.reduce(0) { $0 + $1.duration }
        }
        
        return TrendData(
            values: durations,
            trend: calculateTrendDirection(values: durations),
            slope: calculateTrendSlope(values: durations)
        )
    }
    
    private func calculateIntensityTrend(groupedWorkouts: [String: [Workout]]) -> TrendData {
        let sortedIntervals = groupedWorkouts.keys.sorted()
        let intensities = sortedIntervals.map { interval in
            let workouts = groupedWorkouts[interval] ?? []
            return workouts.reduce(0) { $0 + $1.calories }
        }
        
        return TrendData(
            values: intensities,
            trend: calculateTrendDirection(values: intensities),
            slope: calculateTrendSlope(values: intensities)
        )
    }
    
    private func calculateTrendDirection(values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let firstHalf = Array(values.prefix(values.count / 2))
        let secondHalf = Array(values.suffix(values.count / 2))
        
        let firstAverage = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0, +) / Double(secondHalf.count)
        
        let change = secondAverage - firstAverage
        let threshold = firstAverage * 0.1 // 10% threshold
        
        if change > threshold {
            return .increasing
        } else if change < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateTrendSlope(values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        let xValues = Array(0..<values.count).map { Double($0) }
        let yValues = values
        
        let n = Double(xValues.count)
        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        return slope
    }
    
    private func analyzeWeeklyPattern(workouts: [Workout]) -> WeeklyPattern {
        var dayCounts: [Int: Int] = [:]
        
        for workout in workouts {
            let weekday = Calendar.current.component(.weekday, from: workout.startTime)
            dayCounts[weekday, default: 0] += 1
        }
        
        let mostActiveDay = dayCounts.max { $0.value < $1.value }?.key ?? 1
        let leastActiveDay = dayCounts.min { $0.value < $1.value }?.key ?? 1
        
        return WeeklyPattern(
            mostActiveDay: mostActiveDay,
            leastActiveDay: leastActiveDay,
            dayDistribution: dayCounts
        )
    }
    
    private func getMonthlyComparison(for user: User, period: AnalyticsPeriod) async -> MonthlyComparison {
        // Compare current month with previous month
        let currentMonth = period
        let previousMonth = period.previousPeriod
        
        let currentProgress = try await getProgressOverview(for: user, period: currentMonth)
        let previousProgress = try await getProgressOverview(for: user, period: previousMonth)
        
        return MonthlyComparison(
            currentMonth: currentProgress,
            previousMonth: previousProgress,
            improvement: calculateImprovement(current: currentProgress, previous: previousProgress)
        )
    }
    
    private func analyzeExerciseProgress(workouts: [Workout]) -> [ExerciseProgress] {
        // Analyze progress for individual exercises
        var exerciseProgress: [String: ExerciseProgress] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                let exerciseName = exercise.exercise?.name ?? "Unknown"
                
                if exerciseProgress[exerciseName] == nil {
                    exerciseProgress[exerciseName] = ExerciseProgress(
                        name: exerciseName,
                        totalWorkouts: 0,
                        maxWeight: 0,
                        maxReps: 0,
                        averageFormScore: 0,
                        improvement: 0
                    )
                }
                
                exerciseProgress[exerciseName]?.totalWorkouts += 1
                exerciseProgress[exerciseName]?.maxWeight = max(exerciseProgress[exerciseName]?.maxWeight ?? 0, exercise.weight ?? 0)
                exerciseProgress[exerciseName]?.maxReps = max(exerciseProgress[exerciseName]?.maxReps ?? 0, exercise.reps ?? 0)
                exerciseProgress[exerciseName]?.averageFormScore = (exerciseProgress[exerciseName]?.averageFormScore ?? 0) + (exercise.formScore ?? 0)
            }
        }
        
        // Calculate averages and improvements
        for exerciseName in exerciseProgress.keys {
            let progress = exerciseProgress[exerciseName]!
            progress.averageFormScore = progress.averageFormScore / Double(progress.totalWorkouts)
            // Calculate improvement over time would require more complex analysis
        }
        
        return Array(exerciseProgress.values)
    }
    
    private func analyzeWeightProgress(workouts: [Workout]) -> WeightProgress {
        // Analyze weight progression over time
        let weightData = workouts.flatMap { workout in
            workout.exercises?.compactMap { exercise in
                exercise.weight
            } ?? []
        }
        
        let maxWeight = weightData.max() ?? 0
        let averageWeight = weightData.isEmpty ? 0 : weightData.reduce(0, +) / Double(weightData.count)
        
        return WeightProgress(
            maxWeight: maxWeight,
            averageWeight: averageWeight,
            progression: calculateWeightProgression(workouts: workouts)
        )
    }
    
    private func analyzeVolumeProgress(workouts: [Workout]) -> VolumeProgress {
        // Analyze volume (sets × reps × weight) progression
        var volumeData: [Double] = []
        
        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                let volume = Double(exercise.sets ?? 0) * Double(exercise.reps ?? 0) * (exercise.weight ?? 0)
                volumeData.append(volume)
            }
        }
        
        let totalVolume = volumeData.reduce(0, +)
        let averageVolume = volumeData.isEmpty ? 0 : totalVolume / Double(volumeData.count)
        
        return VolumeProgress(
            totalVolume: totalVolume,
            averageVolume: averageVolume,
            progression: calculateVolumeProgression(workouts: workouts)
        )
    }
    
    private func analyzeEnduranceProgress(workouts: [Workout]) -> EnduranceProgress {
        let cardioWorkouts = workouts.filter { $0.type == .cardio || $0.type == .hiit }
        
        let totalDuration = cardioWorkouts.reduce(0) { $0 + $1.duration }
        let averageDuration = cardioWorkouts.isEmpty ? 0 : totalDuration / Double(cardioWorkouts.count)
        let maxDuration = cardioWorkouts.map { $0.duration }.max() ?? 0
        
        return EnduranceProgress(
            totalDuration: totalDuration,
            averageDuration: averageDuration,
            maxDuration: maxDuration,
            improvement: calculateEnduranceImprovement(workouts: cardioWorkouts)
        )
    }
    
    private func analyzeHeartRateProgress(workouts: [Workout]) -> HeartRateProgress {
        let workoutsWithHR = workouts.filter { $0.averageHeartRate > 0 }
        
        let averageHR = workoutsWithHR.isEmpty ? 0 : workoutsWithHR.reduce(0) { $0 + $1.averageHeartRate } / Double(workoutsWithHR.count)
        let maxHR = workoutsWithHR.map { $0.maxHeartRate }.max() ?? 0
        
        return HeartRateProgress(
            averageHeartRate: averageHR,
            maxHeartRate: maxHR,
            improvement: calculateHeartRateImprovement(workouts: workoutsWithHR)
        )
    }
    
    private func analyzeDistanceProgress(workouts: [Workout]) -> DistanceProgress {
        let workoutsWithDistance = workouts.filter { $0.distance > 0 }
        
        let totalDistance = workoutsWithDistance.reduce(0) { $0 + $1.distance }
        let averageDistance = workoutsWithDistance.isEmpty ? 0 : totalDistance / Double(workoutsWithDistance.count)
        let maxDistance = workoutsWithDistance.map { $0.distance }.max() ?? 0
        
        return DistanceProgress(
            totalDistance: totalDistance,
            averageDistance: averageDistance,
            maxDistance: maxDistance,
            improvement: calculateDistanceImprovement(workouts: workoutsWithDistance)
        )
    }
    
    private func analyzeFormScoreTrend(workouts: [Workout]) -> FormScoreTrend {
        let sortedWorkouts = workouts.sorted { $0.startTime < $1.startTime }
        let formScores = sortedWorkouts.compactMap { $0.averageFormScore }
        
        return FormScoreTrend(
            scores: formScores,
            trend: calculateTrendDirection(values: formScores),
            improvement: calculateFormImprovement(scores: formScores)
        )
    }
    
    private func analyzeExerciseFormBreakdown(workouts: [Workout]) -> [ExerciseFormBreakdown] {
        var exerciseFormData: [String: [Double]] = [:]
        
        for workout in workouts {
            for exercise in workout.exercises ?? [] {
                let exerciseName = exercise.exercise?.name ?? "Unknown"
                if let formScore = exercise.formScore {
                    exerciseFormData[exerciseName, default: []].append(formScore)
                }
            }
        }
        
        return exerciseFormData.map { exerciseName, scores in
            let average = scores.reduce(0, +) / Double(scores.count)
            let trend = calculateTrendDirection(values: scores)
            
            return ExerciseFormBreakdown(
                exercise: exerciseName,
                averageScore: average,
                trend: trend,
                improvement: calculateFormImprovement(scores: scores)
            )
        }.sorted { $0.averageScore > $1.averageScore }
    }
    
    private func identifyImprovementAreas(formScoreTrend: FormScoreTrend) -> [ImprovementArea] {
        var areas: [ImprovementArea] = []
        
        if formScoreTrend.trend == .decreasing {
            areas.append(ImprovementArea(
                category: .form,
                description: "Form scores are declining. Focus on proper technique.",
                priority: .high
            ))
        }
        
        if formScoreTrend.improvement < 5.0 {
            areas.append(ImprovementArea(
                category: .technique,
                description: "Consider working with a trainer to improve form.",
                priority: .medium
            ))
        }
        
        return areas
    }
    
    private func generateStrengthRecommendations(exerciseProgress: [ExerciseProgress]) -> [String] {
        var recommendations: [String] = []
        
        // Analyze exercise variety
        if exerciseProgress.count < 5 {
            recommendations.append("Try incorporating more exercise variety to target different muscle groups")
        }
        
        // Analyze form scores
        let lowFormExercises = exerciseProgress.filter { $0.averageFormScore < 70 }
        if !lowFormExercises.isEmpty {
            recommendations.append("Focus on improving form for \(lowFormExercises.map { $0.name }.joined(separator: ", "))")
        }
        
        return recommendations
    }
    
    private func generateCardioRecommendations(enduranceProgress: EnduranceProgress) -> [String] {
        var recommendations: [String] = []
        
        if enduranceProgress.averageDuration < 20 * 60 { // Less than 20 minutes
            recommendations.append("Gradually increase cardio session duration for better endurance")
        }
        
        if enduranceProgress.improvement < 10.0 {
            recommendations.append("Consider adding interval training to improve cardiovascular fitness")
        }
        
        return recommendations
    }
    
    private func generateFormRecommendations(improvementAreas: [ImprovementArea]) -> [String] {
        return improvementAreas.map { area in
            switch area.category {
            case .form:
                return "Use the form analysis feature during workouts to get real-time feedback"
            case .technique:
                return "Practice exercises with lighter weights to perfect your form"
            case .consistency:
                return "Maintain regular workout schedule to build muscle memory"
            }
        }
    }
    
    private func generateAIRecommendations(for user: User, progress: ProgressOverview) async throws -> [ProgressRecommendation] {
        // Use AI to generate personalized recommendations
        let context = buildAIRecommendationContext(user: user, progress: progress)
        
        // This would call the AI service to generate recommendations
        // For now, return empty array
        return []
    }
    
    private func buildAIRecommendationContext(user: User, progress: ProgressOverview) -> [String: Any] {
        return [
            "user_profile": [
                "fitness_level": user.fitnessLevel ?? "beginner",
                "goals": user.goals ?? [],
                "age": calculateAge(from: user.dateOfBirth)
            ],
            "progress_metrics": [
                "consistency_score": progress.metrics.consistencyScore,
                "form_score": progress.metrics.averageFormScore,
                "workout_frequency": progress.metrics.totalWorkouts
            ]
        ]
    }
    
    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dateOfBirth = dateOfBirth else { return 25 }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 25
    }
    
    // Placeholder methods for complex calculations
    private func calculateWeightProgression(workouts: [Workout]) -> Double { return 0.0 }
    private func calculateVolumeProgression(workouts: [Workout]) -> Double { return 0.0 }
    private func calculateEnduranceImprovement(workouts: [Workout]) -> Double { return 0.0 }
    private func calculateHeartRateImprovement(workouts: [Workout]) -> Double { return 0.0 }
    private func calculateDistanceImprovement(workouts: [Workout]) -> Double { return 0.0 }
    private func calculateFormImprovement(scores: [Double]) -> Double { return 0.0 }
    private func calculateImprovement(current: ProgressOverview, previous: ProgressOverview) -> Double { return 0.0 }
}

// MARK: - Data Models
enum AnalyticsPeriod: CaseIterable {
    case week
    case month
    case quarter
    case year
    
    var startDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let quarterStartMonth = quarter * 3 + 1
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterStartMonth
            components.day = 1
            return calendar.date(from: components) ?? now
        case .year:
            return calendar.dateInterval(of: .year, for: now)?.start ?? now
        }
    }
    
    var endDate: Date {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.end ?? now
        case .quarter:
            let quarter = (calendar.component(.month, from: now) - 1) / 3
            let quarterEndMonth = (quarter + 1) * 3
            var components = calendar.dateComponents([.year], from: now)
            components.month = quarterEndMonth
            components.day = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
            return calendar.date(from: components) ?? now
        case .year:
            return calendar.dateInterval(of: .year, for: now)?.end ?? now
        }
    }
    
    var previousPeriod: AnalyticsPeriod {
        switch self {
        case .week:
            let calendar = Calendar.current
            let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) ?? Date()
            return .week
        case .month:
            let calendar = Calendar.current
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return .month
        case .quarter:
            let calendar = Calendar.current
            let previousQuarter = calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            return .quarter
        case .year:
            let calendar = Calendar.current
            let previousYear = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return .year
        }
    }
    
    var expectedWorkoutFrequency: Int {
        switch self {
        case .week: return 3
        case .month: return 12
        case .quarter: return 36
        case .year: return 144
        }
    }
    
    func getTimeInterval(for date: Date) -> String {
        let calendar = Calendar.current
        
        switch self {
        case .week:
            let weekday = calendar.component(.weekday, from: date)
            return "Day \(weekday)"
        case .month:
            let weekOfMonth = calendar.component(.weekOfMonth, from: date)
            return "Week \(weekOfMonth)"
        case .quarter:
            let month = calendar.component(.month, from: date)
            let quarterMonth = ((month - 1) % 3) + 1
            return "Month \(quarterMonth)"
        case .year:
            let month = calendar.component(.month, from: date)
            return "Month \(month)"
        }
    }
}

struct ProgressOverview {
    let period: AnalyticsPeriod
    let metrics: ProgressMetrics
    let topMuscleGroups: [MuscleGroupProgress]
    let workoutTypeDistribution: [WorkoutTypeDistribution]
    let consistencyScore: Double
}

struct ProgressMetrics {
    let totalWorkouts: Int
    let totalDuration: TimeInterval
    let totalCalories: Double
    let averageFormScore: Double
    var workoutChange: Double = 0
    var durationChange: Double = 0
    var caloriesChange: Double = 0
    var formChange: Double = 0
}

struct MuscleGroupProgress {
    let muscleGroup: MuscleGroup
    let workoutCount: Int
    let percentage: Double
}

struct WorkoutTypeDistribution {
    let type: WorkoutType
    let count: Int
    let percentage: Double
}

struct WorkoutTrends {
    let period: AnalyticsPeriod
    let frequencyTrend: TrendData
    let durationTrend: TrendData
    let intensityTrend: TrendData
    let weeklyPattern: WeeklyPattern
    let monthlyComparison: MonthlyComparison
}

struct TrendData {
    let values: [Double]
    let trend: TrendDirection
    let slope: Double
}

enum TrendDirection: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
}

struct WeeklyPattern {
    let mostActiveDay: Int
    let leastActiveDay: Int
    let dayDistribution: [Int: Int]
}

struct MonthlyComparison {
    let currentMonth: ProgressOverview
    let previousMonth: ProgressOverview
    let improvement: Double
}

struct StrengthProgress {
    let period: AnalyticsPeriod
    let exerciseProgress: [ExerciseProgress]
    let weightProgress: WeightProgress
    let volumeProgress: VolumeProgress
    let personalRecords: [PersonalRecord]
    let recommendations: [String]
}

struct ExerciseProgress {
    let name: String
    var totalWorkouts: Int
    var maxWeight: Double
    var maxReps: Int
    var averageFormScore: Double
    var improvement: Double
}

struct WeightProgress {
    let maxWeight: Double
    let averageWeight: Double
    let progression: Double
}

struct VolumeProgress {
    let totalVolume: Double
    let averageVolume: Double
    let progression: Double
}

struct CardioProgress {
    let period: AnalyticsPeriod
    let enduranceProgress: EnduranceProgress
    let heartRateProgress: HeartRateProgress
    let distanceProgress: DistanceProgress
    let vo2Max: Double?
    let restingHeartRate: Int
    let recommendations: [String]
}

struct EnduranceProgress {
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let maxDuration: TimeInterval
    let improvement: Double
}

struct HeartRateProgress {
    let averageHeartRate: Int
    let maxHeartRate: Int
    let improvement: Double
}

struct DistanceProgress {
    let totalDistance: Double
    let averageDistance: Double
    let maxDistance: Double
    let improvement: Double
}

struct FormImprovement {
    let period: AnalyticsPeriod
    let formScoreTrend: FormScoreTrend
    let exerciseFormBreakdown: [ExerciseFormBreakdown]
    let improvementAreas: [ImprovementArea]
    let recommendations: [String]
}

struct FormScoreTrend {
    let scores: [Double]
    let trend: TrendDirection
    let improvement: Double
}

struct ExerciseFormBreakdown {
    let exercise: String
    let averageScore: Double
    let trend: TrendDirection
    let improvement: Double
}

struct ImprovementArea {
    let category: ImprovementCategory
    let description: String
    let priority: Priority
}

enum ImprovementCategory: String, CaseIterable {
    case form = "form"
    case technique = "technique"
    case consistency = "consistency"
}

struct PersonalRecord {
    let exercise: String
    let type: PersonalRecordType
    let value: Double
    let date: Date
    let workout: Workout?
}

enum PersonalRecordType: String, CaseIterable {
    case maxWeight = "max_weight"
    case maxReps = "max_reps"
    case maxDuration = "max_duration"
    case maxDistance = "max_distance"
}

struct ProgressRecommendation {
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let actionItems: [String]
}

enum RecommendationType: String, CaseIterable {
    case consistency = "consistency"
    case form = "form"
    case variety = "variety"
    case intensity = "intensity"
}

struct ProgressReport {
    let user: User
    let period: AnalyticsPeriod
    let overview: ProgressOverview
    let trends: WorkoutTrends
    let strengthProgress: StrengthProgress
    let cardioProgress: CardioProgress
    let formImprovement: FormImprovement
    let recommendations: [ProgressRecommendation]
    let generatedAt: Date
}

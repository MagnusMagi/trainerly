import Foundation
import CoreML
import Vision
import Combine

// MARK: - Form Improvement Predictor Protocol
protocol FormImprovementPredictorProtocol: ObservableObject {
    var isProcessing: Bool { get }
    var lastPrediction: FormImprovementPrediction? { get }
    
    func predictFormImprovement(user: User, exercise: Exercise) async throws -> FormImprovementPrediction
    func analyzeFormTrends(user: User, exercise: Exercise) async throws -> FormTrendAnalysis
    func generateFormRecommendations(user: User, exercise: Exercise) async throws -> [FormRecommendation]
    func trackFormProgress(user: User, exercise: Exercise) async throws -> FormProgressTracker
    func predictInjuryRisk(user: User, exercise: Exercise) async throws -> InjuryRiskPrediction
}

// MARK: - Form Improvement Predictor
final class FormImprovementPredictor: NSObject, FormImprovementPredictorProtocol {
    @Published var isProcessing: Bool = false
    @Published var lastPrediction: FormImprovementPrediction?
    
    private let mlModelManager: MLModelManagerProtocol
    private let formAnalysisService: FormAnalysisServiceProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let cacheService: CacheServiceProtocol
    
    private var formHistoryCache: [String: [FormAnalysisResult]] = [:]
    private var predictionCache: [String: FormImprovementPrediction] = [:]
    
    init(
        mlModelManager: MLModelManagerProtocol,
        formAnalysisService: FormAnalysisServiceProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.mlModelManager = mlModelManager
        self.formAnalysisService = formAnalysisService
        self.workoutRepository = workoutRepository
        self.userRepository = userRepository
        self.cacheService = cacheService
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    func predictFormImprovement(user: User, exercise: Exercise) async throws -> FormImprovementPrediction {
        isProcessing = true
        defer { isProcessing = false }
        
        let cacheKey = "form_improvement_\(user.id)_\(exercise.id)"
        
        // Check cache first
        if let cached = predictionCache[cacheKey] {
            return cached
        }
        
        // Gather form analysis history
        let formHistory = try await getFormHistory(user: user, exercise: exercise)
        let recentFormScores = formHistory.map { $0.formScore }
        
        // Use ML to predict improvement
        let prediction = try await generateFormImprovementPrediction(
            user: user,
            exercise: exercise,
            formHistory: formHistory,
            recentScores: recentFormScores
        )
        
        // Cache the prediction
        predictionCache[cacheKey] = prediction
        lastPrediction = prediction
        
        return prediction
    }
    
    func analyzeFormTrends(user: User, exercise: Exercise) async throws -> FormTrendAnalysis {
        let formHistory = try await getFormHistory(user: user, exercise: exercise)
        
        let trendAnalysis = analyzeFormTrendsFromHistory(
            formHistory: formHistory,
            exercise: exercise
        )
        
        return trendAnalysis
    }
    
    func generateFormRecommendations(user: User, exercise: Exercise) async throws -> [FormRecommendation] {
        let formHistory = try await getFormHistory(user: user, exercise: exercise)
        let recentForm = formHistory.first
        
        let recommendations = try await generatePersonalizedRecommendations(
            user: user,
            exercise: exercise,
            formHistory: formHistory,
            recentForm: recentForm
        )
        
        return recommendations
    }
    
    func trackFormProgress(user: User, exercise: Exercise) async throws -> FormProgressTracker {
        let formHistory = try await getFormHistory(user: user, exercise: exercise)
        
        let progressTracker = createFormProgressTracker(
            formHistory: formHistory,
            exercise: exercise
        )
        
        return progressTracker
    }
    
    func predictInjuryRisk(user: User, exercise: Exercise) async throws -> InjuryRiskPrediction {
        let formHistory = try await getFormHistory(user: user, exercise: exercise)
        let userProfile = try await buildUserProfile(user: user)
        
        let injuryRisk = try await analyzeInjuryRisk(
            user: user,
            exercise: exercise,
            formHistory: formHistory,
            userProfile: userProfile
        )
        
        return injuryRisk
    }
    
    // MARK: - Private Methods
    
    private func getFormHistory(user: User, exercise: Exercise) async throws -> [FormAnalysisResult] {
        let cacheKey = "form_history_\(user.id)_\(exercise.id)"
        
        // Check cache first
        if let cached = formHistoryCache[cacheKey] {
            return cached
        }
        
        // Fetch form analysis results from repository
        let workouts = try await workoutRepository.getWorkouts(for: user.id, limit: 50)
        let formResults: [FormAnalysisResult] = []
        
        // In a real implementation, this would fetch actual form analysis results
        // For now, we'll create sample data
        
        let sampleFormResults = createSampleFormResults(
            user: user,
            exercise: exercise,
            count: 10
        )
        
        // Cache the results
        formHistoryCache[cacheKey] = sampleFormResults
        
        return sampleFormResults
    }
    
    private func generateFormImprovementPrediction(
        user: User,
        exercise: Exercise,
        formHistory: [FormAnalysisResult],
        recentScores: [Double]
    ) async throws -> FormImprovementPrediction {
        
        // Analyze current form trends
        let currentTrend = analyzeFormTrend(scores: recentScores)
        let improvementRate = calculateImprovementRate(scores: recentScores)
        let consistency = calculateConsistency(scores: recentScores)
        
        // Use ML to predict future improvement
        let mlInput = FormAnalysisInput(
            imageData: Data(), // Placeholder
            exerciseType: exercise.type,
            userProfile: buildUserProfile(user: user),
            previousFormScores: recentScores
        )
        
        let mlOutput = try await mlModelManager.performInference(
            modelName: "FormAnalysisModel",
            input: .formAnalysis(mlInput)
        )
        
        // Extract ML predictions
        guard case .formAnalysis(let formAnalysis) = mlOutput else {
            throw FormImprovementError.invalidMLOutput
        }
        
        // Generate prediction
        let prediction = FormImprovementPrediction(
            exercise: exercise,
            currentFormScore: recentScores.last ?? 0.0,
            predictedFormScore: formAnalysis.formScore,
            improvementRate: improvementRate,
            consistency: consistency,
            trend: currentTrend,
            timeToTarget: calculateTimeToTarget(
                currentScore: recentScores.last ?? 0.0,
                targetScore: 0.9,
                improvementRate: improvementRate
            ),
            confidence: formAnalysis.confidence,
            recommendations: formAnalysis.recommendations,
            factors: analyzeImprovementFactors(
                formHistory: formHistory,
                user: user,
                exercise: exercise
            )
        )
        
        return prediction
    }
    
    private func analyzeFormTrendsFromHistory(
        formHistory: [FormAnalysisResult],
        exercise: Exercise
    ) -> FormTrendAnalysis {
        
        let scores = formHistory.map { $0.formScore }
        let dates = formHistory.map { $0.timestamp }
        
        let trend = analyzeFormTrend(scores: scores)
        let volatility = calculateVolatility(scores: scores)
        let seasonality = detectSeasonality(scores: scores, dates: dates)
        
        return FormTrendAnalysis(
            exercise: exercise,
            overallTrend: trend,
            volatility: volatility,
            seasonality: seasonality,
            improvementRate: calculateImprovementRate(scores: scores),
            consistency: calculateConsistency(scores: scores),
            peakPerformance: scores.max() ?? 0.0,
            averagePerformance: scores.reduce(0, +) / Double(scores.count),
            trendData: createTrendData(scores: scores, dates: dates)
        )
    }
    
    private func generatePersonalizedRecommendations(
        user: User,
        exercise: Exercise,
        formHistory: [FormAnalysisResult],
        recentForm: FormAnalysisResult?
    ) async throws -> [FormRecommendation] {
        
        var recommendations: [FormRecommendation] = []
        
        // Analyze common form issues
        if let recentForm = recentForm {
            let commonIssues = analyzeCommonFormIssues(form: recentForm)
            recommendations.append(contentsOf: commonIssues)
        }
        
        // Analyze progression patterns
        let progressionRecommendations = analyzeProgressionPatterns(
            formHistory: formHistory,
            user: user,
            exercise: exercise
        )
        recommendations.append(contentsOf: progressionRecommendations)
        
        // Generate ML-based recommendations
        let mlRecommendations = try await generateMLRecommendations(
            user: user,
            exercise: exercise,
            formHistory: formHistory
        )
        recommendations.append(contentsOf: mlRecommendations)
        
        // Sort by priority and relevance
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func createFormProgressTracker(
        formHistory: [FormAnalysisResult],
        exercise: Exercise
    ) -> FormProgressTracker {
        
        let scores = formHistory.map { $0.formScore }
        let dates = formHistory.map { $0.timestamp }
        
        let progress = FormProgressTracker(
            exercise: exercise,
            totalSessions: formHistory.count,
            currentStreak: calculateCurrentStreak(scores: scores, dates: dates),
            longestStreak: calculateLongestStreak(scores: scores, dates: dates),
            averageScore: scores.reduce(0, +) / Double(scores.count),
            bestScore: scores.max() ?? 0.0,
            improvementRate: calculateImprovementRate(scores: scores),
            consistency: calculateConsistency(scores: scores),
            milestones: generateFormMilestones(scores: scores),
            progressChart: createProgressChart(scores: scores, dates: dates)
        )
        
        return progress
    }
    
    private func analyzeInjuryRisk(
        user: User,
        exercise: Exercise,
        formHistory: [FormAnalysisResult],
        userProfile: UserProfile
    ) async throws -> InjuryRiskPrediction {
        
        // Analyze form consistency and patterns
        let formConsistency = calculateConsistency(scores: formHistory.map { $0.formScore })
        let formTrend = analyzeFormTrend(scores: formHistory.map { $0.formScore })
        
        // Use ML to predict injury risk
        let mlInput = InjuryRiskInput(
            workoutHistory: [], // Would fetch actual workout history
            healthMetrics: HealthMetrics(
                heartRate: 75.0,
                sleepHours: 7.5,
                stressLevel: 30.0,
                energyLevel: 80.0
            ),
            userProfile: userProfile,
            recoveryData: RecoveryData(
                recoveryTime: 24 * 3600,
                sleepQuality: 0.8,
                nutritionScore: 0.7
            )
        )
        
        let mlOutput = try await mlModelManager.performInference(
            modelName: "InjuryRiskModel",
            input: .injuryRisk(mlInput)
        )
        
        // Extract ML predictions
        guard case .injuryRisk(let injuryRisk) = mlOutput else {
            throw FormImprovementError.invalidMLOutput
        }
        
        // Combine ML and form analysis
        let combinedRisk = calculateCombinedInjuryRisk(
            mlRisk: injuryRisk,
            formConsistency: formConsistency,
            formTrend: formTrend
        )
        
        return InjuryRiskPrediction(
            exercise: exercise,
            riskLevel: combinedRisk,
            riskFactors: injuryRisk.riskFactors,
            preventionStrategies: injuryRisk.preventionStrategies,
            confidence: injuryRisk.confidence,
            formAnalysis: FormRiskAnalysis(
                consistency: formConsistency,
                trend: formTrend,
                recentIssues: analyzeRecentFormIssues(formHistory: formHistory)
            ),
            recommendations: generateInjuryPreventionRecommendations(
                riskLevel: combinedRisk,
                formAnalysis: FormRiskAnalysis(
                    consistency: formConsistency,
                    trend: formTrend,
                    recentIssues: analyzeRecentFormIssues(formHistory: formHistory)
                )
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func analyzeFormTrend(scores: [Double]) -> FormTrend {
        guard scores.count >= 2 else { return .stable }
        
        let recentScores = Array(scores.suffix(5))
        let olderScores = Array(scores.prefix(max(0, scores.count - 5)))
        
        let recentAverage = recentScores.reduce(0, +) / Double(recentScores.count)
        let olderAverage = olderScores.isEmpty ? recentAverage : olderScores.reduce(0, +) / Double(olderScores.count)
        
        let difference = recentAverage - olderAverage
        
        if difference > 0.05 { return .improving }
        else if difference < -0.05 { return .declining }
        else { return .stable }
    }
    
    private func calculateImprovementRate(scores: [Double]) -> Double {
        guard scores.count >= 2 else { return 0.0 }
        
        let firstScore = scores.first!
        let lastScore = scores.last!
        let timeSpan = Double(scores.count - 1)
        
        return (lastScore - firstScore) / timeSpan
    }
    
    private func calculateConsistency(scores: [Double]) -> Double {
        guard scores.count >= 2 else { return 1.0 }
        
        let mean = scores.reduce(0, +) / Double(scores.count)
        let variance = scores.map { pow($0 - mean, 2) }.reduce(0, +) / Double(scores.count)
        let standardDeviation = sqrt(variance)
        
        // Higher consistency means lower standard deviation
        return max(0, 1 - (standardDeviation / mean))
    }
    
    private func calculateVolatility(scores: [Double]) -> Double {
        guard scores.count >= 2 else { return 0.0 }
        
        let differences = zip(scores, scores.dropFirst()).map { abs($0 - $1) }
        return differences.reduce(0, +) / Double(differences.count)
    }
    
    private func detectSeasonality(scores: [Double], dates: [Date]) -> SeasonalityPattern {
        // Simple seasonality detection
        // In a real implementation, this would use more sophisticated algorithms
        
        guard scores.count >= 7 else { return .none }
        
        let weeklyPatterns = analyzeWeeklyPatterns(scores: scores, dates: dates)
        let monthlyPatterns = analyzeMonthlyPatterns(scores: scores, dates: dates)
        
        if weeklyPatterns.isSignificant { return .weekly }
        else if monthlyPatterns.isSignificant { return .monthly }
        else { return .none }
    }
    
    private func analyzeWeeklyPatterns(scores: [Double], dates: [Date]) -> PatternAnalysis {
        // Analyze if there are patterns within weeks
        // This is a simplified implementation
        return PatternAnalysis(isSignificant: false, confidence: 0.5)
    }
    
    private func analyzeMonthlyPatterns(scores: [Double], dates: [Date]) -> PatternAnalysis {
        // Analyze if there are patterns within months
        // This is a simplified implementation
        return PatternAnalysis(isSignificant: false, confidence: 0.4)
    }
    
    private func calculateTimeToTarget(
        currentScore: Double,
        targetScore: Double,
        improvementRate: Double
    ) -> TimeInterval {
        guard improvementRate > 0 else { return Double.infinity }
        
        let scoreDifference = targetScore - currentScore
        let sessionsNeeded = scoreDifference / improvementRate
        
        // Assume average of 3 sessions per week
        let weeksNeeded = sessionsNeeded / 3.0
        return weeksNeeded * 7 * 24 * 3600 // Convert to seconds
    }
    
    private func analyzeImprovementFactors(
        formHistory: [FormAnalysisResult],
        user: User,
        exercise: Exercise
    ) -> [ImprovementFactor] {
        
        var factors: [ImprovementFactor] = []
        
        // Analyze frequency
        let frequency = analyzeWorkoutFrequency(formHistory: formHistory)
        factors.append(ImprovementFactor(type: .frequency, value: frequency, impact: .high))
        
        // Analyze consistency
        let consistency = calculateConsistency(scores: formHistory.map { $0.formScore })
        factors.append(ImprovementFactor(type: .consistency, value: consistency, impact: .high))
        
        // Analyze recovery
        let recovery = analyzeRecoveryPatterns(formHistory: formHistory)
        factors.append(ImprovementFactor(type: .recovery, value: recovery, impact: .medium))
        
        return factors
    }
    
    private func analyzeWorkoutFrequency(formHistory: [FormAnalysisResult]) -> Double {
        guard formHistory.count >= 2 else { return 0.0 }
        
        let dates = formHistory.map { $0.timestamp }.sorted()
        let totalDays = Calendar.current.dateComponents([.day], from: dates.first!, to: dates.last!).day ?? 1
        
        return Double(formHistory.count) / Double(totalDays)
    }
    
    private func analyzeRecoveryPatterns(formHistory: [FormAnalysisResult]) -> Double {
        // Analyze recovery patterns between sessions
        // This is a simplified implementation
        return 0.7
    }
    
    private func createSampleFormResults(
        user: User,
        exercise: Exercise,
        count: Int
    ) -> [FormAnalysisResult] {
        
        return (0..<count).map { index in
            let baseScore = 0.6 + (Double(index) * 0.03) // Gradual improvement
            let randomVariation = Double.random(in: -0.05...0.05)
            let finalScore = min(max(baseScore + randomVariation, 0.0), 1.0)
            
            return FormAnalysisResult(
                id: UUID().uuidString,
                exerciseId: exercise.id,
                userId: user.id,
                timestamp: Date().addingTimeInterval(-Double(index * 24 * 3600)),
                formScore: finalScore,
                keyPoints: [],
                tips: [],
                confidence: 0.85 + Double.random(in: -0.1...0.1)
            )
        }
    }
    
    private func buildUserProfile(user: User) -> UserProfile {
        return UserProfile(
            fitnessLevel: user.profile.fitnessLevel,
            age: user.profile.age,
            weight: user.profile.weight,
            height: user.profile.height,
            goals: user.profile.goals
        )
    }
    
    private func analyzeCommonFormIssues(form: FormAnalysisResult) -> [FormRecommendation] {
        // Analyze common form issues and generate recommendations
        // This is a simplified implementation
        
        let recommendations: [FormRecommendation] = [
            FormRecommendation(
                id: UUID().uuidString,
                title: "Maintain Proper Posture",
                description: "Keep your back straight and core engaged throughout the movement",
                priority: .high,
                category: .posture,
                exerciseId: form.exerciseId
            ),
            FormRecommendation(
                id: UUID().uuidString,
                title: "Control the Movement",
                description: "Focus on slow, controlled movements rather than rushing through reps",
                priority: .medium,
                category: .technique,
                exerciseId: form.exerciseId
            )
        ]
        
        return recommendations
    }
    
    private func analyzeProgressionPatterns(
        formHistory: [FormAnalysisResult],
        user: User,
        exercise: Exercise
    ) -> [FormRecommendation] {
        
        // Analyze progression patterns and generate recommendations
        // This is a simplified implementation
        
        let recommendations: [FormRecommendation] = [
            FormRecommendation(
                id: UUID().uuidString,
                title: "Gradual Weight Increase",
                description: "Consider increasing weight by 5-10% once form is consistently good",
                priority: .medium,
                category: .progression,
                exerciseId: exercise.id
            )
        ]
        
        return recommendations
    }
    
    private func generateMLRecommendations(
        user: User,
        exercise: Exercise,
        formHistory: [FormAnalysisResult]
    ) async throws -> [FormRecommendation] {
        
        // Use ML to generate personalized recommendations
        // This is a placeholder implementation
        
        let recommendations: [FormRecommendation] = [
            FormRecommendation(
                id: UUID().uuidString,
                title: "ML-Generated Tip",
                description: "Based on your form patterns, focus on breathing rhythm",
                priority: .low,
                category: .technique,
                exerciseId: exercise.id
            )
        ]
        
        return recommendations
    }
    
    private func calculateCurrentStreak(scores: [Double], dates: [Date]) -> Int {
        guard !scores.isEmpty else { return 0 }
        
        var streak = 0
        let sortedData = zip(scores, dates).sorted { $0.1 > $1.1 }
        
        for (score, _) in sortedData {
            if score >= 0.7 { // Good form threshold
                streak += 1
            } else {
                break
            }
        }
        
        return streak
    }
    
    private func calculateLongestStreak(scores: [Double], dates: [Date]) -> Int {
        guard !scores.isEmpty else { return 0 }
        
        var maxStreak = 0
        var currentStreak = 0
        let sortedData = zip(scores, dates).sorted { $0.1 > $1.1 }
        
        for (score, _) in sortedData {
            if score >= 0.7 { // Good form threshold
                currentStreak += 1
                maxStreak = max(maxStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return maxStreak
    }
    
    private func generateFormMilestones(scores: [Double]) -> [FormMilestone] {
        var milestones: [FormMilestone] = []
        
        let thresholds = [0.7, 0.8, 0.85, 0.9, 0.95]
        
        for threshold in thresholds {
            if let firstAchievement = scores.firstIndex(where: { $0 >= threshold }) {
                milestones.append(FormMilestone(
                    id: UUID().uuidString,
                    title: "Form Score \(Int(threshold * 100))%",
                    description: "Achieved \(Int(threshold * 100))% form score",
                    threshold: threshold,
                    achievedAt: Date().addingTimeInterval(-Double(scores.count - firstAchievement - 1) * 24 * 3600),
                    type: .formScore
                ))
            }
        }
        
        return milestones
    }
    
    private func createProgressChart(scores: [Double], dates: [Date]) -> [ChartDataPoint] {
        let sortedData = zip(scores, dates).sorted { $0.1 < $1.1 }
        
        return sortedData.enumerated().map { index, data in
            ChartDataPoint(
                x: Double(index),
                y: data.0,
                label: formatDate(data.1)
            )
        }
    }
    
    private func createTrendData(scores: [Double], dates: [Date]) -> [TrendDataPoint] {
        let sortedData = zip(scores, dates).sorted { $0.1 < $1.1 }
        
        return sortedData.enumerated().map { index, data in
            TrendDataPoint(
                date: data.1,
                value: data.0,
                trend: index > 0 ? (data.0 > sortedData[index - 1].0 ? .up : .down) : .stable
            )
        }
    }
    
    private func analyzeRecentFormIssues(formHistory: [FormAnalysisResult]) -> [FormIssue] {
        // Analyze recent form issues
        // This is a simplified implementation
        
        let recentForms = Array(formHistory.prefix(5))
        let lowScores = recentForms.filter { $0.formScore < 0.7 }
        
        return lowScores.map { form in
            FormIssue(
                id: UUID().uuidString,
                description: "Form score below threshold",
                severity: .medium,
                timestamp: form.timestamp,
                formScore: form.formScore
            )
        }
    }
    
    private func calculateCombinedInjuryRisk(
        mlRisk: InjuryRiskOutput,
        formConsistency: Double,
        formTrend: FormTrend
    ) -> RiskLevel {
        
        // Combine ML risk with form analysis
        let mlRiskValue = riskLevelToValue(mlRisk.riskLevel)
        let formRiskValue = calculateFormRiskValue(consistency: formConsistency, trend: formTrend)
        
        let combinedRisk = (mlRiskValue + formRiskValue) / 2.0
        
        return valueToRiskLevel(combinedRisk)
    }
    
    private func riskLevelToValue(_ riskLevel: RiskLevel) -> Double {
        switch riskLevel {
        case .low: return 0.2
        case .moderate: return 0.5
        case .high: return 0.8
        }
    }
    
    private func calculateFormRiskValue(consistency: Double, trend: FormTrend) -> Double {
        let consistencyRisk = 1.0 - consistency
        let trendRisk: Double
        
        switch trend {
        case .improving: trendRisk = 0.2
        case .stable: trendRisk = 0.5
        case .declining: trendRisk = 0.8
        }
        
        return (consistencyRisk + trendRisk) / 2.0
    }
    
    private func valueToRiskLevel(_ value: Double) -> RiskLevel {
        if value < 0.3 { return .low }
        else if value < 0.7 { return .moderate }
        else { return .high }
    }
    
    private func generateInjuryPreventionRecommendations(
        riskLevel: RiskLevel,
        formAnalysis: FormRiskAnalysis
    ) -> [InjuryPreventionRecommendation] {
        
        var recommendations: [InjuryPreventionRecommendation] = []
        
        switch riskLevel {
        case .low:
            recommendations.append(InjuryPreventionRecommendation(
                id: UUID().uuidString,
                title: "Maintain Current Form",
                description: "Your form is good, keep up the excellent work!",
                priority: .low,
                category: .maintenance
            ))
            
        case .moderate:
            recommendations.append(InjuryPreventionRecommendation(
                id: UUID().uuidString,
                title: "Focus on Consistency",
                description: "Work on maintaining consistent form across all sets",
                priority: .medium,
                category: .improvement
            ))
            
        case .high:
            recommendations.append(InjuryPreventionRecommendation(
                id: UUID().uuidString,
                title: "Reduce Intensity",
                description: "Consider reducing weight or reps until form improves",
                priority: .high,
                category: .safety
            ))
            
            recommendations.append(InjuryPreventionRecommendation(
                id: UUID().uuidString,
                title: "Add Recovery Days",
                description: "Include more recovery days between sessions",
                priority: .high,
                category: .recovery
            ))
        }
        
        return recommendations
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct FormImprovementPrediction {
    let exercise: Exercise
    let currentFormScore: Double
    let predictedFormScore: Double
    let improvementRate: Double
    let consistency: Double
    let trend: FormTrend
    let timeToTarget: TimeInterval
    let confidence: Double
    let recommendations: [String]
    let factors: [ImprovementFactor]
}

struct FormTrendAnalysis {
    let exercise: Exercise
    let overallTrend: FormTrend
    let volatility: Double
    let seasonality: SeasonalityPattern
    let improvementRate: Double
    let consistency: Double
    let peakPerformance: Double
    let averagePerformance: Double
    let trendData: [TrendDataPoint]
}

struct FormRecommendation {
    let id: String
    let title: String
    let description: String
    let priority: RecommendationPriority
    let category: RecommendationCategory
    let exerciseId: String
}

struct FormProgressTracker {
    let exercise: Exercise
    let totalSessions: Int
    let currentStreak: Int
    let longestStreak: Int
    let averageScore: Double
    let bestScore: Double
    let improvementRate: Double
    let consistency: Double
    let milestones: [FormMilestone]
    let progressChart: [ChartDataPoint]
}

struct InjuryRiskPrediction {
    let exercise: Exercise
    let riskLevel: RiskLevel
    let riskFactors: [String]
    let preventionStrategies: [String]
    let confidence: Double
    let formAnalysis: FormRiskAnalysis
    let recommendations: [InjuryPreventionRecommendation]
}

struct FormRiskAnalysis {
    let consistency: Double
    let trend: FormTrend
    let recentIssues: [FormIssue]
}

struct FormIssue {
    let id: String
    let description: String
    let severity: IssueSeverity
    let timestamp: Date
    let formScore: Double
}

struct ImprovementFactor {
    let type: FactorType
    let value: Double
    let impact: FactorImpact
}

struct FormMilestone {
    let id: String
    let title: String
    let description: String
    let threshold: Double
    let achievedAt: Date
    let type: MilestoneType
}

struct ChartDataPoint {
    let x: Double
    let y: Double
    let label: String
}

struct TrendDataPoint {
    let date: Date
    let value: Double
    let trend: TrendDirection
}

struct PatternAnalysis {
    let isSignificant: Bool
    let confidence: Double
}

struct InjuryPreventionRecommendation {
    let id: String
    let title: String
    let description: String
    let priority: RecommendationPriority
    let category: PreventionCategory
}

enum FormTrend {
    case improving
    case stable
    case declining
}

enum SeasonalityPattern {
    case none
    case weekly
    case monthly
}

enum RecommendationPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
}

enum RecommendationCategory: String, CaseIterable {
    case posture = "Posture"
    case technique = "Technique"
    case progression = "Progression"
    case recovery = "Recovery"
}

enum FactorType: String, CaseIterable {
    case frequency = "Frequency"
    case consistency = "Consistency"
    case recovery = "Recovery"
    case technique = "Technique"
}

enum FactorImpact: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum IssueSeverity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum MilestoneType: String, CaseIterable {
    case formScore = "Form Score"
    case consistency = "Consistency"
    case streak = "Streak"
}

enum PreventionCategory: String, CaseIterable {
    case safety = "Safety"
    case improvement = "Improvement"
    case maintenance = "Maintenance"
    case recovery = "Recovery"
}

enum FormImprovementError: Error, LocalizedError {
    case invalidMLOutput
    case insufficientData
    case predictionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidMLOutput:
            return "Invalid ML model output"
        case .insufficientData:
            return "Insufficient data for prediction"
        case .predictionFailed(let reason):
            return "Form improvement prediction failed: \(reason)"
        }
    }
}

import Foundation
import Combine
import OpenAI

// MARK: - AI Coach Service Protocol
protocol AICoachServiceProtocol: ObservableObject {
    var currentConversation: AIConversation { get }
    var isProcessing: Bool { get }
    var lastResponse: AIResponse? { get }
    
    func startConversation(with user: User) async throws
    func sendMessage(_ message: String, context: AIContext) async throws -> AIResponse
    func generateWorkout(context: WorkoutRequestContext) async throws -> GeneratedWorkout
    func analyzeForm(imageData: Data, exercise: Exercise) async throws -> FormAnalysisResult
    func provideNutritionalGuidance(context: NutritionContext) async throws -> NutritionGuidance
    func analyzeHealthData(metrics: HealthMetrics) async throws -> HealthAnalysis
    func provideMotivationalSupport(context: MotivationContext) async throws -> MotivationalResponse
    func getPersonalizedRecommendations(for user: User) async throws -> [Recommendation]
    func updateUserPreferences(_ preferences: UserPreferences) async throws
    func trackInteraction(_ interaction: AIInteraction) async throws
}

// MARK: - AI Coach Service
final class AICoachService: NSObject, AICoachServiceProtocol {
    @Published var currentConversation: AIConversation = AIConversation()
    @Published var isProcessing: Bool = false
    @Published var lastResponse: AIResponse?
    
    private let openAIService: OpenAIServiceProtocol
    private let geminiService: GeminiServiceProtocol
    private let userRepository: UserRepositoryProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let healthKitManager: HealthKitManagerProtocol
    private let progressAnalyticsService: ProgressAnalyticsServiceProtocol
    private let gamificationService: GamificationServiceProtocol
    
    private var conversationHistory: [AIMessage] = []
    private var userContext: UserContext?
    private var systemPrompt: String
    
    init(
        openAIService: OpenAIServiceProtocol,
        geminiService: GeminiServiceProtocol,
        userRepository: UserRepositoryProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        healthKitManager: HealthKitManagerProtocol,
        progressAnalyticsService: ProgressAnalyticsServiceProtocol,
        gamificationService: GamificationServiceProtocol
    ) {
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        self.healthKitManager = healthKitManager
        self.progressAnalyticsService = progressAnalyticsService
        self.gamificationService = gamificationService
        
        // Load the comprehensive AI Coach system prompt
        self.systemPrompt = Self.loadSystemPrompt()
        
        super.init()
    }
    
    // MARK: - Public Methods
    
    func startConversation(with user: User) async throws {
        let context = try await buildUserContext(for: user)
        self.userContext = context
        
        let welcomeMessage = AIMessage(
            role: .assistant,
            content: generateWelcomeMessage(for: user, context: context),
            timestamp: Date(),
            context: .welcome
        )
        
        conversationHistory = [welcomeMessage]
        currentConversation = AIConversation(
            id: UUID().uuidString,
            userId: user.id,
            startDate: Date(),
            messages: [welcomeMessage]
        )
        
        lastResponse = AIResponse(
            message: welcomeMessage.content,
            type: .welcome,
            recommendations: [],
            nextActions: []
        )
    }
    
    func sendMessage(_ message: String, context: AIContext) async throws -> AIResponse {
        isProcessing = true
        defer { isProcessing = false }
        
        let userMessage = AIMessage(
            role: .user,
            content: message,
            timestamp: Date(),
            context: context
        )
        
        conversationHistory.append(userMessage)
        
        // Analyze message intent and context
        let intent = analyzeMessageIntent(message)
        let responseContext = try await buildResponseContext(intent: intent, userMessage: message)
        
        // Generate AI response based on intent
        let aiResponse = try await generateAIResponse(
            for: message,
            intent: intent,
            context: responseContext
        )
        
        let assistantMessage = AIMessage(
            role: .assistant,
            content: aiResponse.message,
            timestamp: Date(),
            context: context
        )
        
        conversationHistory.append(assistantMessage)
        currentConversation.messages.append(contentsOf: [userMessage, assistantMessage])
        
        // Track interaction for learning
        let interaction = AIInteraction(
            userId: userContext?.userId ?? "",
            messageType: intent,
            responseType: aiResponse.type,
            timestamp: Date(),
            satisfaction: nil
        )
        
        try await trackInteraction(interaction)
        
        lastResponse = aiResponse
        return aiResponse
    }
    
    func generateWorkout(context: WorkoutRequestContext) async throws -> GeneratedWorkout {
        let workoutPrompt = buildWorkoutGenerationPrompt(context: context)
        
        let response = try await openAIService.generateText(
            prompt: workoutPrompt,
            maxTokens: 2000,
            temperature: 0.7
        )
        
        return try parseWorkoutResponse(response)
    }
    
    func analyzeForm(imageData: Data, exercise: Exercise) async throws -> FormAnalysisResult {
        // Use Gemini Vision for form analysis
        let visionPrompt = buildFormAnalysisPrompt(exercise: exercise)
        
        let response = try await geminiService.analyzeImage(
            imageData: imageData,
            prompt: visionPrompt
        )
        
        return try parseFormAnalysisResponse(response, exercise: exercise)
    }
    
    func provideNutritionalGuidance(context: NutritionContext) async throws -> NutritionGuidance {
        let nutritionPrompt = buildNutritionPrompt(context: context)
        
        let response = try await openAIService.generateText(
            prompt: nutritionPrompt,
            maxTokens: 1500,
            temperature: 0.6
        )
        
        return try parseNutritionResponse(response)
    }
    
    func analyzeHealthData(metrics: HealthMetrics) async throws -> HealthAnalysis {
        let healthPrompt = buildHealthAnalysisPrompt(metrics: metrics)
        
        let response = try await openAIService.generateText(
            prompt: healthPrompt,
            maxTokens: 1800,
            temperature: 0.5
        )
        
        return try parseHealthAnalysisResponse(response)
    }
    
    func provideMotivationalSupport(context: MotivationContext) async throws -> MotivationalResponse {
        let motivationPrompt = buildMotivationPrompt(context: context)
        
        let response = try await openAIService.generateText(
            prompt: motivationPrompt,
            maxTokens: 1200,
            temperature: 0.8
        )
        
        return try parseMotivationResponse(response)
    }
    
    func getPersonalizedRecommendations(for user: User) async throws -> [Recommendation] {
        let context = try await buildUserContext(for: user)
        let recommendations = try await generateRecommendations(context: context)
        return recommendations
    }
    
    func updateUserPreferences(_ preferences: UserPreferences) async throws {
        // Update user preferences in the repository
        try await userRepository.updatePreferences(preferences)
        
        // Update local context
        if let userContext = userContext {
            self.userContext = UserContext(
                userId: userContext.userId,
                profile: userContext.profile,
                preferences: preferences,
                recentActivity: userContext.recentActivity,
                healthMetrics: userContext.healthMetrics,
                achievements: userContext.achievements
            )
        }
    }
    
    func trackInteraction(_ interaction: AIInteraction) async throws {
        // Store interaction for learning and analytics
        // This would typically go to a database or analytics service
        print("📊 AI Interaction tracked: \(interaction.messageType) -> \(interaction.responseType)")
    }
    
    // MARK: - Private Methods
    
    private static func loadSystemPrompt() -> String {
        // Load the comprehensive AI Coach system prompt from the file
        guard let path = Bundle.main.path(forResource: "AICoachSystemPrompt", ofType: "txt"),
              let prompt = try? String(contentsOfFile: path, encoding: .utf8) else {
            return defaultSystemPrompt
        }
        return prompt
    }
    
    private func buildUserContext(for user: User) async throws -> UserContext {
        let recentWorkouts = try await workoutRepository.getRecentWorkouts(for: user.id, limit: 10)
        let healthMetrics = try await healthKitManager.fetchTodayStats()
        let progress = try await progressAnalyticsService.getProgressOverview(for: user.id)
        let achievements = try await gamificationService.getUserAchievements(userId: user.id)
        
        return UserContext(
            userId: user.id,
            profile: user.profile,
            preferences: user.preferences,
            recentActivity: recentWorkouts,
            healthMetrics: healthMetrics,
            achievements: achievements
        )
    }
    
    private func generateWelcomeMessage(for user: User, context: UserContext) -> String {
        let name = user.profile.firstName.isEmpty ? "there" : user.profile.firstName
        let streak = context.achievements.first { $0.type == .streak }?.value ?? 0
        
        if streak > 0 {
            return "🔥 Welcome back, \(name)! You're on a \(streak)-day streak - that's incredible! How can I help you crush your fitness goals today?"
        } else {
            return "💪 Hey \(name)! Ready to start your fitness journey? I'm here to guide you every step of the way. What would you like to work on today?"
        }
    }
    
    private func analyzeMessageIntent(_ message: String) -> MessageIntent {
        let lowercased = message.lowercased()
        
        if lowercased.contains("workout") || lowercased.contains("exercise") || lowercased.contains("train") {
            return .workoutRequest
        } else if lowercased.contains("form") || lowercased.contains("technique") || lowercased.contains("correct") {
            return .formAnalysis
        } else if lowercased.contains("nutrition") || lowercased.contains("diet") || lowercased.contains("food") {
            return .nutritionGuidance
        } else if lowercased.contains("pain") || lowercased.contains("hurt") || lowercased.contains("injury") {
            return .healthConcern
        } else if lowercased.contains("motivation") || lowercased.contains("tired") || lowercased.contains("can't") {
            return .motivationalSupport
        } else if lowercased.contains("progress") || lowercased.contains("stats") || lowercased.contains("analytics") {
            return .progressAnalysis
        } else {
            return .generalInquiry
        }
    }
    
    private func buildResponseContext(intent: MessageIntent, userMessage: String) async throws -> AIResponseContext {
        guard let userContext = userContext else {
            throw AICoachError.userContextNotAvailable
        }
        
        return AIResponseContext(
            intent: intent,
            userMessage: userMessage,
            userContext: userContext,
            conversationHistory: conversationHistory,
            systemPrompt: systemPrompt
        )
    }
    
    private func generateAIResponse(
        for message: String,
        intent: MessageIntent,
        context: AIResponseContext
    ) async throws -> AIResponse {
        let prompt = buildResponsePrompt(message: message, intent: intent, context: context)
        
        let response = try await openAIService.generateText(
            prompt: prompt,
            maxTokens: 1500,
            temperature: 0.7
        )
        
        return try parseAIResponse(response, intent: intent)
    }
    
    private func buildResponsePrompt(
        message: String,
        intent: MessageIntent,
        context: AIResponseContext
    ) -> String {
        var prompt = context.systemPrompt + "\n\n"
        prompt += "Current User Context:\n"
        prompt += "- Name: \(context.userContext.profile.firstName) \(context.userContext.profile.lastName)\n"
        prompt += "- Fitness Level: \(context.userContext.profile.fitnessLevel.rawValue)\n"
        prompt += "- Goals: \(context.userContext.profile.goals.map { $0.rawValue }.joined(separator: ", "))\n"
        prompt += "- Recent Activity: \(context.userContext.recentActivity.count) workouts in last 10 days\n"
        
        if let lastWorkout = context.userContext.recentActivity.first {
            prompt += "- Last Workout: \(lastWorkout.type.rawValue) on \(lastWorkout.date)\n"
        }
        
        prompt += "\nUser Message: \(message)\n"
        prompt += "Intent: \(intent.rawValue)\n\n"
        prompt += "Please respond as Trainerly AI following the guidelines above. Be encouraging, professional, and provide actionable advice."
        
        return prompt
    }
    
    private func buildWorkoutGenerationPrompt(context: WorkoutRequestContext) -> String {
        var prompt = "Generate a personalized workout plan for the following context:\n\n"
        prompt += "User Profile:\n"
        prompt += "- Fitness Level: \(context.userProfile.fitnessLevel.rawValue)\n"
        prompt += "- Goals: \(context.userProfile.goals.map { $0.rawValue }.joined(separator: ", "))\n"
        prompt += "- Available Equipment: \(context.availableEquipment.map { $0.rawValue }.joined(separator: ", "))\n"
        prompt += "- Location: \(context.location.rawValue)\n"
        prompt += "- Duration: \(context.duration) minutes\n"
        prompt += "- Focus Areas: \(context.focusAreas.map { $0.rawValue }.joined(separator: ", "))\n\n"
        
        prompt += "Recent Activity:\n"
        prompt += "- Last Workout: \(context.lastWorkout?.type.rawValue ?? "None")\n"
        prompt += "- Recovery Status: \(context.recoveryStatus.rawValue)\n"
        prompt += "- Energy Level: \(context.energyLevel.rawValue)\n\n"
        
        prompt += "Please generate a structured workout with:\n"
        prompt += "1. Warm-up (5-10 minutes)\n"
        prompt += "2. Main workout with exercises, sets, reps, and rest periods\n"
        prompt += "3. Cool-down (5-10 minutes)\n"
        prompt += "4. Form cues for each exercise\n"
        prompt += "5. Modifications if needed\n"
        prompt += "6. Estimated calories and difficulty\n\n"
        
        prompt += "Format the response as JSON matching the GeneratedWorkout structure."
        
        return prompt
    }
    
    private func buildFormAnalysisPrompt(exercise: Exercise) -> String {
        var prompt = "Analyze the exercise form for \(exercise.name) based on the provided image.\n\n"
        prompt += "Exercise Details:\n"
        prompt += "- Type: \(exercise.type.rawValue)\n"
        prompt += "- Muscle Groups: \(exercise.muscleGroups.map { $0.rawValue }.joined(separator: ", "))\n"
        prompt += "- Difficulty: \(exercise.difficulty.rawValue)\n\n"
        
        prompt += "Please analyze:\n"
        prompt += "1. Overall form quality (1-10 scale)\n"
        prompt += "2. Key points that are correct\n"
        prompt += "3. Areas that need improvement\n"
        prompt += "4. Specific form tips and corrections\n"
        prompt += "5. Safety concerns if any\n"
        prompt += "6. Alternative exercises if form issues persist\n\n"
        
        prompt += "Be encouraging and constructive. Focus on actionable improvements."
        
        return prompt
    }
    
    private func buildNutritionPrompt(context: NutritionContext) -> String {
        var prompt = "Provide nutritional guidance for the following context:\n\n"
        prompt += "User Profile:\n"
        prompt += "- Age: \(context.userProfile.age)\n"
        prompt += "- Weight: \(context.userProfile.weight) kg\n"
        prompt += "- Height: \(context.userProfile.height) cm\n"
        prompt += "- Activity Level: \(context.userProfile.activityLevel.rawValue)\n"
        prompt += "- Goals: \(context.userProfile.goals.map { $0.rawValue }.joined(separator: ", "))\n\n"
        
        prompt += "Current Context:\n"
        prompt += "- Meal Timing: \(context.mealTiming.rawValue)\n"
        prompt += "- Workout Intensity: \(context.workoutIntensity.rawValue)\n"
        prompt += "- Dietary Restrictions: \(context.dietaryRestrictions.map { $0.rawValue }.joined(separator: ", "))\n\n"
        
        prompt += "Please provide:\n"
        prompt += "1. Macro recommendations\n"
        prompt += "2. Meal suggestions\n"
        prompt += "3. Timing advice\n"
        prompt += "4. Hydration tips\n"
        prompt += "5. Supplements if relevant\n\n"
        
        prompt += "Format as JSON matching NutritionGuidance structure."
        
        return prompt
    }
    
    private func buildHealthAnalysisPrompt(metrics: HealthMetrics) -> String {
        var prompt = "Analyze the following health metrics and provide insights:\n\n"
        prompt += "Health Data:\n"
        prompt += "- Heart Rate: \(metrics.heartRate) BPM\n"
        prompt += "- HRV: \(metrics.hrv) ms\n"
        prompt += "- Sleep: \(metrics.sleepHours) hours\n"
        prompt += "- Steps: \(metrics.steps)\n"
        prompt += "- Calories: \(metrics.calories) kcal\n"
        prompt += "- Active Minutes: \(metrics.activeMinutes)\n\n"
        
        prompt += "Please analyze:\n"
        prompt += "1. Overall health status\n"
        prompt += "2. Recovery status\n"
        prompt += "3. Potential concerns\n"
        prompt += "4. Recommendations for improvement\n"
        prompt += "5. Workout adjustments if needed\n\n"
        
        prompt += "Format as JSON matching HealthAnalysis structure."
        
        return prompt
    }
    
    private func buildMotivationPrompt(context: MotivationContext) -> String {
        var prompt = "Provide motivational support for the following context:\n\n"
        prompt += "User Situation:\n"
        prompt += "- Current Mood: \(context.currentMood.rawValue)\n"
        prompt += "- Motivation Level: \(context.motivationLevel.rawValue)\n"
        prompt += "- Recent Challenges: \(context.recentChallenges)\n"
        prompt += "- Goals: \(context.userProfile.goals.map { $0.rawValue }.joined(separator: ", "))\n\n"
        
        prompt += "Please provide:\n"
        prompt += "1. Empathetic acknowledgment\n"
        prompt += "2. Motivational message\n"
        prompt += "3. Practical strategies\n"
        prompt += "4. Goal reminder\n"
        prompt += "5. Encouragement for next steps\n\n"
        
        prompt += "Be encouraging, understanding, and provide actionable advice."
        
        return prompt
    }
    
    private func generateRecommendations(context: UserContext) async throws -> [Recommendation] {
        var recommendations: [Recommendation] = []
        
        // Analyze recent activity patterns
        if context.recentActivity.isEmpty {
            recommendations.append(Recommendation(
                type: .startWorkout,
                title: "Start Your First Workout",
                description: "Begin your fitness journey with a beginner-friendly workout",
                priority: .high,
                action: "Generate Workout"
            ))
        }
        
        // Check for consistency
        let workoutDays = context.recentActivity.count
        if workoutDays < 3 {
            recommendations.append(Recommendation(
                type: .increaseFrequency,
                title: "Build Consistency",
                description: "Aim for 3-4 workouts per week for best results",
                priority: .medium,
                action: "Schedule Workouts"
            ))
        }
        
        // Check recovery
        if let lastWorkout = context.recentActivity.first,
           Date().timeIntervalSince(lastWorkout.date) < 24 * 3600 {
            recommendations.append(Recommendation(
                type: .recovery,
                title: "Focus on Recovery",
                description: "Consider a rest day or light activity today",
                priority: .medium,
                action: "Recovery Tips"
            ))
        }
        
        // Check progress
        if let progress = try? await progressAnalyticsService.getProgressOverview(for: context.userId),
           progress.weeksSinceStart > 4 {
            recommendations.append(Recommendation(
                type: .progressReview,
                title: "Review Your Progress",
                description: "Check your 4-week progress and adjust goals",
                priority: .low,
                action: "View Progress"
            ))
        }
        
        return recommendations
    }
    
    // MARK: - Response Parsing
    
    private func parseAIResponse(_ response: String, intent: MessageIntent) throws -> AIResponse {
        // For now, return a simple parsed response
        // In production, this would parse structured JSON responses
        return AIResponse(
            message: response,
            type: .general,
            recommendations: [],
            nextActions: []
        )
    }
    
    private func parseWorkoutResponse(_ response: String) throws -> GeneratedWorkout {
        // Parse the AI-generated workout response
        // This would typically parse JSON and validate the structure
        // For now, return a placeholder
        return GeneratedWorkout(
            id: UUID().uuidString,
            name: "AI Generated Workout",
            exercises: [],
            duration: 45,
            difficulty: .intermediate,
            calories: 300,
            focusAreas: [.strength, .cardio]
        )
    }
    
    private func parseFormAnalysisResponse(_ response: String, exercise: Exercise) throws -> FormAnalysisResult {
        // Parse the form analysis response
        return FormAnalysisResult(
            score: 8.5,
            keyPoints: [],
            formTips: [],
            safetyConcerns: [],
            alternatives: []
        )
    }
    
    private func parseNutritionResponse(_ response: String) throws -> NutritionGuidance {
        // Parse the nutrition guidance response
        return NutritionGuidance(
            macros: MacroRecommendation(protein: 150, carbs: 200, fats: 65),
            mealSuggestions: [],
            timing: "",
            hydration: "",
            supplements: []
        )
    }
    
    private func parseHealthAnalysisResponse(_ response: String) throws -> HealthAnalysis {
        // Parse the health analysis response
        return HealthAnalysis(
            status: .good,
            recoveryStatus: .ready,
            concerns: [],
            recommendations: [],
            workoutAdjustments: []
        )
    }
    
    private func parseMotivationResponse(_ response: String) throws -> MotivationalResponse {
        // Parse the motivational response
        return MotivationalResponse(
            message: response,
            strategies: [],
            nextSteps: [],
            encouragement: ""
        )
    }
}

// MARK: - Supporting Types

struct AIConversation: Identifiable, Codable {
    let id: String
    let userId: String
    let startDate: Date
    var messages: [AIMessage]
}

struct AIMessage: Identifiable, Codable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    let context: AIContext
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

enum AIContext: String, Codable {
    case welcome
    case workoutRequest
    case formAnalysis
    case nutritionGuidance
    case healthConcern
    case motivationalSupport
    case progressAnalysis
    case generalInquiry
}

enum MessageIntent: String, Codable {
    case workoutRequest
    case formAnalysis
    case nutritionGuidance
    case healthConcern
    case motivationalSupport
    case progressAnalysis
    case generalInquiry
}

struct AIResponse: Codable {
    let message: String
    let type: ResponseType
    let recommendations: [Recommendation]
    let nextActions: [String]
}

enum ResponseType: String, Codable {
    case welcome
    case workout
    case form
    case nutrition
    case health
    case motivation
    case progress
    case general
}

struct AIResponseContext {
    let intent: MessageIntent
    let userMessage: String
    let userContext: UserContext
    let conversationHistory: [AIMessage]
    let systemPrompt: String
}

struct UserContext {
    let userId: String
    let profile: UserProfile
    let preferences: UserPreferences
    let recentActivity: [Workout]
    let healthMetrics: HealthStats
    let achievements: [Achievement]
}

struct WorkoutRequestContext {
    let userProfile: UserProfile
    let availableEquipment: [Equipment]
    let location: Location
    let duration: Int
    let focusAreas: [MuscleGroup]
    let lastWorkout: Workout?
    let recoveryStatus: RecoveryStatus
    let energyLevel: EnergyLevel
}

struct NutritionContext {
    let userProfile: UserProfile
    let mealTiming: MealTiming
    let workoutIntensity: WorkoutIntensity
    let dietaryRestrictions: [DietaryRestriction]
}

struct MotivationContext {
    let userProfile: UserProfile
    let currentMood: Mood
    let motivationLevel: MotivationLevel
    let recentChallenges: String
}

struct AIInteraction: Codable {
    let userId: String
    let messageType: MessageIntent
    let responseType: ResponseType
    let timestamp: Date
    let satisfaction: Int?
}

struct Recommendation: Identifiable, Codable {
    let id = UUID()
    let type: RecommendationType
    let title: String
    let description: String
    let priority: Priority
    let action: String
}

enum RecommendationType: String, Codable {
    case startWorkout
    case increaseFrequency
    case recovery
    case progressReview
    case formImprovement
    case nutritionAdjustment
}

enum Priority: String, Codable {
    case low
    case medium
    case high
}

enum Mood: String, Codable {
    case energetic
    case tired
    case stressed
    case motivated
    case discouraged
    case confident
}

enum MotivationLevel: String, Codable {
    case veryLow
    case low
    case medium
    case high
    case veryHigh
}

enum MealTiming: String, Codable {
    case preWorkout
    case postWorkout
    case general
    case specific
}

enum WorkoutIntensity: String, Codable {
    case light
    case moderate
    case intense
    case veryIntense
}

enum RecoveryStatus: String, Codable {
    case ready
    case needsRecovery
    case overtraining
}

enum EnergyLevel: String, Codable {
    case veryLow
    case low
    case medium
    case high
    case veryHigh
}

enum DietaryRestriction: String, Codable {
    case vegetarian
    case vegan
    case glutenFree
    case dairyFree
    case keto
    case paleo
}

// MARK: - Error Types

enum AICoachError: LocalizedError {
    case userContextNotAvailable
    case invalidResponse
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .userContextNotAvailable:
            return "User context is not available"
        case .invalidResponse:
            return "Invalid AI response received"
        case .processingFailed:
            return "Failed to process AI request"
        }
    }
}

// MARK: - Default System Prompt

private let defaultSystemPrompt = """
You are Trainerly AI, an advanced fitness and wellness coach. Provide personalized fitness guidance based on user data, workout history, and individual goals. Be encouraging, professional, and provide actionable advice.
"""

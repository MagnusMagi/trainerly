import Foundation
import Combine

// MARK: - AI Workout Generator Protocol
protocol AIWorkoutGeneratorProtocol {
    func generateWorkout(for user: User, preferences: WorkoutPreferences) async throws -> GeneratedWorkout
    func generateExerciseVariations(for exercise: Exercise, difficulty: Difficulty) async throws -> [ExerciseVariation]
    func analyzeWorkoutPerformance(_ workout: Workout) async throws -> WorkoutAnalysis
    func suggestNextWorkout(based on: WorkoutHistory) async throws -> WorkoutSuggestion
}

// MARK: - AI Workout Generator
final class AIWorkoutGenerator: AIWorkoutGeneratorProtocol {
    
    // MARK: - Properties
    private let openAIService: OpenAIServiceProtocol
    private let exerciseLibrary: ExerciseLibraryProtocol
    private let userRepository: UserRepositoryProtocol
    
    // MARK: - Initialization
    init(
        openAIService: OpenAIServiceProtocol,
        exerciseLibrary: ExerciseLibraryProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.openAIService = openAIService
        self.exerciseLibrary = exerciseLibrary
        self.userRepository = userRepository
    }
    
    // MARK: - Public Methods
    func generateWorkout(for user: User, preferences: WorkoutPreferences) async throws -> GeneratedWorkout {
        // Build context for AI
        let context = buildWorkoutContext(for: user, preferences: preferences)
        
        // Generate workout plan using AI
        let aiResponse = try await generateWorkoutPlan(context: context)
        
        // Parse AI response and create workout
        let workout = try parseAIWorkoutResponse(aiResponse, for: user, preferences: preferences)
        
        return workout
    }
    
    func generateExerciseVariations(for exercise: Exercise, difficulty: Difficulty) async throws -> [ExerciseVariation] {
        let context = buildVariationContext(for: exercise, difficulty: difficulty)
        
        let aiResponse = try await openAIService.generateVariations(context: context)
        
        return try parseExerciseVariations(aiResponse, for: exercise)
    }
    
    func analyzeWorkoutPerformance(_ workout: Workout) async throws -> WorkoutAnalysis {
        let context = buildPerformanceContext(for: workout)
        
        let aiResponse = try await openAIService.analyzePerformance(context: context)
        
        return try parsePerformanceAnalysis(aiResponse, for: workout)
    }
    
    func suggestNextWorkout(based on history: WorkoutHistory) async throws -> WorkoutSuggestion {
        let context = buildSuggestionContext(for: history)
        
        let aiResponse = try await openAIService.suggestWorkout(context: context)
        
        return try parseWorkoutSuggestion(aiResponse, based: on history)
    }
    
    // MARK: - Private Methods
    private func buildWorkoutContext(for user: User, preferences: WorkoutPreferences) -> [String: Any] {
        var context: [String: Any] = [
            "user_profile": [
                "fitness_level": user.fitnessLevel ?? "beginner",
                "goals": user.goals ?? [],
                "restrictions": user.restrictions ?? [],
                "age": calculateAge(from: user.dateOfBirth),
                "gender": user.gender ?? "not_specified"
            ],
            "workout_preferences": [
                "type": preferences.type.rawValue,
                "duration": preferences.duration,
                "intensity": preferences.intensity.rawValue,
                "focus_areas": preferences.focusAreas.map { $0.rawValue },
                "equipment_available": preferences.availableEquipment.map { $0.rawValue },
                "location": preferences.location.rawValue
            ],
            "recent_workouts": preferences.recentWorkoutTypes,
            "target_calories": preferences.targetCalories,
            "rest_days": preferences.restDays
        ]
        
        // Add fitness metrics if available
        if let height = user.height, let weight = user.weight {
            context["fitness_metrics"] = [
                "height_cm": height,
                "weight_kg": weight,
                "bmi": calculateBMI(height: height, weight: weight)
            ]
        }
        
        return context
    }
    
    private func generateWorkoutPlan(context: [String: Any]) async throws -> String {
        let prompt = buildWorkoutPrompt(context: context)
        
        let response = try await openAIService.generateWorkout(prompt: prompt)
        
        return response
    }
    
    private func buildWorkoutPrompt(context: [String: Any]) -> String {
        """
        You are an expert fitness trainer creating personalized workouts. Generate a detailed workout plan based on the following context:
        
        User Profile: \(context["user_profile"] ?? [:])
        Workout Preferences: \(context["workout_preferences"] ?? [:])
        Recent Workouts: \(context["recent_workouts"] ?? [])
        Target Calories: \(context["target_calories"] ?? 300)
        Rest Days: \(context["rest_days"] ?? [])
        
        Create a workout that includes:
        1. Warm-up exercises (5-10 minutes)
        2. Main workout with specific exercises, sets, reps, and rest times
        3. Cool-down exercises (5-10 minutes)
        4. Estimated duration and calories
        5. Modifications for different fitness levels
        
        Format the response as JSON with this structure:
        {
            "name": "Workout Name",
            "type": "workout_type",
            "duration": "estimated_minutes",
            "calories": "estimated_calories",
            "difficulty": "beginner/intermediate/advanced",
            "warmup": [{"name": "exercise_name", "duration": "seconds", "instructions": "..."}],
            "main_workout": [{"name": "exercise_name", "sets": number, "reps": number, "weight": "kg/lbs", "rest": "seconds", "instructions": "..."}],
            "cooldown": [{"name": "exercise_name", "duration": "seconds", "instructions": "..."}],
            "tips": ["tip1", "tip2", "tip3"],
            "modifications": {"beginner": "...", "advanced": "..."}
        }
        """
    }
    
    private func parseAIWorkoutResponse(_ response: String, for user: User, preferences: WorkoutPreferences) throws -> GeneratedWorkout {
        // Extract JSON from AI response
        let jsonString = extractJSONFromResponse(response)
        
        guard let data = jsonString.data(using: .utf8) else {
            throw AIWorkoutError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let aiWorkout = try decoder.decode(AIWorkoutResponse.self, from: data)
        
        // Convert to GeneratedWorkout
        return try convertToGeneratedWorkout(aiWorkout, for: user, preferences: preferences)
    }
    
    private func extractJSONFromResponse(_ response: String) -> String {
        // Find JSON content in the response
        if let startIndex = response.firstIndex(of: "{"),
           let endIndex = response.lastIndex(of: "}") {
            let start = response.index(startIndex, offsetBy: 0)
            let end = response.index(endIndex, offsetBy: 1)
            return String(response[start..<end])
        }
        return response
    }
    
    private func convertToGeneratedWorkout(_ aiWorkout: AIWorkoutResponse, for user: User, preferences: WorkoutPreferences) throws -> GeneratedWorkout {
        let warmup = try convertToExercises(aiWorkout.warmup, type: .warmup)
        let mainWorkout = try convertToExercises(aiWorkout.mainWorkout, type: .main)
        let cooldown = try convertToExercises(aiWorkout.cooldown, type: .cooldown)
        
        return GeneratedWorkout(
            name: aiWorkout.name,
            type: WorkoutType(rawValue: aiWorkout.type) ?? .strength,
            duration: TimeInterval(aiWorkout.duration * 60), // Convert minutes to seconds
            estimatedCalories: aiWorkout.calories,
            difficulty: Difficulty(rawValue: aiWorkout.difficulty) ?? .beginner,
            warmup: warmup,
            mainWorkout: mainWorkout,
            cooldown: cooldown,
            tips: aiWorkout.tips,
            modifications: aiWorkout.modifications,
            user: user,
            preferences: preferences,
            createdAt: Date()
        )
    }
    
    private func convertToExercises(_ aiExercises: [AIExercise], type: ExerciseType) throws -> [GeneratedExercise] {
        return try aiExercises.map { aiExercise in
            let exercise = try findOrCreateExercise(name: aiExercise.name)
            
            return GeneratedExercise(
                exercise: exercise,
                type: type,
                sets: aiExercise.sets ?? 1,
                reps: aiExercise.reps ?? 10,
                weight: aiExercise.weight,
                duration: TimeInterval(aiExercise.duration ?? 0),
                restTime: TimeInterval(aiExercise.rest ?? 0),
                instructions: aiExercise.instructions,
                order: 0 // Will be set by caller
            )
        }
    }
    
    private func findOrCreateExercise(name: String) throws -> Exercise {
        // Try to find existing exercise
        if let existing = try exerciseLibrary.findExercise(by: name) {
            return existing
        }
        
        // Create new exercise if not found
        let newExercise = Exercise()
        newExercise.id = UUID().uuidString
        newExercise.name = name
        newExercise.createdAt = Date()
        newExercise.updatedAt = Date()
        
        try exerciseLibrary.saveExercise(newExercise)
        
        return newExercise
    }
    
    // MARK: - Helper Methods
    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dateOfBirth = dateOfBirth else { return 25 }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 25
    }
    
    private func calculateBMI(height: Double, weight: Double) -> Double {
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
    
    private func buildVariationContext(for exercise: Exercise, difficulty: Difficulty) -> [String: Any] {
        return [
            "exercise_name": exercise.name,
            "current_difficulty": difficulty.rawValue,
            "muscle_groups": exercise.muscleGroups ?? [],
            "equipment": exercise.equipment ?? "none",
            "instructions": exercise.instructions ?? ""
        ]
    }
    
    private func buildPerformanceContext(for workout: Workout) -> [String: Any] {
        return [
            "workout_type": workout.type ?? "unknown",
            "duration": workout.duration,
            "calories": workout.calories,
            "exercises_count": workout.exercises?.count ?? 0,
            "average_form_score": workout.averageFormScore,
            "completion_date": workout.endTime ?? workout.startTime
        ]
    }
    
    private func buildSuggestionContext(for history: WorkoutHistory) -> [String: Any] {
        return [
            "recent_workouts": history.recentWorkouts.map { workout in
                [
                    "type": workout.type ?? "unknown",
                    "date": workout.startTime,
                    "duration": workout.duration,
                    "calories": workout.calories
                ]
            },
            "workout_frequency": history.workoutFrequency,
            "preferred_types": history.preferredTypes,
            "avoided_types": history.avoidedTypes,
            "fitness_trend": history.fitnessTrend
        ]
    }
    
    private func parseExerciseVariations(_ response: String, for exercise: Exercise) throws -> [ExerciseVariation] {
        // Parse AI response for exercise variations
        // Implementation would parse the response and create ExerciseVariation objects
        return []
    }
    
    private func parsePerformanceAnalysis(_ response: String, for workout: Workout) throws -> WorkoutAnalysis {
        // Parse AI response for performance analysis
        // Implementation would parse the response and create WorkoutAnalysis object
        return WorkoutAnalysis(workout: workout, insights: [], recommendations: [])
    }
    
    private func parseWorkoutSuggestion(_ response: String, based on history: WorkoutHistory) throws -> WorkoutSuggestion {
        // Parse AI response for workout suggestion
        // Implementation would parse the response and create WorkoutSuggestion object
        return WorkoutSuggestion(type: .strength, reason: "Based on your recent workouts", priority: .high)
    }
}

// MARK: - Data Models
struct WorkoutPreferences {
    let type: WorkoutType
    let duration: Int // minutes
    let intensity: Intensity
    let focusAreas: [MuscleGroup]
    let availableEquipment: [Equipment]
    let location: Location
    let recentWorkoutTypes: [String]
    let targetCalories: Int
    let restDays: [Int] // 1 = Monday, 7 = Sunday
}

enum Intensity: String, CaseIterable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case extreme = "extreme"
}

enum MuscleGroup: String, CaseIterable {
    case chest = "chest"
    case back = "back"
    case shoulders = "shoulders"
    case biceps = "biceps"
    case triceps = "triceps"
    case legs = "legs"
    case core = "core"
    case fullBody = "full_body"
}

enum Equipment: String, CaseIterable {
    case none = "none"
    case dumbbells = "dumbbells"
    case barbell = "barbell"
    case resistanceBands = "resistance_bands"
    case pullUpBar = "pull_up_bar"
    case bench = "bench"
    case machine = "machine"
}

enum Location: String, CaseIterable {
    case home = "home"
    case gym = "gym"
    case outdoor = "outdoor"
    case hotel = "hotel"
}

enum Difficulty: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
}

enum ExerciseType: String, CaseIterable {
    case warmup = "warmup"
    case main = "main"
    case cooldown = "cooldown"
}

struct GeneratedWorkout {
    let name: String
    let type: WorkoutType
    let duration: TimeInterval
    let estimatedCalories: Int
    let difficulty: Difficulty
    let warmup: [GeneratedExercise]
    let mainWorkout: [GeneratedExercise]
    let cooldown: [GeneratedExercise]
    let tips: [String]
    let modifications: [String: String]
    let user: User
    let preferences: WorkoutPreferences
    let createdAt: Date
}

struct GeneratedExercise {
    let exercise: Exercise
    let type: ExerciseType
    let sets: Int
    let reps: Int
    let weight: String?
    let duration: TimeInterval
    let restTime: TimeInterval
    let instructions: String
    var order: Int
}

struct ExerciseVariation {
    let name: String
    let difficulty: Difficulty
    let instructions: String
    let modifications: [String]
}

struct WorkoutAnalysis {
    let workout: Workout
    let insights: [String]
    let recommendations: [String]
}

struct WorkoutSuggestion {
    let type: WorkoutType
    let reason: String
    let priority: Priority
}

enum Priority: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

struct WorkoutHistory {
    let recentWorkouts: [Workout]
    let workoutFrequency: Int // workouts per week
    let preferredTypes: [WorkoutType]
    let avoidedTypes: [WorkoutType]
    let fitnessTrend: String // "improving", "maintaining", "declining"
}

// MARK: - AI Response Models
struct AIWorkoutResponse: Codable {
    let name: String
    let type: String
    let duration: Int
    let calories: Int
    let difficulty: String
    let warmup: [AIExercise]
    let mainWorkout: [AIExercise]
    let cooldown: [AIExercise]
    let tips: [String]
    let modifications: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case name, type, duration, calories, difficulty, warmup, tips, modifications
        case mainWorkout = "main_workout"
    }
}

struct AIExercise: Codable {
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: String?
    let duration: Int?
    let rest: Int?
    let instructions: String
}

// MARK: - Error Types
enum AIWorkoutError: LocalizedError {
    case invalidResponse
    case parsingFailed
    case exerciseNotFound
    case aiServiceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .parsingFailed:
            return "Failed to parse AI response"
        case .exerciseNotFound:
            return "Exercise not found in library"
        case .aiServiceUnavailable:
            return "AI service is currently unavailable"
        }
    }
}

// MARK: - Protocol Extensions
protocol ExerciseLibraryProtocol {
    func findExercise(by name: String) throws -> Exercise?
    func saveExercise(_ exercise: Exercise) throws
}

protocol OpenAIServiceProtocol {
    func generateWorkout(prompt: String) async throws -> String
    func generateVariations(context: [String: Any]) async throws -> String
    func analyzePerformance(context: [String: Any]) async throws -> String
    func suggestWorkout(context: [String: Any]) async throws -> String
}

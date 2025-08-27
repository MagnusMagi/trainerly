import Foundation
import Combine

// MARK: - Exercise Library Service Protocol
protocol ExerciseLibraryServiceProtocol {
    func getAllExercises() async throws -> [Exercise]
    func getExercises(for muscleGroup: MuscleGroup) async throws -> [Exercise]
    func getExercises(for difficulty: Difficulty) async throws -> [Exercise]
    func getExercises(for equipment: Equipment) async throws -> [Exercise]
    func searchExercises(query: String) async throws -> [Exercise]
    func getExerciseDetails(id: String) async throws -> Exercise?
    func getExerciseVariations(for exercise: Exercise) async throws -> [ExerciseVariation]
    func getRecommendedExercises(for user: User, preferences: WorkoutPreferences) async throws -> [Exercise]
    func addCustomExercise(_ exercise: Exercise) async throws
    func updateExercise(_ exercise: Exercise) async throws
    func deleteExercise(id: String) async throws
    func getExerciseCategories() async throws -> [ExerciseCategory]
    func getPopularExercises(limit: Int) async throws -> [Exercise]
    func getRecentExercises(for user: User, limit: Int) async throws -> [Exercise]
}

// MARK: - Exercise Library Service
final class ExerciseLibraryService: ExerciseLibraryServiceProtocol {
    
    // MARK: - Properties
    private let exerciseRepository: ExerciseRepositoryProtocol
    private let aiWorkoutGenerator: AIWorkoutGeneratorProtocol
    private let userRepository: UserRepositoryProtocol
    private let cacheService: CacheServiceProtocol
    
    // MARK: - Initialization
    init(
        exerciseRepository: ExerciseRepositoryProtocol,
        aiWorkoutGenerator: AIWorkoutGeneratorProtocol,
        userRepository: UserRepositoryProtocol,
        cacheService: CacheServiceProtocol
    ) {
        self.exerciseRepository = exerciseRepository
        self.aiWorkoutGenerator = aiWorkoutGenerator
        self.userRepository = userRepository
        self.cacheService = cacheService
    }
    
    // MARK: - Public Methods
    func getAllExercises() async throws -> [Exercise] {
        // Check cache first
        if let cached = await getCachedExercises() {
            return cached
        }
        
        // Fetch from repository
        let exercises = try await exerciseRepository.getAllExercises()
        
        // Cache results
        await cacheExercises(exercises)
        
        return exercises
    }
    
    func getExercises(for muscleGroup: MuscleGroup) async throws -> [Exercise] {
        let cacheKey = "exercises_muscle_\(muscleGroup.rawValue)"
        
        // Check cache first
        if let cached = await cacheService.getObject([Exercise].self, forKey: cacheKey) {
            return cached
        }
        
        // Fetch from repository
        let exercises = try await exerciseRepository.getExercises(for: muscleGroup)
        
        // Cache results
        await cacheService.setObject(exercises, forKey: cacheKey, expiration: .hours(24))
        
        return exercises
    }
    
    func getExercises(for difficulty: Difficulty) async throws -> [Exercise] {
        let cacheKey = "exercises_difficulty_\(difficulty.rawValue)"
        
        // Check cache first
        if let cached = await cacheService.getObject([Exercise].self, forKey: cacheKey) {
            return cached
        }
        
        // Fetch from repository
        let exercises = try await exerciseRepository.getExercises(for: difficulty)
        
        // Cache results
        await cacheService.setObject(exercises, forKey: cacheKey, expiration: .hours(24))
        
        return exercises
    }
    
    func getExercises(for equipment: Equipment) async throws -> [Exercise] {
        let cacheKey = "exercises_equipment_\(equipment.rawValue)"
        
        // Check cache first
        if let cached = await cacheService.getObject([Exercise].self, forKey: cacheKey) {
            return cached
        }
        
        // Fetch from repository
        let exercises = try await exerciseRepository.getExercises(for: equipment)
        
        // Cache results
        await cacheService.setObject(exercises, forKey: cacheKey, expiration: .hours(24))
        
        return exercises
    }
    
    func searchExercises(query: String) async throws -> [Exercise] {
        // Search in repository
        let exercises = try await exerciseRepository.searchExercises(query: query)
        
        // Sort by relevance (exact matches first, then partial matches)
        return sortByRelevance(exercises, query: query)
    }
    
    func getExerciseDetails(id: String) async throws -> Exercise? {
        // Check cache first
        let cacheKey = "exercise_details_\(id)"
        if let cached = await cacheService.getObject(Exercise.self, forKey: cacheKey) {
            return cached
        }
        
        // Fetch from repository
        let exercise = try await exerciseRepository.getExercise(id: id)
        
        // Cache if found
        if let exercise = exercise {
            await cacheService.setObject(exercise, forKey: cacheKey, expiration: .hours(24))
        }
        
        return exercise
    }
    
    func getExerciseVariations(for exercise: Exercise) async throws -> [ExerciseVariation] {
        // Get variations from AI service
        let variations = try await aiWorkoutGenerator.generateExerciseVariations(
            for: exercise,
            difficulty: .intermediate
        )
        
        return variations
    }
    
    func getRecommendedExercises(for user: User, preferences: WorkoutPreferences) async throws -> [Exercise] {
        // Build recommendation context
        let context = buildRecommendationContext(for: user, preferences: preferences)
        
        // Get AI recommendations
        let recommendedWorkout = try await aiWorkoutGenerator.generateWorkout(for: user, preferences: preferences)
        
        // Extract unique exercises from the workout
        let allExercises = recommendedWorkout.warmup + recommendedWorkout.mainWorkout + recommendedWorkout.cooldown
        let uniqueExercises = Array(Set(allExercises.map { $0.exercise }))
        
        // Sort by relevance to user preferences
        let sortedExercises = sortByUserPreferences(uniqueExercises, user: user, preferences: preferences)
        
        return sortedExercises
    }
    
    func addCustomExercise(_ exercise: Exercise) async throws {
        // Validate exercise
        try validateExercise(exercise)
        
        // Set metadata
        exercise.id = UUID().uuidString
        exercise.createdAt = Date()
        exercise.updatedAt = Date()
        exercise.isCustom = true
        
        // Save to repository
        try await exerciseRepository.saveExercise(exercise)
        
        // Clear relevant caches
        await clearExerciseCaches()
    }
    
    func updateExercise(_ exercise: Exercise) async throws {
        // Validate exercise
        try validateExercise(exercise)
        
        // Update timestamp
        exercise.updatedAt = Date()
        
        // Save to repository
        try await exerciseRepository.updateExercise(exercise)
        
        // Clear relevant caches
        await clearExerciseCaches()
    }
    
    func deleteExercise(id: String) async throws {
        // Check if exercise exists
        guard let exercise = try await exerciseRepository.getExercise(id: id) else {
            throw ExerciseLibraryError.exerciseNotFound
        }
        
        // Check if it's a custom exercise
        guard exercise.isCustom else {
            throw ExerciseLibraryError.cannotDeleteSystemExercise
        }
        
        // Delete from repository
        try await exerciseRepository.deleteExercise(id: id)
        
        // Clear relevant caches
        await clearExerciseCaches()
    }
    
    func getExerciseCategories() async throws -> [ExerciseCategory] {
        // Check cache first
        let cacheKey = "exercise_categories"
        if let cached = await cacheService.getObject([ExerciseCategory].self, forKey: cacheKey) {
            return cached
        }
        
        // Get all exercises to build categories
        let exercises = try await getAllExercises()
        
        // Build categories from exercises
        let categories = buildExerciseCategories(from: exercises)
        
        // Cache results
        await cacheService.setObject(categories, forKey: cacheKey, expiration: .hours(24))
        
        return categories
    }
    
    func getPopularExercises(limit: Int) async throws -> [Exercise] {
        // Get popular exercises based on usage statistics
        let exercises = try await exerciseRepository.getPopularExercises(limit: limit)
        
        return exercises
    }
    
    func getRecentExercises(for user: User, limit: Int) async throws -> [Exercise] {
        // Get exercises from user's recent workouts
        let exercises = try await exerciseRepository.getRecentExercises(for: user, limit: limit)
        
        return exercises
    }
    
    // MARK: - Private Methods
    private func getCachedExercises() async -> [Exercise]? {
        return await cacheService.getObject([Exercise].self, forKey: "all_exercises")
    }
    
    private func cacheExercises(_ exercises: [Exercise]) async {
        await cacheService.setObject(exercises, forKey: "all_exercises", expiration: .hours(24))
    }
    
    private func clearExerciseCaches() async {
        let keys = [
            "all_exercises",
            "exercise_categories"
        ]
        
        for key in keys {
            await cacheService.removeObject(forKey: key)
        }
        
        // Clear muscle group caches
        for muscleGroup in MuscleGroup.allCases {
            let key = "exercises_muscle_\(muscleGroup.rawValue)"
            await cacheService.removeObject(forKey: key)
        }
        
        // Clear difficulty caches
        for difficulty in Difficulty.allCases {
            let key = "exercises_difficulty_\(difficulty.rawValue)"
            await cacheService.removeObject(forKey: key)
        }
        
        // Clear equipment caches
        for equipment in Equipment.allCases {
            let key = "exercises_equipment_\(equipment.rawValue)"
            await cacheService.removeObject(forKey: key)
        }
    }
    
    private func sortByRelevance(_ exercises: [Exercise], query: String) -> [Exercise] {
        let lowercasedQuery = query.lowercased()
        
        return exercises.sorted { exercise1, exercise2 in
            let score1 = calculateRelevanceScore(exercise1, query: lowercasedQuery)
            let score2 = calculateRelevanceScore(exercise2, query: lowercasedQuery)
            return score1 > score2
        }
    }
    
    private func calculateRelevanceScore(_ exercise: Exercise, query: String) -> Int {
        var score = 0
        
        // Exact name match
        if exercise.name.lowercased() == query {
            score += 100
        }
        // Name contains query
        else if exercise.name.lowercased().contains(query) {
            score += 50
        }
        
        // Description contains query
        if let description = exercise.description, description.lowercased().contains(query) {
            score += 25
        }
        
        // Category contains query
        if let category = exercise.category, category.lowercased().contains(query) {
            score += 20
        }
        
        // Muscle groups contain query
        if let muscleGroups = exercise.muscleGroups {
            for muscleGroup in muscleGroups {
                if muscleGroup.lowercased().contains(query) {
                    score += 15
                    break
                }
            }
        }
        
        // Equipment contains query
        if let equipment = exercise.equipment, equipment.lowercased().contains(query) {
            score += 10
        }
        
        return score
    }
    
    private func buildRecommendationContext(for user: User, preferences: WorkoutPreferences) -> [String: Any] {
        return [
            "user_profile": [
                "fitness_level": user.fitnessLevel ?? "beginner",
                "goals": user.goals ?? [],
                "restrictions": user.restrictions ?? [],
                "age": calculateAge(from: user.dateOfBirth),
                "gender": user.gender ?? "not_specified"
            ],
            "workout_preferences": [
                "type": preferences.type.rawValue,
                "intensity": preferences.intensity.rawValue,
                "focus_areas": preferences.focusAreas.map { $0.rawValue },
                "equipment_available": preferences.availableEquipment.map { $0.rawValue }
            ]
        ]
    }
    
    private func sortByUserPreferences(_ exercises: [Exercise], user: User, preferences: WorkoutPreferences) -> [Exercise] {
        return exercises.sorted { exercise1, exercise2 in
            let score1 = calculateUserPreferenceScore(exercise1, user: user, preferences: preferences)
            let score2 = calculateUserPreferenceScore(exercise2, user: user, preferences: preferences)
            return score1 > score2
        }
    }
    
    private func calculateUserPreferenceScore(_ exercise: Exercise, user: User, preferences: WorkoutPreferences) -> Int {
        var score = 0
        
        // Match focus areas
        if let muscleGroups = exercise.muscleGroups {
            for muscleGroup in muscleGroups {
                if preferences.focusAreas.contains(MuscleGroup(rawValue: muscleGroup) ?? .fullBody) {
                    score += 20
                }
            }
        }
        
        // Match available equipment
        if let equipment = exercise.equipment {
            let exerciseEquipment = Equipment(rawValue: equipment) ?? .none
            if preferences.availableEquipment.contains(exerciseEquipment) {
                score += 15
            }
        }
        
        // Match fitness level
        if let difficulty = exercise.difficulty {
            let exerciseDifficulty = Difficulty(rawValue: difficulty) ?? .beginner
            let userLevel = Difficulty(rawValue: user.fitnessLevel ?? "beginner") ?? .beginner
            
            switch (exerciseDifficulty, userLevel) {
            case (.beginner, .beginner):
                score += 10
            case (.intermediate, .intermediate):
                score += 10
            case (.advanced, .advanced):
                score += 10
            case (.intermediate, .beginner):
                score += 5
            case (.advanced, .intermediate):
                score += 5
            default:
                score += 0
            }
        }
        
        // Bonus for popular exercises
        if exercise.isPopular {
            score += 5
        }
        
        return score
    }
    
    private func validateExercise(_ exercise: Exercise) throws {
        guard !exercise.name.isEmpty else {
            throw ExerciseLibraryError.invalidExerciseName
        }
        
        guard exercise.name.count >= 3 else {
            throw ExerciseLibraryError.exerciseNameTooShort
        }
        
        guard exercise.name.count <= 100 else {
            throw ExerciseLibraryError.exerciseNameTooLong
        }
        
        if let description = exercise.description, description.count > 1000 {
            throw ExerciseLibraryError.exerciseDescriptionTooLong
        }
    }
    
    private func buildExerciseCategories(from exercises: [Exercise]) -> [ExerciseCategory] {
        var categories: [String: [Exercise]] = [:]
        
        // Group exercises by category
        for exercise in exercises {
            let category = exercise.category ?? "Uncategorized"
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(exercise)
        }
        
        // Convert to ExerciseCategory objects
        return categories.map { categoryName, exercises in
            ExerciseCategory(
                name: categoryName,
                exerciseCount: exercises.count,
                exercises: exercises
            )
        }.sorted { $0.exerciseCount > $1.exerciseCount }
    }
    
    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dateOfBirth = dateOfBirth else { return 25 }
        
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dateOfBirth, to: Date())
        return ageComponents.year ?? 25
    }
}

// MARK: - Data Models
struct ExerciseCategory {
    let name: String
    let exerciseCount: Int
    let exercises: [Exercise]
}

// MARK: - Error Types
enum ExerciseLibraryError: LocalizedError {
    case exerciseNotFound
    case cannotDeleteSystemExercise
    case invalidExerciseName
    case exerciseNameTooShort
    case exerciseNameTooLong
    case exerciseDescriptionTooLong
    case invalidExerciseData
    
    var errorDescription: String? {
        switch self {
        case .exerciseNotFound:
            return "Exercise not found"
        case .cannotDeleteSystemExercise:
            return "Cannot delete system exercises"
        case .invalidExerciseName:
            return "Invalid exercise name"
        case .exerciseNameTooShort:
            return "Exercise name is too short"
        case .exerciseNameTooLong:
            return "Exercise name is too long"
        case .exerciseDescriptionTooLong:
            return "Exercise description is too long"
        case .invalidExerciseData:
            return "Invalid exercise data"
        }
    }
}

// MARK: - Protocol Extensions
protocol ExerciseRepositoryProtocol {
    func getAllExercises() async throws -> [Exercise]
    func getExercises(for muscleGroup: MuscleGroup) async throws -> [Exercise]
    func getExercises(for difficulty: Difficulty) async throws -> [Exercise]
    func getExercises(for equipment: Equipment) async throws -> [Exercise]
    func searchExercises(query: String) async throws -> [Exercise]
    func getExercise(id: String) async throws -> Exercise?
    func saveExercise(_ exercise: Exercise) async throws
    func updateExercise(_ exercise: Exercise) async throws
    func deleteExercise(id: String) async throws
    func getPopularExercises(limit: Int) async throws -> [Exercise]
    func getRecentExercises(for user: User, limit: Int) async throws -> [Exercise]
}

// MARK: - Exercise Extensions
extension Exercise {
    var isCustom: Bool {
        get {
            // This would be a property in the Core Data model
            return false
        }
        set {
            // This would set a property in the Core Data model
        }
    }
    
    var difficulty: String? {
        get {
            // This would be a property in the Core Data model
            return nil
        }
        set {
            // This would set a property in the Core Data model
        }
    }
    
    var isPopular: Bool {
        // This would be calculated based on usage statistics
        return false
    }
}

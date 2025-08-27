import Foundation
import Combine
import HealthKit

// MARK: - Workout Tracking Service Protocol
protocol WorkoutTrackingServiceProtocol: ObservableObject {
    var currentWorkout: ActiveWorkout? { get }
    var isWorkoutActive: Bool { get }
    var workoutDuration: TimeInterval { get }
    var currentExercise: ActiveExercise? { get }
    
    func startWorkout(_ workout: GeneratedWorkout) async throws
    func pauseWorkout() async throws
    func resumeWorkout() async throws
    func endWorkout() async throws -> WorkoutSummary
    func skipExercise() async throws
    func completeExercise() async throws
    func updateExerciseProgress(_ progress: ExerciseProgress) async throws
    func getWorkoutHistory(limit: Int) async throws -> [WorkoutSummary]
}

// MARK: - Workout Tracking Service
final class WorkoutTrackingService: NSObject, WorkoutTrackingServiceProtocol {
    
    // MARK: - Published Properties
    @Published var currentWorkout: ActiveWorkout?
    @Published var isWorkoutActive: Bool = false
    @Published var workoutDuration: TimeInterval = 0
    @Published var currentExercise: ActiveExercise?
    
    // MARK: - Private Properties
    private let healthKitManager: HealthKitManagerProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private let formAnalysisService: FormAnalysisServiceProtocol
    private var workoutTimer: Timer?
    private var exerciseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        healthKitManager: HealthKitManagerProtocol,
        workoutRepository: WorkoutRepositoryProtocol,
        formAnalysisService: FormAnalysisServiceProtocol
    ) {
        self.healthKitManager = healthKitManager
        self.workoutRepository = workoutRepository
        self.formAnalysisService = formAnalysisService
        super.init()
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    func startWorkout(_ workout: GeneratedWorkout) async throws {
        // Create active workout
        let activeWorkout = ActiveWorkout(
            id: UUID().uuidString,
            generatedWorkout: workout,
            startTime: Date(),
            status: .active
        )
        
        // Start HealthKit workout session
        let healthKitSession = healthKitManager.startWorkoutSession(type: workout.type.healthKitType)
        
        guard let session = healthKitSession else {
            throw WorkoutTrackingError.failedToStartHealthKitSession
        }
        
        // Update active workout with HealthKit session
        activeWorkout.healthKitSession = session
        
        // Start workout timer
        startWorkoutTimer()
        
        // Set first exercise
        if let firstExercise = workout.warmup.first {
            try await startExercise(firstExercise, type: .warmup)
        }
        
        // Update state
        await MainActor.run {
            self.currentWorkout = activeWorkout
            self.isWorkoutActive = true
        }
        
        // Save to repository
        try await saveWorkoutToRepository(activeWorkout)
    }
    
    func pauseWorkout() async throws {
        guard let workout = currentWorkout else {
            throw WorkoutTrackingError.noActiveWorkout
        }
        
        // Pause HealthKit session
        workout.healthKitSession?.pause()
        
        // Pause timers
        pauseWorkoutTimer()
        pauseExerciseTimer()
        
        // Update workout status
        workout.status = .paused
        workout.pauseTime = Date()
        
        // Update state
        await MainActor.run {
            self.currentWorkout = workout
        }
        
        // Save to repository
        try await saveWorkoutToRepository(workout)
    }
    
    func resumeWorkout() async throws {
        guard let workout = currentWorkout else {
            throw WorkoutTrackingError.noActiveWorkout
        }
        
        // Resume HealthKit session
        workout.healthKitSession?.resume()
        
        // Resume timers
        resumeWorkoutTimer()
        resumeExerciseTimer()
        
        // Update workout status
        workout.status = .active
        workout.resumeTime = Date()
        
        // Update state
        await MainActor.run {
            self.currentWorkout = workout
        }
        
        // Save to repository
        try await saveWorkoutToRepository(workout)
    }
    
    func endWorkout() async throws -> WorkoutSummary {
        guard let workout = currentWorkout else {
            throw WorkoutTrackingError.noActiveWorkout
        }
        
        // Stop timers
        stopWorkoutTimer()
        stopExerciseTimer()
        
        // End HealthKit session
        let endTime = Date()
        workout.healthKitSession?.end()
        
        // Calculate final metrics
        let finalMetrics = calculateFinalMetrics(workout: workout, endTime: endTime)
        
        // Create workout summary
        let summary = WorkoutSummary(
            id: workout.id,
            name: workout.generatedWorkout.name,
            type: workout.generatedWorkout.type,
            startTime: workout.startTime,
            endTime: endTime,
            duration: finalMetrics.duration,
            calories: finalMetrics.calories,
            distance: finalMetrics.distance,
            exercises: finalMetrics.exercises,
            averageFormScore: finalMetrics.averageFormScore,
            healthKitSession: workout.healthKitSession
        )
        
        // Save to HealthKit
        try await healthKitManager.saveWorkout(summary)
        
        // Save to repository
        try await saveWorkoutSummaryToRepository(summary)
        
        // Clear current workout
        await MainActor.run {
            self.currentWorkout = nil
            self.isWorkoutActive = false
            self.workoutDuration = 0
            self.currentExercise = nil
        }
        
        return summary
    }
    
    func skipExercise() async throws {
        guard let workout = currentWorkout,
              let currentExercise = currentExercise else {
            throw WorkoutTrackingError.noActiveExercise
        }
        
        // Mark exercise as skipped
        currentExercise.status = .skipped
        currentExercise.endTime = Date()
        
        // Move to next exercise
        try await moveToNextExercise()
    }
    
    func completeExercise() async throws {
        guard let workout = currentWorkout,
              let currentExercise = currentExercise else {
            throw WorkoutTrackingError.noActiveExercise
        }
        
        // Mark exercise as completed
        currentExercise.status = .completed
        currentExercise.endTime = Date()
        
        // Stop exercise timer
        stopExerciseTimer()
        
        // Move to next exercise
        try await moveToNextExercise()
    }
    
    func updateExerciseProgress(_ progress: ExerciseProgress) async throws {
        guard let exercise = currentExercise else {
            throw WorkoutTrackingError.noActiveExercise
        }
        
        // Update exercise progress
        exercise.currentSet = progress.currentSet
        exercise.currentRep = progress.currentRep
        exercise.currentWeight = progress.currentWeight
        exercise.formScore = progress.formScore
        exercise.notes = progress.notes
        
        // Update current exercise
        await MainActor.run {
            self.currentExercise = exercise
        }
    }
    
    func getWorkoutHistory(limit: Int) async throws -> [WorkoutSummary] {
        return try await workoutRepository.getWorkoutHistory(limit: limit)
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Monitor workout duration
        $workoutDuration
            .sink { [weak self] duration in
                self?.updateWorkoutDuration(duration)
            }
            .store(in: &cancellables)
    }
    
    private func startWorkoutTimer() {
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateWorkoutDuration()
        }
    }
    
    private func pauseWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }
    
    private func resumeWorkoutTimer() {
        startWorkoutTimer()
    }
    
    private func stopWorkoutTimer() {
        workoutTimer?.invalidate()
        workoutTimer = nil
    }
    
    private func startExerciseTimer() {
        exerciseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateExerciseDuration()
        }
    }
    
    private func pauseExerciseTimer() {
        exerciseTimer?.invalidate()
        exerciseTimer = nil
    }
    
    private func resumeExerciseTimer() {
        startExerciseTimer()
    }
    
    private func stopExerciseTimer() {
        exerciseTimer?.invalidate()
        exerciseTimer = nil
    }
    
    private func updateWorkoutDuration() {
        guard let workout = currentWorkout else { return }
        
        let duration = Date().timeIntervalSince(workout.startTime)
        
        await MainActor.run {
            self.workoutDuration = duration
        }
    }
    
    private func updateWorkoutDuration(_ duration: TimeInterval) {
        guard let workout = currentWorkout else { return }
        workout.duration = duration
    }
    
    private func updateExerciseDuration() {
        guard let exercise = currentExercise else { return }
        
        let duration = Date().timeIntervalSince(exercise.startTime)
        exercise.duration = duration
    }
    
    private func startExercise(_ exercise: GeneratedExercise, type: ExerciseType) async throws {
        let activeExercise = ActiveExercise(
            id: UUID().uuidString,
            exercise: exercise.exercise,
            type: type,
            startTime: Date(),
            status: .active,
            targetSets: exercise.sets,
            targetReps: exercise.reps,
            targetWeight: exercise.weight,
            instructions: exercise.instructions
        )
        
        // Start exercise timer
        startExerciseTimer()
        
        // Update current exercise
        await MainActor.run {
            self.currentExercise = activeExercise
        }
        
        // Add to workout
        currentWorkout?.exercises.append(activeExercise)
    }
    
    private func moveToNextExercise() async throws {
        guard let workout = currentWorkout else { return }
        
        let currentIndex = workout.exercises.firstIndex { $0.id == currentExercise?.id }
        let nextIndex = (currentIndex ?? -1) + 1
        
        // Check if we're done with warmup
        if let currentExercise = currentExercise,
           currentExercise.type == .warmup,
           nextIndex >= workout.generatedWorkout.warmup.count {
            // Move to main workout
            if let firstMainExercise = workout.generatedWorkout.mainWorkout.first {
                try await startExercise(firstMainExercise, type: .main)
                return
            }
        }
        
        // Check if we're done with main workout
        if let currentExercise = currentExercise,
           currentExercise.type == .main,
           nextIndex >= workout.generatedWorkout.mainWorkout.count {
            // Move to cooldown
            if let firstCooldownExercise = workout.generatedWorkout.cooldown.first {
                try await startExercise(firstCooldownExercise, type: .cooldown)
                return
            }
        }
        
        // Check if we're done with cooldown
        if let currentExercise = currentExercise,
           currentExercise.type == .cooldown,
           nextIndex >= workout.generatedWorkout.cooldown.count {
            // Workout is complete
            try await endWorkout()
            return
        }
        
        // Move to next exercise of same type
        let exercises = getExercisesForType(currentExercise?.type ?? .warmup)
        if nextIndex < exercises.count {
            try await startExercise(exercises[nextIndex], type: currentExercise?.type ?? .warmup)
        }
    }
    
    private func getExercisesForType(_ type: ExerciseType) -> [GeneratedExercise] {
        switch type {
        case .warmup:
            return currentWorkout?.generatedWorkout.warmup ?? []
        case .main:
            return currentWorkout?.generatedWorkout.mainWorkout ?? []
        case .cooldown:
            return currentWorkout?.generatedWorkout.cooldown ?? []
        }
    }
    
    private func calculateFinalMetrics(workout: ActiveWorkout, endTime: Date) -> WorkoutFinalMetrics {
        let duration = endTime.timeIntervalSince(workout.startTime)
        
        // Calculate calories (basic estimation)
        let calories = calculateCalories(duration: duration, workoutType: workout.generatedWorkout.type)
        
        // Calculate distance (if applicable)
        let distance = calculateDistance(workoutType: workout.generatedWorkout.type)
        
        // Calculate average form score
        let completedExercises = workout.exercises.filter { $0.status == .completed }
        let averageFormScore = completedExercises.isEmpty ? 0.0 : 
            completedExercises.reduce(0.0) { $0 + $1.formScore } / Double(completedExercises.count)
        
        // Convert exercises to summaries
        let exerciseSummaries = workout.exercises.map { exercise in
            ExerciseSummary(
                name: exercise.exercise.name,
                startTime: exercise.startTime,
                endTime: exercise.endTime ?? exercise.startTime,
                sets: exercise.targetSets,
                reps: exercise.targetReps,
                weight: exercise.targetWeight,
                formScore: exercise.formScore
            )
        }
        
        return WorkoutFinalMetrics(
            duration: duration,
            calories: calories,
            distance: distance,
            exercises: exerciseSummaries,
            averageFormScore: averageFormScore
        )
    }
    
    private func calculateCalories(duration: TimeInterval, workoutType: WorkoutType) -> Double {
        // Basic calorie calculation based on workout type and duration
        let minutes = duration / 60.0
        let baseCaloriesPerMinute: Double
        
        switch workoutType {
        case .strength:
            baseCaloriesPerMinute = 6.0
        case .cardio:
            baseCaloriesPerMinute = 10.0
        case .yoga:
            baseCaloriesPerMinute = 3.0
        case .hiit:
            baseCaloriesPerMinute = 12.0
        case .flexibility:
            baseCaloriesPerMinute = 2.0
        }
        
        return baseCaloriesPerMinute * minutes
    }
    
    private func calculateDistance(workoutType: WorkoutType) -> Double? {
        // Only return distance for cardio workouts
        switch workoutType {
        case .cardio, .hiit:
            return 0.0 // Would be calculated from GPS/HealthKit data
        default:
            return nil
        }
    }
    
    private func saveWorkoutToRepository(_ workout: ActiveWorkout) async throws {
        // Convert to repository model and save
        // This would save the active workout state
    }
    
    private func saveWorkoutSummaryToRepository(_ summary: WorkoutSummary) async throws {
        try await workoutRepository.saveWorkout(summary)
    }
}

// MARK: - Data Models
class ActiveWorkout: ObservableObject {
    let id: String
    let generatedWorkout: GeneratedWorkout
    let startTime: Date
    var status: WorkoutStatus
    var pauseTime: Date?
    var resumeTime: Date?
    var duration: TimeInterval = 0
    var exercises: [ActiveExercise] = []
    var healthKitSession: HKWorkoutSession?
    
    init(id: String, generatedWorkout: GeneratedWorkout, startTime: Date, status: WorkoutStatus) {
        self.id = id
        self.generatedWorkout = generatedWorkout
        self.startTime = startTime
        self.status = status
    }
}

class ActiveExercise: ObservableObject {
    let id: String
    let exercise: Exercise
    let type: ExerciseType
    let startTime: Date
    var status: ExerciseStatus
    var endTime: Date?
    var duration: TimeInterval = 0
    var currentSet: Int = 0
    var currentRep: Int = 0
    var currentWeight: String?
    var formScore: Double = 0.0
    var notes: String = ""
    
    let targetSets: Int
    let targetReps: Int
    let targetWeight: String?
    let instructions: String
    
    init(id: String, exercise: Exercise, type: ExerciseType, startTime: Date, status: ExerciseStatus, targetSets: Int, targetReps: Int, targetWeight: String?, instructions: String) {
        self.id = id
        self.exercise = exercise
        self.type = type
        self.startTime = startTime
        self.status = status
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.instructions = instructions
    }
}

enum WorkoutStatus: String, CaseIterable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"
}

enum ExerciseStatus: String, CaseIterable {
    case active = "active"
    case completed = "completed"
    case skipped = "skipped"
    case paused = "paused"
}

struct ExerciseProgress {
    let currentSet: Int
    let currentRep: Int
    let currentWeight: String?
    let formScore: Double
    let notes: String
}

struct WorkoutFinalMetrics {
    let duration: TimeInterval
    let calories: Double
    let distance: Double?
    let exercises: [ExerciseSummary]
    let averageFormScore: Double
}

// MARK: - Error Types
enum WorkoutTrackingError: LocalizedError {
    case noActiveWorkout
    case noActiveExercise
    case failedToStartHealthKitSession
    case exerciseNotFound
    case invalidWorkoutState
    
    var errorDescription: String? {
        switch self {
        case .noActiveWorkout:
            return "No active workout found"
        case .noActiveExercise:
            return "No active exercise found"
        case .failedToStartHealthKitSession:
            return "Failed to start HealthKit workout session"
        case .exerciseNotFound:
            return "Exercise not found in workout"
        case .invalidWorkoutState:
            return "Invalid workout state"
        }
    }
}

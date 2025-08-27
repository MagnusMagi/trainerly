import Foundation
import HealthKit
import Combine
import SwiftUI

// MARK: - HealthKit Manager Protocol
protocol HealthKitManagerProtocol: ObservableObject {
    var isHealthKitAvailable: Bool { get }
    var authorizationStatus: HKAuthorizationStatus { get }
    var isAuthorized: Bool { get }
    
    func requestAuthorization() async throws
    func startWorkoutSession(type: HKWorkoutActivityType) -> HKWorkoutSession?
    func endWorkoutSession(_ session: HKWorkoutSession, with summary: WorkoutSummary)
    func fetchTodayStats() async throws -> HealthStats
    func fetchWorkoutHistory(limit: Int) async throws -> [HKWorkout]
    func saveWorkout(_ workout: WorkoutSummary) async throws
}

// MARK: - HealthKit Manager
final class HealthKitManager: NSObject, HealthKitManagerProtocol {
    
    // MARK: - Published Properties
    @Published var isHealthKitAvailable: Bool = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    @Published var isAuthorized: Bool = false
    @Published var currentWorkoutSession: HKWorkoutSession?
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Health Data Types
    private let readTypes: Set<HKObjectType> = [
        .workoutType(),
        .quantityType(forIdentifier: .heartRate)!,
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .stepCount)!,
        .quantityType(forIdentifier: .vo2Max)!,
        .quantityType(forIdentifier: .restingHeartRate)!,
        .quantityType(forIdentifier: .bodyMass)!,
        .quantityType(forIdentifier: .bodyFatPercentage)!,
        .quantityType(forIdentifier: .leanBodyMass)!,
        .quantityType(forIdentifier: .height)!,
        .quantityType(forIdentifier: .bodyMassIndex)!,
        .quantityType(forIdentifier: .waistCircumference)!,
        .quantityType(forIdentifier: .appleExerciseTime)!,
        .quantityType(forIdentifier: .appleStandTime)!,
        .quantityType(forIdentifier: .appleStandHours)!,
        .quantityType(forIdentifier: .distanceWalkingRunning)!,
        .quantityType(forIdentifier: .distanceCycling)!,
        .quantityType(forIdentifier: .distanceSwimming)!,
        .quantityType(forIdentifier: .flightsClimbed)!,
        .categoryType(forIdentifier: .sleepAnalysis)!,
        .categoryType(forIdentifier: .mindfulSession)!
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        .workoutType(),
        .quantityType(forIdentifier: .activeEnergyBurned)!,
        .quantityType(forIdentifier: .heartRate)!,
        .quantityType(forIdentifier: .stepCount)!
    ]
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupHealthKit()
    }
    
    // MARK: - Setup
    private func setupHealthKit() {
        isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
        
        if isHealthKitAvailable {
            checkAuthorizationStatus()
        }
    }
    
    private func checkAuthorizationStatus() {
        let workoutType = HKObjectType.workoutType()
        authorizationStatus = healthStore.authorizationStatus(for: workoutType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }
    
    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard isHealthKitAvailable else {
            throw HealthKitError.notAvailable
        }
        
        do {
            try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
            
            await MainActor.run {
                self.checkAuthorizationStatus()
            }
            
            // Setup background delivery for workouts
            try await setupBackgroundDelivery()
            
        } catch {
            throw HealthKitError.authorizationFailed(error)
        }
    }
    
    private func setupBackgroundDelivery() async throws {
        let workoutType = HKObjectType.workoutType()
        
        try await withCheckedThrowingContinuation { continuation in
            healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { success, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.backgroundDeliveryFailed(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Workout Sessions
    func startWorkoutSession(type: HKWorkoutActivityType) -> HKWorkoutSession? {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = type
        configuration.locationType = .indoor
        
        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            
            // Configure builder
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, configuration: configuration)
            
            // Start session
            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("❌ Failed to begin workout collection: \(error)")
                }
            }
            
            // Store references
            workoutSession = session
            workoutBuilder = builder
            currentWorkoutSession = session
            
            return session
            
        } catch {
            print("❌ Failed to create workout session: \(error)")
            return nil
        }
    }
    
    func endWorkoutSession(_ session: HKWorkoutSession, with summary: WorkoutSummary) {
        session.end()
        
        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("❌ Failed to end workout collection: \(error)")
                return
            }
            
            // Finish workout
            self.workoutBuilder?.finishWorkout { workout, error in
                if let error = error {
                    print("❌ Failed to finish workout: \(error)")
                    return
                }
                
                // Save workout summary
                Task {
                    try? await self.saveWorkout(summary)
                }
            }
        }
        
        // Clear references
        workoutSession = nil
        workoutBuilder = nil
        currentWorkoutSession = nil
    }
    
    // MARK: - Data Fetching
    func fetchTodayStats() async throws -> HealthStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        async let steps = fetchQuantity(for: .stepCount, unit: .count(), start: startOfDay, end: endOfDay)
        async let calories = fetchQuantity(for: .activeEnergyBurned, unit: .kilocalorie(), start: startOfDay, end: endOfDay)
        async let exerciseTime = fetchQuantity(for: .appleExerciseTime, unit: .minute(), start: startOfDay, end: endOfDay)
        async let standTime = fetchQuantity(for: .appleStandTime, unit: .minute(), start: startOfDay, end: endOfDay)
        async let distance = fetchQuantity(for: .distanceWalkingRunning, unit: .meter(), start: startOfDay, end: endOfDay)
        async let flights = fetchQuantity(for: .flightsClimbed, unit: .count(), start: startOfDay, end: endOfDay)
        async let heartRate = fetchAverageHeartRate(start: startOfDay, end: endOfDay)
        async let restingHR = fetchRestingHeartRate()
        async let vo2Max = fetchVO2Max()
        async let sleep = fetchSleepHours(for: Date())
        
        return try await HealthStats(
            steps: steps,
            calories: calories,
            exerciseTime: exerciseTime,
            standTime: standTime,
            distance: distance,
            flights: flights,
            heartRate: heartRate,
            restingHeartRate: restingHR,
            vo2Max: vo2Max,
            sleepHours: sleep
        )
    }
    
    func fetchWorkoutHistory(limit: Int) async throws -> [HKWorkout] {
        let workoutType = HKObjectType.workoutType()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: nil,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { _, samples, error in
            // Handle in continuation
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var workouts: [HKWorkout] = []
            
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: nil,
                limit: limit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                    return
                }
                
                if let workouts = samples as? [HKWorkout] {
                    continuation.resume(returning: workouts)
                } else {
                    continuation.resume(returning: [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Private Fetch Methods
    private func fetchQuantity(
        for identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        let quantityType = HKQuantityType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                } else if let sum = result?.sumQuantity() {
                    let value = sum.doubleValue(for: unit)
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchAverageHeartRate(start: Date, end: Date) async throws -> Int {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: heartRateType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                } else if let average = result?.averageQuantity() {
                    let value = average.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: Int(value))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchRestingHeartRate() async throws -> Int {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                } else if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.resume(returning: Int(value))
                } else {
                    continuation.resume(returning: 0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchVO2Max() async throws -> Double? {
        let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max)!
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                } else if let sample = samples?.first as? HKQuantitySample {
                    let value = sample.quantity.doubleValue(for: HKUnit(from: "ml/kg/min"))
                    continuation.resume(returning: value)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    private func fetchSleepHours(for date: Date) async throws -> Double {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.fetchFailed(error))
                } else if let sleepSamples = samples as? [HKCategorySample] {
                    let totalSleep = sleepSamples.reduce(0.0) { total, sample in
                        total + sample.endDate.timeIntervalSince(sample.startDate)
                    }
                    let hours = totalSleep / 3600
                    continuation.resume(returning: hours)
                } else {
                    continuation.resume(returning: 0.0)
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Data Saving
    func saveWorkout(_ workout: WorkoutSummary) async throws {
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: workout.calories)
        
        var metadata: [String: Any] = [
            "ExerciseCount": workout.exercises.count,
            "AverageFormScore": workout.averageFormScore,
            "WorkoutType": workout.type.rawValue,
            "TrainerlyApp": true
        ]
        
        let hkWorkout = HKWorkout(
            activityType: workout.type.healthKitType,
            start: workout.startTime,
            end: workout.endTime,
            workoutEvents: nil,
            totalEnergyBurned: energyBurned,
            totalDistance: workout.distance != nil ? HKQuantity(unit: .meter(), doubleValue: workout.distance!) : nil,
            metadata: metadata
        )
        
        try await healthStore.save(hkWorkout)
        
        // Save individual exercise samples if available
        if !workout.exercises.isEmpty {
            try await saveExerciseSamples(workout.exercises, for: hkWorkout)
        }
    }
    
    private func saveExerciseSamples(_ exercises: [ExerciseSummary], for workout: HKWorkout) async throws {
        for exercise in exercises {
            let exerciseType = HKObjectType.workoutType()
            let exerciseWorkout = HKWorkout(
                activityType: .functionalStrengthTraining,
                start: exercise.startTime,
                end: exercise.endTime,
                workoutEvents: nil,
                totalEnergyBurned: nil,
                totalDistance: nil,
                metadata: [
                    "ExerciseName": exercise.name,
                    "Sets": exercise.sets,
                    "Reps": exercise.reps,
                    "Weight": exercise.weight,
                    "FormScore": exercise.formScore,
                    "ParentWorkout": workout.uuid.uuidString
                ]
            )
            
            try await healthStore.save(exerciseWorkout)
        }
    }
}

// MARK: - Data Models
struct HealthStats {
    let steps: Double
    let calories: Double
    let exerciseTime: Double
    let standTime: Double
    let distance: Double
    let flights: Double
    let heartRate: Int
    let restingHeartRate: Int
    let vo2Max: Double?
    let sleepHours: Double
}

struct WorkoutSummary {
    let type: WorkoutType
    let startTime: Date
    let endTime: Date
    let duration: TimeInterval
    let calories: Double
    let distance: Double?
    let exercises: [ExerciseSummary]
    let averageFormScore: Double
}

struct ExerciseSummary {
    let name: String
    let startTime: Date
    let endTime: Date
    let sets: Int
    let reps: Int
    let weight: Double
    let formScore: Double
}

enum WorkoutType: String, CaseIterable {
    case strength = "strength"
    case cardio = "cardio"
    case yoga = "yoga"
    case hiit = "hiit"
    case flexibility = "flexibility"
    
    var healthKitType: HKWorkoutActivityType {
        switch self {
        case .strength:
            return .functionalStrengthTraining
        case .cardio:
            return .traditionalStrengthTraining
        case .yoga:
            return .yoga
        case .hiit:
            return .highIntensityIntervalTraining
        case .flexibility:
            return .flexibility
        }
    }
}

// MARK: - Error Types
enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationFailed(Error)
    case backgroundDeliveryFailed(Error)
    case fetchFailed(Error)
    case saveFailed(Error)
    case workoutSessionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationFailed(let error):
            return "Failed to authorize HealthKit: \(error.localizedDescription)"
        case .backgroundDeliveryFailed(let error):
            return "Failed to setup background delivery: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch health data: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save workout: \(error.localizedDescription)"
        case .workoutSessionFailed(let error):
            return "Workout session failed: \(error.localizedDescription)"
        }
    }
}

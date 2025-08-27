import Foundation
import Combine
import SwiftUI

// MARK: - AI Coach Chat ViewModel
@MainActor
final class AICoachChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isProcessing: Bool = false
    @Published var currentExercise: Exercise?
    @Published var errorMessage: String?
    @Published var showingError: Bool = false
    
    private let aiCoachService: AICoachServiceProtocol
    private let userRepository: UserRepositoryProtocol
    private let workoutRepository: WorkoutRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    init(
        aiCoachService: AICoachServiceProtocol = DependencyContainer.shared.aiCoachService,
        userRepository: UserRepositoryProtocol = DependencyContainer.shared.userRepository,
        workoutRepository: WorkoutRepositoryProtocol = DependencyContainer.shared.workoutRepository
    ) {
        self.aiCoachService = aiCoachService
        self.userRepository = userRepository
        self.workoutRepository = workoutRepository
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func startConversation() {
        Task {
            do {
                let currentUser = try await userRepository.getCurrentUser()
                try await aiCoachService.startConversation(with: currentUser)
                
                // Add welcome message
                if let response = aiCoachService.lastResponse {
                    let welcomeMessage = ChatMessage(
                        id: UUID().uuidString,
                        content: response.message,
                        isFromUser: false,
                        timestamp: Date(),
                        type: .welcome
                    )
                    messages.append(welcomeMessage)
                }
            } catch {
                await handleError(error)
            }
        }
    }
    
    func sendMessage(_ text: String) async {
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            content: text,
            isFromUser: true,
            timestamp: Date(),
            type: .userInput
        )
        
        messages.append(userMessage)
        
        do {
            isProcessing = true
            
            let context: AIContext = determineMessageContext(from: text)
            let response = try await aiCoachService.sendMessage(text, context: context)
            
            let aiMessage = ChatMessage(
                id: UUID().uuidString,
                content: response.message,
                isFromUser: false,
                timestamp: Date(),
                type: .aiResponse
            )
            
            messages.append(aiMessage)
            
            // Handle recommendations if any
            if !response.recommendations.isEmpty {
                await handleRecommendations(response.recommendations)
            }
            
        } catch {
            await handleError(error)
        }
        
        isProcessing = false
    }
    
    func generateWorkout() {
        Task {
            do {
                let currentUser = try await userRepository.getCurrentUser()
                
                let context = WorkoutRequestContext(
                    userProfile: currentUser.profile,
                    availableEquipment: currentUser.preferences.availableEquipment,
                    location: currentUser.preferences.preferredLocation,
                    duration: 45,
                    focusAreas: currentUser.profile.goals.map { $0.primaryMuscleGroup },
                    lastWorkout: await getLastWorkout(),
                    recoveryStatus: .ready,
                    energyLevel: .medium
                )
                
                let workout = try await aiCoachService.generateWorkout(context: context)
                
                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: "Here's your personalized workout:\n\n\(formatWorkout(workout))",
                    isFromUser: false,
                    timestamp: Date(),
                    type: .workoutGenerated
                )
                
                messages.append(message)
                
                // Save workout to repository
                try await workoutRepository.saveWorkout(workout)
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func requestNutritionGuidance() {
        Task {
            do {
                let currentUser = try await userRepository.getCurrentUser()
                
                let context = NutritionContext(
                    userProfile: currentUser.profile,
                    mealTiming: .general,
                    workoutIntensity: .moderate,
                    dietaryRestrictions: currentUser.preferences.dietaryRestrictions
                )
                
                let guidance = try await aiCoachService.provideNutritionalGuidance(context: context)
                
                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: "Here are your personalized nutrition tips:\n\n\(formatNutritionGuidance(guidance))",
                    isFromUser: false,
                    timestamp: Date(),
                    timestamp: Date(),
                    type: .nutritionGuidance
                )
                
                messages.append(message)
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func requestProgressReview() {
        Task {
            do {
                let currentUser = try await userRepository.getCurrentUser()
                let recommendations = try await aiCoachService.getPersonalizedRecommendations(for: currentUser)
                
                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: "Here's your progress review:\n\n\(formatRecommendations(recommendations))",
                    isFromUser: false,
                    timestamp: Date(),
                    type: .progressReview
                )
                
                messages.append(message)
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func analyzeForm(image: UIImage, exercise: Exercise?) {
        Task {
            do {
                guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                    throw AICoachError.processingFailed
                }
                
                let exerciseToAnalyze = exercise ?? Exercise.defaultExercise
                let result = try await aiCoachService.analyzeForm(imageData: imageData, exercise: exerciseToAnalyze)
                
                let message = ChatMessage(
                    id: UUID().uuidString,
                    content: "Form Analysis Results:\n\n\(formatFormAnalysis(result))",
                    isFromUser: false,
                    timestamp: Date(),
                    type: .formAnalysis
                )
                
                messages.append(message)
                
            } catch {
                await handleError(error)
            }
        }
    }
    
    func clearChat() {
        messages.removeAll()
        startConversation()
    }
    
    func exportChat() {
        // Implementation for exporting chat
        print("Exporting chat...")
    }
    
    func showSettings() {
        // Implementation for showing settings
        print("Showing settings...")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind to AI Coach Service state changes
        aiCoachService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isProcessing, on: self)
            .store(in: &cancellables)
        
        aiCoachService.$lastResponse
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                if let response = response {
                    self?.handleAIResponse(response)
                }
            }
            .store(in: &cancellables)
    }
    
    private func determineMessageContext(from text: String) -> AIContext {
        let lowercased = text.lowercased()
        
        if lowercased.contains("workout") || lowercased.contains("exercise") {
            return .workoutRequest
        } else if lowercased.contains("form") || lowercased.contains("technique") {
            return .formAnalysis
        } else if lowercased.contains("nutrition") || lowercased.contains("diet") {
            return .nutritionGuidance
        } else if lowercased.contains("progress") || lowercased.contains("stats") {
            return .progressAnalysis
        } else if lowercased.contains("motivation") || lowercased.contains("encourage") {
            return .motivationalSupport
        } else {
            return .generalInquiry
        }
    }
    
    private func handleAIResponse(_ response: AIResponse) {
        // Handle any additional AI response processing
        // This could include updating UI state, showing notifications, etc.
    }
    
    private func handleRecommendations(_ recommendations: [Recommendation]) async {
        // Process recommendations and potentially show them in the UI
        for recommendation in recommendations {
            print("📋 Recommendation: \(recommendation.title) - \(recommendation.description)")
        }
    }
    
    private func getLastWorkout() async -> Workout? {
        do {
            let currentUser = try await userRepository.getCurrentUser()
            let workouts = try await workoutRepository.getWorkouts(for: currentUser.id, limit: 1)
            return workouts.first
        } catch {
            return nil
        }
    }
    
    private func formatWorkout(_ workout: GeneratedWorkout) -> String {
        var formatted = "🏋️ \(workout.name)\n"
        formatted += "⏱️ Duration: \(workout.duration) minutes\n"
        formatted += "🔥 Difficulty: \(workout.difficulty.rawValue)\n"
        formatted += "💪 Focus Areas: \(workout.focusAreas.map { $0.rawValue }.joined(separator: ", "))\n"
        formatted += "🔥 Calories: ~\(workout.calories)\n\n"
        
        if !workout.exercises.isEmpty {
            formatted += "Exercises:\n"
            for (index, exercise) in workout.exercises.enumerated() {
                formatted += "\(index + 1). \(exercise.name)\n"
            }
        }
        
        return formatted
    }
    
    private func formatNutritionGuidance(_ guidance: NutritionGuidance) -> String {
        var formatted = "🥗 Nutrition Guidance\n\n"
        formatted += "Macros:\n"
        formatted += "• Protein: \(guidance.macros.protein)g\n"
        formatted += "• Carbs: \(guidance.macros.carbs)g\n"
        formatted += "• Fats: \(guidance.macros.fats)g\n\n"
        
        if !guidance.mealSuggestions.isEmpty {
            formatted += "Meal Suggestions:\n"
            for suggestion in guidance.mealSuggestions {
                formatted += "• \(suggestion)\n"
            }
        }
        
        return formatted
    }
    
    private func formatRecommendations(_ recommendations: [Recommendation]) -> String {
        var formatted = "📊 Progress Recommendations\n\n"
        
        for recommendation in recommendations {
            formatted += "🎯 \(recommendation.title)\n"
            formatted += "   \(recommendation.description)\n"
            formatted += "   Priority: \(recommendation.priority.rawValue.capitalized)\n\n"
        }
        
        return formatted
    }
    
    private func formatFormAnalysis(_ result: FormAnalysisResult) -> String {
        var formatted = "📸 Form Analysis Results\n\n"
        formatted += "Score: \(result.score)/10\n\n"
        
        if !result.formTips.isEmpty {
            formatted += "Form Tips:\n"
            for tip in result.formTips {
                formatted += "• \(tip.description)\n"
            }
        }
        
        if !result.safetyConcerns.isEmpty {
            formatted += "\n⚠️ Safety Concerns:\n"
            for concern in result.safetyConcerns {
                formatted += "• \(concern)\n"
            }
        }
        
        return formatted
    }
    
    private func handleError(_ error: Error) async {
        errorMessage = error.localizedDescription
        showingError = true
        
        // Add error message to chat
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            content: "Sorry, I encountered an error: \(error.localizedDescription). Please try again.",
            isFromUser: false,
            timestamp: Date(),
            type: .error
        )
        
        messages.append(errorMessage)
    }
}

// MARK: - Supporting Types

struct ChatMessage: Identifiable {
    let id: String
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let type: MessageType
}

enum MessageType {
    case welcome
    case userInput
    case aiResponse
    case workoutGenerated
    case nutritionGuidance
    case progressReview
    case formAnalysis
    case error
}

// MARK: - Dependency Container Extension
extension DependencyContainer {
    static var shared: DependencyContainer {
        // This would typically come from your app's dependency injection container
        // For now, return a placeholder
        fatalError("DependencyContainer.shared not implemented")
    }
}

import Foundation
import Combine
import SwiftUI

// MARK: - View State
enum ViewState {
    case idle
    case loading
    case loaded
    case error(Error)
    case empty
}

// MARK: - Base View Model
class BaseViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var viewState: ViewState = .idle
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        $viewState
            .map { state in
                if case .loading = state {
                    return true
                }
                return false
            }
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        $viewState
            .compactMap { state in
                if case .error(let error) = state {
                    return error.localizedDescription
                }
                return nil
            }
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - State Management
    func setLoading() {
        viewState = .loading
    }
    
    func setLoaded() {
        viewState = .loaded
    }
    
    func setError(_ error: Error) {
        viewState = .error(error)
    }
    
    func setEmpty() {
        viewState = .empty
    }
    
    func resetState() {
        viewState = .idle
        errorMessage = nil
    }
    
    // MARK: - Error Handling
    func handleError(_ error: Error) {
        setError(error)
        logError(error)
    }
    
    private func logError(_ error: Error) {
        #if DEBUG
        print("❌ Error in \(type(of: self)): \(error)")
        #endif
    }
    
    // MARK: - Async Operations
    func performAsyncOperation<T>(
        operation: @escaping () async throws -> T,
        onSuccess: @escaping (T) -> Void,
        onError: @escaping (Error) -> Void = { _ in }
    ) {
        setLoading()
        
        Task {
            do {
                let result = try await operation()
                await MainActor.run {
                    self.setLoaded()
                    onSuccess(result)
                }
            } catch {
                await MainActor.run {
                    self.handleError(error)
                    onError(error)
                }
            }
        }
    }
    
    // MARK: - Memory Management
    deinit {
        cancellables.removeAll()
    }
}

// MARK: - View Model with Input/Output
protocol ViewModelProtocol: ObservableObject {
    associatedtype Input
    associatedtype Output
    
    var input: Input { get }
    var output: Output { get }
    
    func transform(input: Input) -> Output
}

// MARK: - Base View Model with Input/Output
class BaseViewModelWithIO<Input, Output>: BaseViewModel, ViewModelProtocol {
    
    // MARK: - Properties
    let input: Input
    let output: Output
    
    // MARK: - Initialization
    init(input: Input) {
        self.input = input
        self.output = Self.createOutput()
        super.init()
        setupBindings()
    }
    
    // MARK: - Abstract Methods
    static func createOutput() -> Output {
        fatalError("Subclasses must implement createOutput()")
    }
    
    func transform(input: Input) -> Output {
        fatalError("Subclasses must implement transform(input:)")
    }
    
    // MARK: - Setup
    override func setupBindings() {
        super.setupBindings()
        
        // Transform input to output
        let transformedOutput = transform(input: input)
        
        // Apply transformations to output properties
        applyTransformations(transformedOutput)
    }
    
    private func applyTransformations(_ transformedOutput: Output) {
        // This will be overridden by subclasses to apply specific transformations
    }
}

// MARK: - View Model with Coordinator
protocol CoordinatorViewModel: ObservableObject {
    var coordinator: Coordinator? { get set }
    
    func setCoordinator(_ coordinator: Coordinator)
}

extension CoordinatorViewModel {
    func setCoordinator(_ coordinator: Coordinator) {
        self.coordinator = coordinator
    }
}

// MARK: - View Model with Repository
protocol RepositoryViewModel: ObservableObject {
    associatedtype Repository
    
    var repository: Repository { get }
    
    init(repository: Repository)
}

// MARK: - Error Types
enum ViewModelError: LocalizedError {
    case networkError(String)
    case dataError(String)
    case validationError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .dataError(let message):
            return "Data Error: \(message)"
        case .validationError(let message):
            return "Validation Error: \(message)"
        case .unknownError(let message):
            return "Unknown Error: \(message)"
        }
    }
}

// MARK: - Loading State
enum LoadingState {
    case idle
    case loading
    case success
    case failure(Error)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isFailure: Bool {
        if case .failure = self {
            return true
        }
        return false
    }
    
    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

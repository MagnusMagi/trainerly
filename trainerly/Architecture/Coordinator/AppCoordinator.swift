import SwiftUI
import Combine

// MARK: - Coordinator Protocol
protocol Coordinator: ObservableObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController? { get set }
    
    func start()
    func finish()
}

extension Coordinator {
    func store(coordinator: Coordinator) {
        childCoordinators.append(coordinator)
    }
    
    func free(coordinator: Coordinator) {
        childCoordinators = childCoordinators.filter { $0 !== coordinator }
    }
}

// MARK: - Main App Coordinator
final class AppCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Start with main tab coordinator
        let mainTabCoordinator = MainTabCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: mainTabCoordinator)
        mainTabCoordinator.start()
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

// MARK: - Main Tab Coordinator
final class MainTabCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Create main tab view with coordinators for each tab
        let mainTabView = MainTabView(coordinator: self)
        
        // Present the main tab view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = UIHostingController(rootView: mainTabView)
            window.makeKeyAndVisible()
        }
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
    
    // MARK: - Tab Coordinators
    func createHomeCoordinator() -> HomeCoordinator {
        let coordinator = HomeCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: coordinator)
        return coordinator
    }
    
    func createWorkoutsCoordinator() -> WorkoutsCoordinator {
        let coordinator = WorkoutsCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: coordinator)
        return coordinator
    }
    
    func createProgressCoordinator() -> ProgressCoordinator {
        let coordinator = ProgressCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: coordinator)
        return coordinator
    }
    
    func createSocialCoordinator() -> SocialCoordinator {
        let coordinator = SocialCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: coordinator)
        return coordinator
    }
    
    func createProfileCoordinator() -> ProfileCoordinator {
        let coordinator = ProfileCoordinator(dependencyContainer: dependencyContainer)
        store(coordinator: coordinator)
        return coordinator
    }
}

// MARK: - Individual Tab Coordinators
final class HomeCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Home coordinator logic
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

final class WorkoutsCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Workouts coordinator logic
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

final class ProgressCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Progress coordinator logic
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

final class SocialCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Social coordinator logic
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

final class ProfileCoordinator: Coordinator {
    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController?
    
    private let dependencyContainer: DependencyContainer
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        // Profile coordinator logic
    }
    
    func finish() {
        childCoordinators.forEach { $0.finish() }
        childCoordinators.removeAll()
    }
}

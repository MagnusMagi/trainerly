import Foundation
import Combine

// MARK: - Dependency Container Protocol
protocol DependencyContainer {
    // Core Services
    var networkService: NetworkServiceProtocol { get }
    var healthKitManager: HealthKitManagerProtocol { get }
    var aiCoachService: AICoachServiceProtocol { get }
    var supabaseClient: SupabaseClientProtocol { get }
    var workoutRepository: WorkoutRepositoryProtocol { get }
    var userRepository: UserRepositoryProtocol { get }
    
    // Feature Services
    var formAnalysisService: FormAnalysisServiceProtocol { get }
    var gamificationService: GamificationServiceProtocol { get }
    var paymentService: PaymentServiceProtocol { get }
    var notificationService: NotificationServiceProtocol { get }
    
    // Utilities
    var analyticsService: AnalyticsServiceProtocol { get }
    var storageService: StorageServiceProtocol { get }
    var cacheService: CacheServiceProtocol { get }
}

// MARK: - Main Dependency Container
final class MainDependencyContainer: DependencyContainer {
    
    // MARK: - Core Services
    lazy var networkService: NetworkServiceProtocol = {
        NetworkService()
    }()
    
    lazy var healthKitManager: HealthKitManagerProtocol = {
        HealthKitManager()
    }()
    
    lazy var aiCoachService: AICoachServiceProtocol = {
        AICoachService(
            openAIService: openAIService,
            geminiService: geminiService
        )
    }()
    
    lazy var supabaseClient: SupabaseClientProtocol = {
        SupabaseClient()
    }()
    
    lazy var workoutRepository: WorkoutRepositoryProtocol = {
        WorkoutRepository(
            localDataSource: workoutLocalDataSource,
            remoteDataSource: workoutRemoteDataSource,
            syncManager: workoutSyncManager
        )
    }()
    
    lazy var userRepository: UserRepositoryProtocol = {
        UserRepository(
            localDataSource: userLocalDataSource,
            remoteDataSource: userRemoteDataSource,
            authService: authService
        )
    }()
    
    // MARK: - Feature Services
    lazy var formAnalysisService: FormAnalysisServiceProtocol = {
        FormAnalysisService(
            visionProcessor: visionProcessor,
            geminiService: geminiService
        )
    }()
    
    lazy var gamificationService: GamificationServiceProtocol = {
        GamificationService(
            userRepository: userRepository,
            workoutRepository: workoutRepository
        )
    }()
    
    lazy var paymentService: PaymentServiceProtocol = {
        PaymentService(
            stripeService: stripeService,
            subscriptionManager: subscriptionManager
        )
    }()
    
    lazy var notificationService: NotificationServiceProtocol = {
        NotificationService(
            pushNotificationService: pushNotificationService,
            localNotificationService: localNotificationService
        )
    }()
    
    // MARK: - Utility Services
    lazy var analyticsService: AnalyticsServiceProtocol = {
        AnalyticsService(
            firebaseService: firebaseService,
            mixpanelService: mixpanelService
        )
    }()
    
    lazy var storageService: StorageServiceProtocol = {
        StorageService(
            supabaseStorage: supabaseStorage,
            localStorage: localStorage
        )
    }()
    
    lazy var cacheService: CacheServiceProtocol = {
        CacheService(
            memoryCache: memoryCache,
            diskCache: diskCache
        )
    }()
    
    // MARK: - Private Dependencies
    private lazy var openAIService: OpenAIServiceProtocol = {
        OpenAIService(networkService: networkService)
    }()
    
    private lazy var geminiService: GeminiServiceProtocol = {
        GeminiService(networkService: networkService)
    }()
    
    private lazy var workoutLocalDataSource: WorkoutLocalDataSourceProtocol = {
        WorkoutLocalDataSource(coreDataStack: coreDataStack)
    }()
    
    private lazy var workoutRemoteDataSource: WorkoutRemoteDataSourceProtocol = {
        WorkoutRemoteDataSource(supabaseClient: supabaseClient)
    }()
    
    private lazy var workoutSyncManager: WorkoutSyncManagerProtocol = {
        WorkoutSyncManager(
            localDataSource: workoutLocalDataSource,
            remoteDataSource: workoutRemoteDataSource,
            networkMonitor: networkMonitor
        )
    }()
    
    private lazy var userLocalDataSource: UserLocalDataSourceProtocol = {
        UserLocalDataSource(coreDataStack: coreDataStack)
    }()
    
    private lazy var userRemoteDataSource: UserRemoteDataSourceProtocol = {
        UserRemoteDataSource(supabaseClient: supabaseClient)
    }()
    
    private lazy var authService: AuthServiceProtocol = {
        AuthService(supabaseClient: supabaseClient)
    }()
    
    private lazy var visionProcessor: VisionProcessorProtocol = {
        VisionProcessor()
    }()
    
    private lazy var stripeService: StripeServiceProtocol = {
        StripeService()
    }()
    
    private lazy var subscriptionManager: SubscriptionManagerProtocol = {
        SubscriptionManager(
            stripeService: stripeService,
            userRepository: userRepository
        )
    }()
    
    private lazy var pushNotificationService: PushNotificationServiceProtocol = {
        PushNotificationService()
    }()
    
    private lazy var localNotificationService: LocalNotificationServiceProtocol = {
        LocalNotificationService()
    }()
    
    private lazy var firebaseService: FirebaseServiceProtocol = {
        FirebaseService()
    }()
    
    private lazy var mixpanelService: MixpanelServiceProtocol = {
        MixpanelService()
    }()
    
    private lazy var supabaseStorage: SupabaseStorageProtocol = {
        SupabaseStorage(supabaseClient: supabaseClient)
    }()
    
    private lazy var localStorage: LocalStorageProtocol = {
        LocalStorage()
    }()
    
    private lazy var memoryCache: MemoryCacheProtocol = {
        MemoryCache()
    }()
    
    private lazy var diskCache: DiskCacheProtocol = {
        DiskCache()
    }()
    
    private lazy var coreDataStack: CoreDataStackProtocol = {
        CoreDataStack()
    }()
    
    private lazy var networkMonitor: NetworkMonitorProtocol = {
        NetworkMonitor()
    }()
    
    // MARK: - Initialization
    init() {
        // Configure services that need initialization
        setupServices()
    }
    
    private func setupServices() {
        // Initialize services that need setup
        healthKitManager.requestAuthorization()
        notificationService.requestPermissions()
        analyticsService.configure()
    }
}

// MARK: - Service Protocols (Placeholders - will be implemented next)
protocol NetworkServiceProtocol {}
protocol HealthKitManagerProtocol {}
protocol AICoachServiceProtocol {}
protocol SupabaseClientProtocol {}
protocol WorkoutRepositoryProtocol {}
protocol UserRepositoryProtocol {}
protocol FormAnalysisServiceProtocol {}
protocol GamificationServiceProtocol {}
protocol PaymentServiceProtocol {}
protocol NotificationServiceProtocol {}
protocol AnalyticsServiceProtocol {}
protocol StorageServiceProtocol {}
protocol CacheServiceProtocol {}

// Additional protocols for private dependencies
protocol OpenAIServiceProtocol {}
protocol GeminiServiceProtocol {}
protocol WorkoutLocalDataSourceProtocol {}
protocol WorkoutRemoteDataSourceProtocol {}
protocol WorkoutSyncManagerProtocol {}
protocol UserLocalDataSourceProtocol {}
protocol UserRemoteDataSourceProtocol {}
protocol AuthServiceProtocol {}
protocol VisionProcessorProtocol {}
protocol StripeServiceProtocol {}
protocol SubscriptionManagerProtocol {}
protocol PushNotificationServiceProtocol {}
protocol LocalNotificationServiceProtocol {}
protocol FirebaseServiceProtocol {}
protocol MixpanelServiceProtocol {}
protocol SupabaseStorageProtocol {}
protocol LocalStorageProtocol {}
protocol MemoryCacheProtocol {}
protocol DiskCacheProtocol {}
protocol CoreDataStackProtocol {}
protocol NetworkMonitorProtocol {}

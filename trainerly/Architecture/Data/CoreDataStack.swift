import Foundation
import CoreData
import Combine

// MARK: - Core Data Stack Protocol
protocol CoreDataStackProtocol {
    var persistentContainer: NSPersistentContainer { get }
    var viewContext: NSManagedObjectContext { get }
    var backgroundContext: NSManagedObjectContext { get }
    
    func saveContext()
    func saveBackgroundContext()
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T
}

// MARK: - Core Data Stack
final class CoreDataStack: CoreDataStackProtocol {
    
    // MARK: - Properties
    static let shared = CoreDataStack()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TrainerlyDataModel")
        
        // Configure persistent store
        let storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSSQLiteStoreType
        storeDescription.shouldMigrateStoreAutomatically = true
        storeDescription.shouldInferMappingModelAutomatically = true
        
        // Enable CloudKit sync if available
        if #available(iOS 13.0, *) {
            storeDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.trainerly.app"
            )
        }
        
        container.persistentStoreDescriptions = [storeDescription]
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error {
                fatalError("❌ Core Data failed to load: \(error)")
            }
            
            // Configure contexts
            self?.configureContexts()
        }
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    var backgroundContext: NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    // MARK: - Initialization
    private init() {
        // Private initializer for singleton
    }
    
    // MARK: - Context Configuration
    private func configureContexts() {
        viewContext.automaticallyMergesChangesFromParent = true
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable undo support for development
        #if DEBUG
        viewContext.undoManager = UndoManager()
        #endif
    }
    
    // MARK: - Context Management
    func saveContext() {
        let context = viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("❌ Core Data save error: \(nsError), \(nsError.userInfo)")
        }
    }
    
    func saveBackgroundContext() {
        let context = backgroundContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("❌ Core Data background save error: \(nsError), \(nsError.userInfo)")
        }
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Batch Operations
    func performBatchDelete<T: NSManagedObject>(_ request: NSFetchRequest<T>) async throws -> Int {
        return try await performBackgroundTask { context in
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            deleteRequest.resultType = .resultTypeCount
            
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            return result?.result as? Int ?? 0
        }
    }
    
    func performBatchInsert<T: NSManagedObject>(_ objects: [T]) async throws {
        try await performBackgroundTask { context in
            for object in objects {
                context.insert(object)
            }
            try context.save()
        }
    }
    
    // MARK: - Context Observers
    func addContextObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        viewContext.addObserver(observer, forKeyPath: keyPath, options: [.new, .old], context: nil)
    }
    
    func removeContextObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        viewContext.removeObserver(observer, forKeyPath: keyPath)
    }
    
    // MARK: - Migration Support
    func migrateStoreIfNeeded() {
        // Check if migration is needed
        guard let sourceModel = NSManagedObjectModel.mergedModel(from: [Bundle.main]) else {
            print("❌ Could not create source model for migration")
            return
        }
        
        let destinationModel = persistentContainer.managedObjectModel
        
        guard sourceModel.isCompatible(with: destinationModel) else {
            print("⚠️ Store migration needed")
            performMigration(from: sourceModel, to: destinationModel)
        }
    }
    
    private func performMigration(from sourceModel: NSManagedObjectModel, to destinationModel: NSManagedObjectModel) {
        // Implement custom migration logic if needed
        print("🔄 Performing Core Data migration...")
    }
    
    // MARK: - Debug Helpers
    #if DEBUG
    func printStoreStatistics() {
        let context = viewContext
        
        // Count entities
        let workoutCount = try? context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Workout"))
        let userCount = try? context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "User"))
        let exerciseCount = try? context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: "Exercise"))
        
        print("📊 Core Data Statistics:")
        print("   Workouts: \(workoutCount ?? 0)")
        print("   Users: \(userCount ?? 0)")
        print("   Exercises: \(exerciseCount ?? 0)")
    }
    
    func clearAllData() {
        let context = viewContext
        
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                print("🗑️ Cleared all \(entityName) data")
            } catch {
                print("❌ Failed to clear \(entityName) data: \(error)")
            }
        }
        
        saveContext()
    }
    #endif
}

// MARK: - Core Data Context Extensions
extension NSManagedObjectContext {
    
    func saveIfNeeded() {
        guard hasChanges else { return }
        
        do {
            try save()
        } catch {
            print("❌ Context save error: \(error)")
        }
    }
    
    func deleteAll<T: NSManagedObject>(_ entityType: T.Type) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entityType))
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        try execute(deleteRequest)
    }
    
    func fetch<T: NSManagedObject>(_ entityType: T.Type, predicate: NSPredicate? = nil, sortDescriptors: [NSSortDescriptor]? = nil) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        return try fetch(request)
    }
    
    func fetchFirst<T: NSManagedObject>(_ entityType: T.Type, predicate: NSPredicate? = nil) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: entityType))
        request.predicate = predicate
        request.fetchLimit = 1
        
        return try fetch(request).first
    }
}

// MARK: - Core Data Error Types
enum CoreDataError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case migrationFailed(Error)
    case invalidEntity(String)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete data: \(error.localizedDescription)"
        case .migrationFailed(let error):
            return "Failed to migrate data: \(error.localizedDescription)"
        case .invalidEntity(let entityName):
            return "Invalid entity: \(entityName)"
        }
    }
}

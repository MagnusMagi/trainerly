//
//  trainerlyApp.swift
//  trainerly
//
//  Created by Magnus Magi on 27.08.2025.
//

import SwiftUI

@main
struct trainerlyApp: App {
    
    // MARK: - Properties
    @StateObject private var dependencyContainer = MainDependencyContainer()
    @StateObject private var appCoordinator: AppCoordinator
    
    // MARK: - Initialization
    init() {
        let container = MainDependencyContainer()
        self._dependencyContainer = StateObject(wrappedValue: container)
        self._appCoordinator = StateObject(wrappedValue: AppCoordinator(dependencyContainer: container))
    }
    
    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dependencyContainer)
                .environmentObject(appCoordinator)
                .onAppear {
                    // Start the app coordinator
                    appCoordinator.start()
                }
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        // The coordinator will handle the main view presentation
        // This is just a placeholder until the coordinator takes over
        VStack {
            Text("Trainerly")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Loading...")
                .foregroundColor(.secondary)
        }
        .onAppear {
            // The coordinator should have already started and presented the main view
            // This is just a fallback
        }
    }
}

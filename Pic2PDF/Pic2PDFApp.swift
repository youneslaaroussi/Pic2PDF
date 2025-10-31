//
//  Pic2PDFApp.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import SwiftUI
import SwiftData

@main
struct Pic2PDFApp: App {
    @StateObject private var appState = AppState.shared
    @StateObject private var storageManager = StorageManager.shared
    
    var body: some Scene {
        WindowGroup {
            Group {
                if appState.showOnboarding {
                    OnboardingView()
                        .environmentObject(appState)
                } else {
                    ContentView()
                        .environmentObject(storageManager)
                        .environmentObject(appState)
                        .modelContainer(storageManager.modelContainer)
                }
            }
        }
    }
}

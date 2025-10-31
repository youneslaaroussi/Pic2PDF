//
//  AppState.swift
//  Pic2PDF
//
//  Created for Arm AI Developer Challenge 2025
//

import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var showOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(!showOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    private init() {
        self.showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func restartOnboarding() {
        showOnboarding = true
    }
    
    func completeOnboarding() {
        showOnboarding = false
    }
}


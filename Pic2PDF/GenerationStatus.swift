//
//  GenerationStatus.swift
//  Pic2PDF
//
//  Created for tracking PDF generation progress
//

import Foundation
import Combine

@MainActor
class GenerationStatus: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var statusMessage: String = "Starting..."
}


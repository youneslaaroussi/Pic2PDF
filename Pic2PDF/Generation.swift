//
//  Generation.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import Foundation
import SwiftData
import UIKit

@Model
final class Generation {
    var id: UUID
    var timestamp: Date
    var imageCount: Int
    var latex: String
    var pdfData: Data?
    var imageDataArray: [Data]
    var title: String?
    var isFavorite: Bool
    var refinementHistory: [RefinementEntry]
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        imageCount: Int,
        latex: String,
        pdfData: Data? = nil,
        imageDataArray: [Data],
        title: String? = nil,
        isFavorite: Bool = false,
        refinementHistory: [RefinementEntry] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.imageCount = imageCount
        self.latex = latex
        self.pdfData = pdfData
        self.imageDataArray = imageDataArray
        self.title = title
        self.isFavorite = isFavorite
        self.refinementHistory = refinementHistory
    }
    
    // Helper to get images from data
    func getImages() -> [UIImage] {
        imageDataArray.compactMap { UIImage(data: $0) }
    }
    
    // Helper to create title from timestamp
    var displayTitle: String {
        title ?? "PDF from \(timestamp.formatted(date: .abbreviated, time: .shortened))"
    }
}

// Model for refinement history
@Model
final class RefinementEntry {
    var timestamp: Date
    var feedback: String
    var previousLaTeX: String
    
    init(timestamp: Date = Date(), feedback: String, previousLaTeX: String) {
        self.timestamp = timestamp
        self.feedback = feedback
        self.previousLaTeX = previousLaTeX
    }
}


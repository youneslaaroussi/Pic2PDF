//
//  StorageManager.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import Foundation
import SwiftData
import UIKit
import PDFKit
import Combine

@MainActor
class StorageManager: ObservableObject {
    static let shared = StorageManager()
    
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    @Published var generations: [Generation] = []
    @Published var favoriteGenerations: [Generation] = []
    
    private init() {
        do {
            let schema = Schema([
                Generation.self,
                RefinementEntry.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            modelContext = ModelContext(modelContainer)
            
            print("[Storage] StorageManager initialized successfully")
            
            // Load initial data
            Task {
                await loadGenerations()
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Save Generation
    
    func saveGeneration(
        images: [UIImage],
        latex: String,
        pdfDocument: PDFDocument?,
        title: String? = nil
    ) throws {
        print("[Storage] Saving new generation")
        
        // Convert images to data
        let imageDataArray = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        
        // Convert PDF to data
        let pdfData = pdfDocument?.dataRepresentation()
        
        let generation = Generation(
            imageCount: images.count,
            latex: latex,
            pdfData: pdfData,
            imageDataArray: imageDataArray,
            title: title
        )
        
        modelContext.insert(generation)
        
        do {
            try modelContext.save()
            print("[Storage] Generation saved successfully")
            
            // Reload generations
            Task {
                await loadGenerations()
            }
        } catch {
            print("[Storage] ERROR: Failed to save generation: \(error)")
            throw error
        }
    }
    
    // MARK: - Load Generations
    
    func loadGenerations() async {
        print("[Storage] Loading generations")
        
        let descriptor = FetchDescriptor<Generation>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            generations = try modelContext.fetch(descriptor)
            favoriteGenerations = generations.filter { $0.isFavorite }
            print("[Storage] Loaded \(generations.count) generations")
        } catch {
            print("[Storage] ERROR: Failed to load generations: \(error)")
            generations = []
            favoriteGenerations = []
        }
    }
    
    // MARK: - Update Generation
    
    func updateGeneration(_ generation: Generation) throws {
        print("[Storage] Updating generation")
        
        do {
            try modelContext.save()
            print("[Storage] Generation updated successfully")
            
            Task {
                await loadGenerations()
            }
        } catch {
            print("[Storage] ERROR: Failed to update generation: \(error)")
            throw error
        }
    }
    
    // MARK: - Delete Generation
    
    func deleteGeneration(_ generation: Generation) throws {
        print("[Storage] Deleting generation")
        
        modelContext.delete(generation)
        
        do {
            try modelContext.save()
            print("[Storage] Generation deleted successfully")
            
            Task {
                await loadGenerations()
            }
        } catch {
            print("[Storage] ERROR: Failed to delete generation: \(error)")
            throw error
        }
    }
    
    // MARK: - Toggle Favorite
    
    func toggleFavorite(_ generation: Generation) throws {
        generation.isFavorite.toggle()
        try updateGeneration(generation)
    }
    
    // MARK: - Add Refinement
    
    func addRefinement(to generation: Generation, feedback: String, previousLaTeX: String) throws {
        let refinement = RefinementEntry(
            feedback: feedback,
            previousLaTeX: previousLaTeX
        )
        
        generation.refinementHistory.append(refinement)
        generation.latex = previousLaTeX // This will be updated with new LaTeX after refinement
        
        try updateGeneration(generation)
    }
    
    // MARK: - Search Generations
    
    func searchGenerations(query: String) -> [Generation] {
        if query.isEmpty {
            return generations
        }
        
        return generations.filter { generation in
            generation.displayTitle.localizedCaseInsensitiveContains(query) ||
            generation.latex.localizedCaseInsensitiveContains(query)
        }
    }
    
    // MARK: - Get Statistics
    
    func getStatistics() -> StorageStatistics {
        let totalGenerations = generations.count
        let totalFavorites = favoriteGenerations.count
        let totalImages = generations.reduce(0) { $0 + $1.imageCount }
        
        let totalSize = generations.reduce(0) { total, gen in
            let imageSize = gen.imageDataArray.reduce(0) { $0 + $1.count }
            let pdfSize = gen.pdfData?.count ?? 0
            return total + imageSize + pdfSize
        }
        
        return StorageStatistics(
            totalGenerations: totalGenerations,
            totalFavorites: totalFavorites,
            totalImages: totalImages,
            totalStorageBytes: totalSize
        )
    }
    
    // MARK: - Clear All Data
    
    func clearAllData() throws {
        print("[Storage] Clearing all data")
        
        for generation in generations {
            modelContext.delete(generation)
        }
        
        do {
            try modelContext.save()
            generations = []
            favoriteGenerations = []
            print("[Storage] All data cleared successfully")
        } catch {
            print("[Storage] ERROR: Failed to clear data: \(error)")
            throw error
        }
    }
}

// MARK: - Statistics Model

struct StorageStatistics {
    let totalGenerations: Int
    let totalFavorites: Int
    let totalImages: Int
    let totalStorageBytes: Int
    
    var totalStorageMB: Double {
        Double(totalStorageBytes) / 1_048_576 // Convert bytes to MB
    }
    
    var formattedStorage: String {
        if totalStorageMB < 1 {
            return String(format: "%.2f KB", Double(totalStorageBytes) / 1024)
        } else {
            return String(format: "%.2f MB", totalStorageMB)
        }
    }
}


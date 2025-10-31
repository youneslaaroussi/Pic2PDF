//
//  HistoryView.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import SwiftUI
import PDFKit
import WebKit

struct HistoryView: View {
    @StateObject private var storageManager = StorageManager.shared
    @State private var searchQuery = ""
    @State private var showFavoritesOnly = false
    @State private var selectedGeneration: Generation?
    @State private var showDeleteAlert = false
    @State private var generationToDelete: Generation?
    @Environment(\.dismiss) var dismiss
    
    var filteredGenerations: [Generation] {
        let gens = showFavoritesOnly ? storageManager.favoriteGenerations : storageManager.generations
        
        if searchQuery.isEmpty {
            return gens
        } else {
            return storageManager.searchGenerations(query: searchQuery)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Statistics Bar
                statisticsBar
                
                // Search and Filter
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search history...", text: $searchQuery)
                            .textFieldStyle(.plain)
                        
                        if !searchQuery.isEmpty {
                            Button(action: { searchQuery = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Toggle(isOn: $showFavoritesOnly) {
                        Label("Favorites Only", systemImage: "star.fill")
                    }
                    .tint(.yellow)
                }
                .padding()
                
                // Generations List
                if filteredGenerations.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredGenerations, id: \.id) { generation in
                                GenerationCard(
                                    generation: generation,
                                    onTap: { selectedGeneration = generation },
                                    onDelete: {
                                        generationToDelete = generation
                                        showDeleteAlert = true
                                    },
                                    onToggleFavorite: {
                                        try? storageManager.toggleFavorite(generation)
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: clearAllData) {
                            Label("Clear All History", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedGeneration) { generation in
                GenerationDetailView(generation: generation)
            }
            .alert("Delete Generation", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let gen = generationToDelete {
                        try? storageManager.deleteGeneration(gen)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this generation? This action cannot be undone.")
            }
        }
    }
    
    private var statisticsBar: some View {
        let stats = storageManager.getStatistics()
        
        return HStack(spacing: 20) {
            StatItem(icon: "doc.on.doc", value: "\(stats.totalGenerations)", label: "Docs")
            StatItem(icon: "photo.stack", value: "\(stats.totalImages)", label: "Images")
            StatItem(icon: "star.fill", value: "\(stats.totalFavorites)", label: "Favorites")
            StatItem(icon: "externaldrive", value: stats.formattedStorage, label: "Storage")
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: showFavoritesOnly ? "star.slash" : "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text(showFavoritesOnly ? "No favorites yet" : "No history yet")
                .font(.headline)
            
            Text(showFavoritesOnly ? "Star your favorite generations to see them here" : "Your PDF generations will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func clearAllData() {
        try? storageManager.clearAllData()
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GenerationCard: View {
    let generation: Generation
    let onTap: () -> Void
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(generation.displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(generation.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: onToggleFavorite) {
                        Image(systemName: generation.isFavorite ? "star.fill" : "star")
                            .foregroundColor(generation.isFavorite ? .yellow : .gray)
                    }
                    .buttonStyle(.plain)
                }
                
                // Preview images
                if !generation.imageDataArray.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<min(generation.imageDataArray.count, 5), id: \.self) { index in
                                if let image = UIImage(data: generation.imageDataArray[index]) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 80)
                                        .clipped()
                                        .cornerRadius(8)
                                }
                            }
                            
                            if generation.imageCount > 5 {
                                Text("+\(generation.imageCount - 5)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, height: 80)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                HStack {
                    Label("\(generation.imageCount) images", systemImage: "photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if !generation.refinementHistory.isEmpty {
                        Label("\(generation.refinementHistory.count) refinements", systemImage: "pencil")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct GenerationDetailView: View {
    let generation: Generation
    @Environment(\.dismiss) var dismiss
    @State private var webView: WKWebView?
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Live LaTeX Render
                    LaTeXWebView(latex: generation.latex) { view in
                        webView = view
                    }
                    .frame(height: 400)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 16) {
                        HistoryInfoRow(label: "Created", value: generation.timestamp.formatted(date: .long, time: .shortened))
                        HistoryInfoRow(label: "Images", value: "\(generation.imageCount)")
                        
                        if !generation.refinementHistory.isEmpty {
                            HistoryInfoRow(label: "Refinements", value: "\(generation.refinementHistory.count)")
                        }
                        
                        Divider()
                        
                        // Source Images
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Source Images")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(generation.getImages(), id: \.self) { image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 160)
                                            .clipped()
                                            .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // LaTeX Source
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LaTeX Source")
                                .font(.headline)
                            
                            ScrollView {
                                Text(generation.latex)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .frame(height: 200)
                        }
                        
                        // Refinement History
                        if !generation.refinementHistory.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Refinement History")
                                    .font(.headline)
                                
                                ForEach(generation.refinementHistory.indices, id: \.self) { index in
                                    let refinement = generation.refinementHistory[index]
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Refinement \(index + 1)")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text(refinement.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        
                                        Text(refinement.feedback)
                                            .font(.caption)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .padding()
            }
            .navigationTitle(generation.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: shareAsPDF) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let shareURL = shareURL {
                    ShareSheet(items: [shareURL])
                }
            }
        }
    }
    
    private func shareAsPDF() {
        guard let webView = webView else { return }
        webView.exportPDF { result in
            switch result {
            case .success(let data):
                let fileName = "Pic2PDF_\(Date().timeIntervalSince1970).pdf"
                let temporaryURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                do {
                    try data.write(to: temporaryURL)
                    DispatchQueue.main.async {
                        shareURL = temporaryURL
                        showShareSheet = true
                    }
                } catch {
                    print("[History] Share write failed: \(error)")
                }
            case .failure(let error):
                print("[History] Export failed: \(error)")
            }
        }
    }
}

struct HistoryInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HistoryView()
}


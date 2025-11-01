//
//  ContentView.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import SwiftUI
import PhotosUI
import PDFKit
import Combine

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var mainGenerationViewModel = MainGenerationViewModel()
    @StateObject private var llmService = OnDeviceLLMService.shared

    var body: some View {
        ZStack {
            // Main Tab View
            TabView(selection: $selectedTab) {
                // Main PDF Generation Tab
                MainGenerationView(viewModel: mainGenerationViewModel)
                    .tabItem {
                        Label("Generate", systemImage: "doc.badge.plus")
                    }
                    .tag(0)

                // History Tab
                NavigationView { HistoryView() }
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(1)

                // Stats & Analytics Tab
                StatsView()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar.fill")
                    }
                    .tag(2)
                
                // Settings Tab
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(3)
            }
            
            // Full-screen generation overlay (hides tabs)
            if mainGenerationViewModel.isGenerating {
                GenerationOverlayView(
                    status: mainGenerationViewModel.generationStatus
                )
                .transition(.opacity)
                .zIndex(999)
            }
            
            // Model loading overlay (fades screen until model is ready)
            if !llmService.isInitialized && llmService.initializationError == nil {
                ModelLoadingOverlay(llmService: llmService)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: mainGenerationViewModel.isGenerating)
        .animation(.easeInOut(duration: 0.5), value: llmService.isInitialized)
    }
}

// View model to share state between ContentView and MainGenerationView
@MainActor
class MainGenerationViewModel: ObservableObject {
    @Published var isGenerating = false
    @Published var generationStatus = GenerationStatus()
    var currentTask: Task<Void, Never>?
    
    func stopGeneration() {
        // Cancel the task and update state
        currentTask?.cancel()
        isGenerating = false
    }
}

// MARK: - Main Generation View (Original ContentView functionality)
struct MainGenerationView: View {
    @ObservedObject var viewModel: MainGenerationViewModel
    
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    // No auto-generated PDF; render LaTeX in WebView on demand
    @State private var currentLaTeX: String = ""
    @State private var errorMessage: String?
    @State private var showRefinementSheet = false
    @State private var refinementFeedback = ""
    @State private var showCamera = false
    @State private var currentTask: Task<Void, Never>?
    @State private var showSaveSuccess = false
    @State private var showEditorView = false

    @StateObject private var onDeviceLLMService = OnDeviceLLMService.shared

    @EnvironmentObject var storageManager: StorageManager

    // Renderer not needed for auto-PDF; PDF is created from WebView on save/share
    
    // Use viewModel's isGenerating and generationStatus
    private var isGenerating: Bool {
        viewModel.isGenerating
    }
    
    private var generationStatus: GenerationStatus {
        viewModel.generationStatus
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Note: PDF compilation is now done locally using WebView + LaTeX.js
                // AI Model loading is handled by overlay in ContentView
                
                if selectedImages.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Select photos to convert to PDF")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !isGenerating {
                    // Generation moved to overlay, so just show image preview when not generating
                    // Selected images preview
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                            ForEach(0..<selectedImages.count, id: \.self) { index in
                                Image(uiImage: selectedImages[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                        .padding()
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                // Action buttons
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        PhotosPicker(
                            selection: $selectedItems,
                            maxSelectionCount: 10,
                            matching: .images
                        ) {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 28, weight: .medium))
                                Text("Select Photos")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            Task {
                                await loadImages(from: newItems)
                            }
                        }
                        .disabled(isGenerating)
                        
                        Button(action: { showCamera = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 28, weight: .medium))
                                Text("Take Photo")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(16)
                        }
                        .disabled(isGenerating)
                    }
                    
                    if !selectedImages.isEmpty {
                        if isGenerating {
                            Button(action: stopGeneration) {
                                HStack(spacing: 10) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Stop Generation")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .foregroundColor(.red)
                                .cornerRadius(16)
                            }
                        } else {
                            Button(action: generateLaTeX) {
                                HStack(spacing: 10) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .semibold))
                                    Text("Generate")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemGray6))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                            }
                        }
                    }
                }
                .padding()
                
                // Navigation to LaTeX preview with actions (no auto-PDF)
                NavigationLink(destination: LaTeXPreviewWithActionsView(
                    currentLaTeX: $currentLaTeX,
                    selectedImages: selectedImages,
                    onRefinement: { feedback in
                        showEditorView = false
                        refinementFeedback = feedback
                        refineLaTeX()
                    },
                    onStartOver: {
                        showEditorView = false
                        reset()
                    }
                ), isActive: $showEditorView) {
                    EmptyView()
                }
            }
            .navigationTitle("Pic2PDF")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showRefinementSheet) {
                RefinementView(
                    feedback: $refinementFeedback,
                    onSubmit: {
                        showRefinementSheet = false
                        refineLaTeX()
                    }
                )
            }
            .sheet(isPresented: $showCamera) {
                CameraView { image in
                    selectedImages.append(image)
                    showCamera = false
                }
            }
            .overlay(alignment: .top) {
                if showSaveSuccess {
                    SuccessToast(message: "Saved to History")
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(), value: showSaveSuccess)
                }
            }
        }
    }
    
    private func loadImages(from items: [PhotosPickerItem]) async {
        selectedImages.removeAll()
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
            }
        }
    }
    
    private func generateLaTeX() {
        let task = Task {
            await MainActor.run {
                viewModel.isGenerating = true
                errorMessage = nil
            }
            
            do {
                // No additional prompt needed - the base prompt in OnDeviceLLMService is comprehensive
                currentLaTeX = try await onDeviceLLMService.generateLaTeX(from: selectedImages, additionalPrompt: nil, status: generationStatus)
                
                if Task.isCancelled { return }
                
                await MainActor.run {
                    // Auto-save to history
                    do {
                        try StorageManager.shared.saveGeneration(
                            images: selectedImages,
                            latex: currentLaTeX,
                            pdfDocument: nil,
                            title: nil
                        )
                        print("[ContentView] Auto-saved to history")
                    } catch {
                        print("[ContentView] Failed to auto-save: \(error)")
                    }
                    
                    viewModel.isGenerating = false
                    showEditorView = true
                }
            } catch {
                await MainActor.run {
                    // Handle different error types
                    if let onDeviceError = error as? OnDeviceLLMError {
                        // On-device LLM errors
                        errorMessage = onDeviceError.localizedDescription
                    } else {
                        // Generic errors
                        errorMessage = error.localizedDescription
                    }
                    viewModel.isGenerating = false
                }
            }
        }
        currentTask = task
        viewModel.currentTask = task
    }
    
    private func stopGeneration() {
        viewModel.stopGeneration()
        errorMessage = "Generation stopped"
    }
    
    private func refineLaTeX() {
        let task = Task {
            await MainActor.run {
                viewModel.isGenerating = true
                errorMessage = nil
            }
            
            do {
                currentLaTeX = try await onDeviceLLMService.refineLaTeX(
                    currentLaTeX: currentLaTeX,
                    userFeedback: refinementFeedback,
                    status: generationStatus
                )
                
                if Task.isCancelled { return }
                
                await MainActor.run {
                    viewModel.isGenerating = false
                    showEditorView = true
                    refinementFeedback = ""
                }
            } catch {
                await MainActor.run {
                    // Handle different error types for refinement
                    if let onDeviceError = error as? OnDeviceLLMError {
                        errorMessage = onDeviceError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    viewModel.isGenerating = false
                }
            }
        }
        currentTask = task
        viewModel.currentTask = task
    }
    
    // Save/Share now handled inside LaTeXPreviewWithActionsView
    
    private func reset() {
        selectedItems.removeAll()
        selectedImages.removeAll()
        // no stored PDF
        currentLaTeX = ""
        errorMessage = nil
        refinementFeedback = ""
    }
    
    // Saving happens on demand from the preview screen
}

struct Badge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(4)
            .background(Color.red)
            .clipShape(Circle())
    }
}

struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.top, 60)
    }
}

// Model Loading Overlay
struct ModelLoadingOverlay: View {
    @ObservedObject var llmService: OnDeviceLLMService
    
    var body: some View {
        ZStack {
            // Backdrop blur
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "cpu")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text("Loading AI Model")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Initializing Gemma 3N for on-device processing")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    if llmService.modelInitializationTime > 0 {
                        Text("Time: \(String(format: "%.1fs", llmService.modelInitializationTime))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                
                // Feature badges
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                        Text("Private")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        Text("Fast")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    VStack(spacing: 4) {
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text("ARM64")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                Text("First launch may take a moment")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}

struct RefinementView: View {
    @Binding var feedback: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Describe the changes you'd like to make")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $feedback)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding()
                
                Button(action: onSubmit) {
                    Text("Submit Changes")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(feedback.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(feedback.isEmpty)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Suggest Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Full-Screen Generation Overlay
struct GenerationOverlayView: View {
    @ObservedObject var status: GenerationStatus
    @StateObject private var llmService = OnDeviceLLMService.shared
    
    var body: some View {
        ZStack {
            // Background gradient matching app theme
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.1, green: 0.2, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main generation view
                ScrollView {
                    VStack(spacing: 24) {
                        // Title with glow effect
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 120, height: 120)
                                    .blur(radius: 20)
                                
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 60))
                                    .foregroundColor(.white)
                            }
                            
                            Text("AI Generation in Progress")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Powered by Gemma 3N on ARM64")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Real-time metrics while generating
                        HStack(spacing: 16) {
                            MetricMiniCard(
                                icon: "memorychip",
                                value: String(format: "%.0f", llmService.currentMemoryUsage),
                                unit: "MB"
                            )
                            
                            MetricMiniCard(
                                icon: "speedometer",
                                value: String(format: "%.1f", llmService.cpuUsage),
                                unit: "%"
                            )
                            
                            MetricMiniCard(
                                icon: "chart.line.uptrend.xyaxis",
                                value: llmService.currentTokensPerSecond > 0 ? String(format: "%.1f", llmService.currentTokensPerSecond) : "...",
                                unit: "tok/s"
                            )
                        }
                        .padding(.horizontal)
                        
                        // Mini sparkline charts
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                    .foregroundColor(.white.opacity(0.7))
                                Text("RAM Usage")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(llmService.currentMemoryUsage)) MB")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            if !llmService.realtimeMemoryHistory.isEmpty {
                                MiniSparklineView(
                                    values: llmService.realtimeMemoryHistory,
                                    color: .white.opacity(0.5)
                                )
                                .frame(height: 40)
                            } else {
                                // Placeholder when no data yet
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 40)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Streaming LaTeX Code View
                        if !llmService.streamingLaTeX.isEmpty {
                            StreamingLaTeXView(latexCode: llmService.streamingLaTeX)
                                .frame(height: 220)
                                .padding(.horizontal)
                        }
                        
                        // Status message and progress
                        VStack(spacing: 16) {
                            Text(status.statusMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            ProgressView(value: status.progress, total: 1.0)
                                .progressViewStyle(LinearProgressViewStyle())
                                .tint(.white)
                                .scaleEffect(x: 1, y: 2, anchor: .center)
                            
                            Text("\(Int(status.progress * 100))% Complete")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 40)
                        .padding(.bottom, 20)
                        
                        // Info message about stopping generation
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                            Text("To stop generation, quit the app")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
        }
    }
}

struct PollingView: View {
    @ObservedObject var status: GenerationStatus
    @StateObject private var llmService = OnDeviceLLMService.shared

    var body: some View {
        VStack(spacing: 20) {
            // Real-time metrics while generating
            HStack(spacing: 16) {
                MetricMiniCard(
                    icon: "memorychip",
                    value: String(format: "%.0f", llmService.currentMemoryUsage),
                    unit: "MB"
                )
                
                MetricMiniCard(
                    icon: "speedometer",
                    value: String(format: "%.1f", llmService.cpuUsage),
                    unit: "%"
                )
                
                MetricMiniCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: llmService.currentTokensPerSecond > 0 ? String(format: "%.1f", llmService.currentTokensPerSecond) : "...",
                    unit: "tok/s"
                )
            }
            .padding(.horizontal)
            
            // Mini sparkline charts
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .foregroundColor(.green)
                    Text("RAM Usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(llmService.currentMemoryUsage)) MB")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                
                MiniSparklineView(
                    values: llmService.generationHistory.suffix(10).map { $0.memoryUsageMB },
                    color: .green
                )
                .frame(height: 40)
            }
            .padding()
            .background(Color(.systemBackground).opacity(0.5))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Streaming LaTeX Code View
            if !llmService.streamingLaTeX.isEmpty {
                StreamingLaTeXView(latexCode: llmService.streamingLaTeX)
                    .frame(height: 200)
                    .padding(.horizontal)
            }
            
            // Status message and progress
            VStack(spacing: 12) {
                Text(status.statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                ProgressView(value: status.progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(.blue)
            }
            .padding(.horizontal)
        }
    }
}

// Streaming LaTeX code display (last 8 lines)
struct StreamingLaTeXView: View {
    let latexCode: String
    @State private var scrollProxy: ScrollViewProxy?
    
    var displayLines: [String] {
        let allLines = latexCode.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let lastLines = allLines.suffix(8)
        return Array(lastLines)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundColor(.cyan)
                    .font(.caption)
                Text("Live LaTeX Generation")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(latexCode.count) chars")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(displayLines.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(format: "%02d", index + 1))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .frame(width: 20, alignment: .trailing)
                                
                                Text(line.isEmpty ? " " : line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.cyan)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .onChange(of: displayLines.count) { _, _ in
                    // Auto-scroll to bottom when new lines appear
                    if let lastIndex = displayLines.indices.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
    }
}

// Mini metric card for real-time stats
struct MetricMiniCard: View {
    let icon: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// Mini sparkline chart view
struct MiniSparklineView: View {
    let values: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            if values.isEmpty {
                // Empty state
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
            } else {
                let maxValue = values.max() ?? 1.0
                let minValue = values.min() ?? 0.0
                let range = maxValue - minValue
                
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(max(values.count - 1, 1)))
                        let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedValue))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // Fill area under the line
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * (geometry.size.width / CGFloat(max(values.count - 1, 1)))
                        let normalizedValue = range > 0 ? (value - minValue) / range : 0.5
                        let y = geometry.size.height * (1 - CGFloat(normalizedValue))
                        
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: geometry.size.height))
                            path.addLine(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct OnDeviceAIStatusBanner: View {
    @ObservedObject var llmService: OnDeviceLLMService

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                if llmService.initializationError != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(llmService.initializationError != nil ? "AI Model Error" : "Loading AI Model")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let error = llmService.initializationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Initializing Gemma 3N for on-device processing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .background(llmService.initializationError != nil ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}


// MARK: - Model Selection Sheet
struct ModelSelectionSheet: View {
    @ObservedObject var llmService: OnDeviceLLMService
    @ObservedObject var downloadManager: ModelDownloadManager
    @Environment(\.dismiss) var dismiss
    @State private var isSwitching = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(GemmaModelIdentifier.allCases) { modelId in
                        ModelRow(
                            model: modelId,
                            isSelected: modelId == llmService.selectedModel,
                            isDownloaded: downloadManager.isModelDownloaded(modelId),
                            downloadStatus: downloadManager.downloadStatus,
                            isSwitching: isSwitching,
                            onSelect: {
                                Task {
                                    await switchToModel(modelId)
                                }
                            },
                            onDownload: {
                                Task {
                                    await downloadModel(modelId)
                                }
                            }
                        )
                    }
                } header: {
                    Text("Available Models")
                } footer: {
                    Text("Larger models provide better accuracy but require more storage and processing time.")
                        .font(.caption)
                }
            }
            .navigationTitle("Select AI Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func switchToModel(_ modelId: GemmaModelIdentifier) async {
        guard !isSwitching else { return }
        
        // Check if model is downloaded first
        if !downloadManager.isModelDownloaded(modelId) {
            // Need to download first
            return
        }
        
        isSwitching = true
        await llmService.switchModel(to: modelId)
        await MainActor.run {
            isSwitching = false
        }
        
        // Dismiss after successful switch
        await MainActor.run {
            dismiss()
        }
    }
    
    private func downloadModel(_ modelId: GemmaModelIdentifier) async {
        do {
            try await downloadManager.downloadModel(modelId)
            // After download, offer to switch to it
            await switchToModel(modelId)
        } catch {
            print("Download failed: \(error)")
        }
    }
}

// MARK: - Model Row
struct ModelRow: View {
    let model: GemmaModelIdentifier
    let isSelected: Bool
    let isDownloaded: Bool
    let downloadStatus: ModelDownloadStatus
    let isSwitching: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    
    var modelSize: String {
        if let config = DownloadableModelConfig.availableModels[model] {
            let sizeMB = config.expectedSizeMB
            if sizeMB >= 1024 {
                return String(format: "%.1f GB", sizeMB / 1024)
            } else {
                return String(format: "%.0f MB", sizeMB)
            }
        }
        return "Unknown size"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.displayName)
                        .font(.headline)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(modelSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if isDownloaded {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                            Text("Downloaded")
                                .font(.caption2)
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            if isSwitching && isSelected {
                ProgressView()
                    .controlSize(.small)
            } else if !isDownloaded {
                if case .downloading(let progress, _, _) = downloadStatus {
                    VStack(spacing: 4) {
                        ProgressView(value: progress)
                            .frame(width: 60)
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button(action: onDownload) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text("Download")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            } else if !isSelected {
                Button(action: onSelect) {
                    Text("Use")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(StorageManager.shared)
}

//
//  SettingsView.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var storageManager = StorageManager.shared
    @StateObject private var appState = AppState.shared
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @StateObject private var llmService = OnDeviceLLMService.shared
    @AppStorage("performanceModeEnabled") private var performanceModeEnabled = false
    
    // LLM Parameters
    @AppStorage("llmTemperature") private var temperature: Double = 0.7
    @AppStorage("llmTopP") private var topP: Double = 0.9
    @AppStorage("llmTopK") private var topK: Int = 40
    @AppStorage("llmMaxTokens") private var maxTokens: Int = 2000
    
    @State private var showClearDataAlert = false
    @State private var showResetParamsAlert = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Performance Section
                Section {
                    Toggle("Performance Mode", isOn: $performanceModeEnabled)
                        .tint(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimizes for speed on ARM devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("- Downscale images more aggressively\n- Lower max tokens\n- Slightly faster sampling")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                } header: {
                    Text("Performance")
                }
                
                // LLM Parameters Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Temperature
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Temperature")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", temperature))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $temperature, in: 0.1...1.5, step: 0.05)
                                .tint(.blue)
                            Text("Controls randomness. Lower = more focused, Higher = more creative")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Top P
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Top P (Nucleus Sampling)")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.2f", topP))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $topP, in: 0.1...1.0, step: 0.05)
                                .tint(.blue)
                            Text("Limits token choices by cumulative probability. Lower = more focused")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Top K
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Top K")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(topK)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(topK) },
                                set: { topK = Int($0) }
                            ), in: 1...100, step: 1)
                                .tint(.blue)
                            Text("Limits token choices to top K options. Lower = more deterministic")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider()
                        
                        // Max Tokens
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Tokens")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(maxTokens)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(maxTokens) },
                                set: { maxTokens = Int($0) }
                            ), in: 500...4000, step: 100)
                                .tint(.blue)
                            Text("Maximum output length. Higher = longer documents, more memory")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: { showResetParamsAlert = true }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .foregroundColor(.blue)
                    }
                } header: {
                    Text("LLM Parameters")
                } footer: {
                    Text("Advanced settings for AI model behavior. Changes take effect on next generation.")
                }
                
                // Storage Section
                Section {
                    let stats = storageManager.getStatistics()
                    
                    HStack {
                        Text("Total Generations")
                        Spacer()
                        Text("\(stats.totalGenerations)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Images")
                        Spacer()
                        Text("\(stats.totalImages)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Favorites")
                        Spacer()
                        Text("\(stats.totalFavorites)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Storage Used")
                        Spacer()
                        Text(stats.formattedStorage)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Storage")
                }
                
                // AI Model Management Section
                Section {
                    // Model Selector Dropdown
                    Picker("Current Model", selection: Binding(
                        get: { llmService.selectedModel },
                        set: { newModel in
                            Task {
                                await llmService.switchModel(to: newModel)
                            }
                        }
                    )) {
                        ForEach(ModelIdentifier.allCases.filter { downloadManager.isModelDownloaded($0) }) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    
                    // Downloaded Models List
                    ForEach([ModelIdentifier.gemma2B, ModelIdentifier.gemma4B], id: \.self) { model in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.displayName)
                                    .font(.subheadline)
                                
                                if downloadManager.isModelDownloaded(model) {
                                    if let size = downloadManager.modelSize(model) {
                                        Text("\(String(format: "%.1f", size)) MB")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } else {
                                    Text("Not downloaded")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if downloadManager.isModelDownloaded(model) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Button("Download") {
                                    Task {
                                        do {
                                            try await downloadManager.downloadModel(model)
                                        } catch {
                                            print("Failed to download model: \(error)")
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                } header: {
                    Text("AI Models")
                } footer: {
                    Text("Download AI models for on-device processing. Models are stored locally and never uploaded.")
                }
                
                // Data Management Section
                Section {
                    Button(role: .destructive, action: { showClearDataAlert = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("This will permanently delete all saved generations and cannot be undone.")
                }
                
                // Help Section
                Section {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation {
                                appState.restartOnboarding()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: "book.circle")
                                .foregroundColor(.blue)
                            Text("View Onboarding Tutorial")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Help")
                } footer: {
                    Text("Learn about the app's features and how to use it effectively.")
                }
                
                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://github.com/youneslaaroussi/Pic2PDF")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/youneslaaroussi/Pic2PDF/blob/main/PRIVACY.md")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Built for Arm AI Developer Challenge 2025 - Showcasing efficient on-device AI processing with fully local PDF generation.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            // Removed Done button since Settings is now a tab
            .alert("Clear All Data", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("Are you sure you want to delete all saved generations? This action cannot be undone.")
            }
            .alert("Reset LLM Parameters", isPresented: $showResetParamsAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset") {
                    resetLLMParameters()
                }
            } message: {
                Text("Reset all LLM parameters to their default values?")
            }
        }
    }
    
    private func clearAllData() {
        do {
            try storageManager.clearAllData()
        } catch {
            print("[Settings] ERROR: Failed to clear data: \(error)")
        }
    }
    
    private func resetLLMParameters() {
        temperature = 0.7
        topP = 0.9
        topK = 40
        maxTokens = 2000
    }
}

#Preview {
    SettingsView()
}


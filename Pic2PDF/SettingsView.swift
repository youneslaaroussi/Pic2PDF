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
    @State private var showClearDataAlert = false
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
                        ForEach(GemmaModelIdentifier.allCases.filter { downloadManager.isModelDownloaded($0) }) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                    
                    // Downloaded Models List
                    ForEach([GemmaModelIdentifier.gemma2B, GemmaModelIdentifier.gemma4B], id: \.self) { model in
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
                    
                    Link(destination: URL(string: "https://github.com")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("GitHub Repository")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    
                    // Privacy & Terms
                    Link(destination: URL(string: "https://pic2pdf.app/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                        }
                    }
                    Link(destination: URL(string: "https://pic2pdf.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                            Text("Terms of Service")
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
        }
    }
    
    private func clearAllData() {
        do {
            try storageManager.clearAllData()
        } catch {
            print("[Settings] ERROR: Failed to clear data: \(error)")
        }
    }
}

#Preview {
    SettingsView()
}


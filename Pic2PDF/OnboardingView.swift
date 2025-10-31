//
//  OnboardingView.swift
//  Pic2PDF
//
//  Created for Arm AI Developer Challenge 2025
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background gradient - Modern dark theme with blue accent
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.1, blue: 0.2), Color(red: 0.1, green: 0.2, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: completeOnboarding) {
                        Text("Skip")
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding()
                
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    OnDeviceAIPage()
                        .tag(1)
                    
                    ArmOptimizedPage()
                        .tag(2)
                    
                    FeaturesPage()
                        .tag(3)
                    
                    ModelDownloadPage()
                        .tag(4)
                    
                    GetStartedPage(onComplete: completeOnboarding)
                        .tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: { withAnimation { currentPage -= 1 } }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
                    
                    Spacer()
                    
                    if currentPage < 5 {
                        Button(action: { withAnimation { currentPage += 1 } }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .padding()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            appState.completeOnboarding()
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 100))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("Welcome to Pic2PDF")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Convert Photos to Beautiful PDFs\nPowered by On-Device AI")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 12) {
                FeatureBadge(icon: "shield.fill", text: "Private & Secure")
                    .frame(maxWidth: 280)
                FeatureBadge(icon: "bolt.fill", text: "Lightning Fast")
                    .frame(maxWidth: 280)
                FeatureBadge(icon: "cpu", text: "Arm Optimized")
                    .frame(maxWidth: 280)
            }
            .padding(.bottom, 50)
        }
        .padding()
    }
}

// MARK: - On-Device AI Page
struct OnDeviceAIPage: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                    .opacity(isAnimating ? 0 : 1)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
            }
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            
            Text("100% On-Device AI")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 20) {
                OnboardingFeatureRow(
                    icon: "lock.shield.fill",
                    title: "Complete Privacy",
                    description: "Your images never leave your device. All processing happens locally."
                )
                
                OnboardingFeatureRow(
                    icon: "wifi.slash",
                    title: "Works Offline",
                    description: "No internet? No problem. Generate PDFs anywhere, anytime."
                )
                
                OnboardingFeatureRow(
                    icon: "speedometer",
                    title: "Blazing Fast",
                    description: "Powered by Gemma 3N, optimized for mobile performance."
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Arm Optimized Page
struct ArmOptimizedPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "cpu.fill")
                .font(.system(size: 100))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("Built for Arm")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Optimized for Maximum Efficiency")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 20) {
                OnboardingFeatureRow(
                    icon: "battery.100",
                    title: "Energy Efficient",
                    description: "Leverages Arm architecture for minimal battery consumption."
                )
                
                OnboardingFeatureRow(
                    icon: "memorychip",
                    title: "Memory Optimized",
                    description: "Smart caching and efficient resource management."
                )
                
                OnboardingFeatureRow(
                    icon: "gauge.high",
                    title: "Peak Performance",
                    description: "Native Arm optimization ensures smooth, responsive experience."
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Features Page
struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: 25) {
            Spacer()
            
            Text("Powerful Features")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 20) {
                FeatureCard(
                    icon: "photo.on.rectangle",
                    title: "Smart Image Processing",
                    description: "AI analyzes your photos and generates professional LaTeX documents"
                )
                
                FeatureCard(
                    icon: "doc.text.magnifyingglass",
                    title: "LaTeX Generation",
                    description: "Converts handwritten notes, equations, and diagrams to LaTeX"
                )
                
                FeatureCard(
                    icon: "arrow.clockwise",
                    title: "Iterative Refinement",
                    description: "Suggest changes and refine your PDFs with AI assistance"
                )
                
                FeatureCard(
                    icon: "square.and.arrow.up",
                    title: "Easy Sharing",
                    description: "Save, share, and organize your generated PDFs effortlessly"
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Model Download Page
struct ModelDownloadPage: View {
    @StateObject private var downloadManager = ModelDownloadManager.shared
    @State private var selectedModel: GemmaModelIdentifier = .gemma2B
    @State private var isDownloading = false
    @State private var downloadError: String?
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: downloadManager.downloadStatus.isCompleted ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("Download AI Model")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Choose and download the AI model for on-device processing")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // Model Selection
            if !downloadManager.downloadStatus.isCompleted {
                VStack(spacing: 16) {
                    ForEach([GemmaModelIdentifier.gemma2B, GemmaModelIdentifier.gemma4B], id: \.self) { model in
                        ModelOptionCard(
                            model: model,
                            isSelected: selectedModel == model,
                            isDownloaded: downloadManager.isModelDownloaded(model)
                        ) {
                            selectedModel = model
                        }
                    }
                }
                .padding(.horizontal, 30)
            }
            
            // Download Status
            VStack(spacing: 16) {
                switch downloadManager.downloadStatus {
                case .notStarted:
                    if !downloadManager.isModelDownloaded(selectedModel) {
                        Button(action: { startDownload() }) {
                            HStack {
                                Image(systemName: "arrow.down.circle.fill")
                                Text("Download \(selectedModel.displayName)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(15)
                        }
                        .padding(.horizontal, 40)
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Model already downloaded")
                                .foregroundColor(.white)
                        }
                    }
                    
                case .downloading(let progress, let downloaded, let total):
                    VStack(spacing: 12) {
                        HStack {
                            Text("Downloading...")
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(progress * 100))%")
                                .foregroundColor(.white)
                        }
                        
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                        
                        HStack {
                            Text("\(formatBytes(downloaded)) / \(formatBytes(total))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            if downloadManager.downloadSpeed > 0 {
                                Text(String(format: "%.1f MB/s", downloadManager.downloadSpeed))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        if downloadManager.estimatedTimeRemaining > 0 {
                            Text("Est. time remaining: \(formatTime(downloadManager.estimatedTimeRemaining))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Button(action: { downloadManager.cancelDownload() }) {
                            Text("Cancel")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.7))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                case .verifying:
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Verifying download...")
                            .foregroundColor(.white)
                    }
                    
                case .extracting:
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Setting up model...")
                            .foregroundColor(.white)
                    }
                    
                case .completed:
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                            Text("Download Complete!")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        
                        Text("Model is ready for on-device AI processing")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                case .failed(let error):
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text("Download Failed")
                                .foregroundColor(.white)
                        }
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        
                        Button(action: { startDownload() }) {
                            Text("Retry")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                case .cancelled:
                    VStack(spacing: 12) {
                        Text("Download Cancelled")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button(action: { startDownload() }) {
                            Text("Retry")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            
            // Skip Note
            if !downloadManager.downloadStatus.isCompleted {
                Text("You can skip this and download later from Settings")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func startDownload() {
        Task {
            do {
                try await downloadManager.downloadModel(selectedModel)
            } catch {
                downloadError = error.localizedDescription
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.1f MB", mb)
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

struct ModelOptionCard: View {
    let model: GemmaModelIdentifier
    let isSelected: Bool
    let isDownloaded: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(modelDescription)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if isDownloaded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if isSelected {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding()
            .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
    
    private var modelDescription: String {
        switch model {
        case .gemma2B:
            return "~3.0 GB • Faster, Good quality"
        case .gemma4B:
            return "~4.5 GB • Slower, Best quality"
        }
    }
}

// MARK: - Get Started Page
struct GetStartedPage: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("You're All Set!")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Start converting your photos to beautiful PDFs")
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Select or take photos")
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Tap 'Generate PDF'")
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "3.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Review, refine, and share")
                        .foregroundColor(.white)
                    Spacer()
                }
            }
            .frame(maxWidth: 300)
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: onComplete) {
                Text("Get Started")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 10)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 50)
        }
        .padding()
    }
}

// MARK: - Helper Components
struct FeatureBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
            
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.2))
        .cornerRadius(25)
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.15))
        .cornerRadius(15)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState.shared)
}


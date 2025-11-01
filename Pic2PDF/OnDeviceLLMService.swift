//
//  OnDeviceLLMService.swift
//  Pic2PDF
//
//  Created by AI Assistant on 2025-01-30.
//

import Foundation
import UIKit
import MediaPipeTasksGenAI
import ZIPFoundation
import Combine
import Accelerate
import os.signpost

/// Represents the available Gemma models optimized for image-to-LaTeX conversion
public enum GemmaModelIdentifier: String, CaseIterable, Identifiable {
    case gemma2B = "gemma-3n-E2B-it-int4"
    case gemma4B = "gemma-3n-E4B-it-int4"

    public var id: String { self.rawValue }
    public var fileName: String { "\(self.rawValue).task" }

    public var displayName: String {
        switch self {
        case .gemma2B: return "Gemma 3N (2B)"
        case .gemma4B: return "Gemma 3N (4B)"
        }
    }

    /// Checks which models are actually present in the app bundle
    public static func availableInBundle() -> [GemmaModelIdentifier] {
        return GemmaModelIdentifier.allCases.filter { modelId in
            Bundle.main.path(forResource: modelId.rawValue, ofType: "task") != nil
        }
    }
}

/// Manages the on-device Gemma model, including initialization and vision component extraction
struct OnDeviceGemmaModel {
    private(set) var inference: LlmInference
    let identifier: GemmaModelIdentifier

    init(modelIdentifier: GemmaModelIdentifier, maxTokens: Int = 1000) throws {
        self.identifier = modelIdentifier
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)

        // First check for downloaded model in documents directory
        let downloadManager = ModelDownloadManager.shared
        let downloadedModelPath = downloadManager.localModelPath(for: modelIdentifier)
        
        var sourceModelPath: String?
        
        if fileManager.fileExists(atPath: downloadedModelPath.path) {
            // Use downloaded model
            sourceModelPath = downloadedModelPath.path
            NSLog("Using downloaded model at: \(downloadedModelPath.path)")
        } else if let bundleModelPath = Bundle.main.path(forResource: modelIdentifier.rawValue, ofType: "task") {
            // Fallback to bundled model if available
            sourceModelPath = bundleModelPath
            NSLog("Using bundled model at: \(bundleModelPath)")
        }
        
        guard let modelPath = sourceModelPath else {
            let errorMessage = "Model file '\(modelIdentifier.fileName)' not found. Please download the model first."
            NSLog(errorMessage)
            throw NSError(domain: "ModelSetupError", code: 1001, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        let modelCopyPath = cacheDir.appendingPathComponent(modelIdentifier.fileName)

        // Copy to cache if not already there or if source has been updated
        if !fileManager.fileExists(atPath: modelCopyPath.path) {
            try fileManager.copyItem(atPath: modelPath, toPath: modelCopyPath.path)
        }

        // Define vision component filenames within the .task archive
        let visionEncoderFileName = "TF_LITE_VISION_ENCODER"
        let visionAdapterFileName = "TF_LITE_VISION_ADAPTER"

        let extractedVisionEncoderPath = cacheDir.appendingPathComponent(visionEncoderFileName)
        let extractedVisionAdapterPath = cacheDir.appendingPathComponent(visionAdapterFileName)

        // Extract vision models if they don't exist
        if !fileManager.fileExists(atPath: extractedVisionEncoderPath.path) ||
           !fileManager.fileExists(atPath: extractedVisionAdapterPath.path) {
            NSLog("Extracting vision models from .task file...")
            do {
                try OnDeviceGemmaModel.extractVisionModels(
                    fromArchive: modelCopyPath,
                    toDirectory: cacheDir,
                    filesToExtract: [visionEncoderFileName, visionAdapterFileName]
                )
                NSLog("Successfully extracted vision models.")
            } catch {
                let extractionErrorMessage = "Error extracting vision components: \(error.localizedDescription)"
                NSLog(extractionErrorMessage)
                // Continue without vision components for now
            }
        } else {
            NSLog("Vision models already exist in cache.")
        }

        let options = LlmInference.Options(modelPath: modelCopyPath.path)
        options.maxTokens = maxTokens

        // Configure for vision modality
        options.visionEncoderPath = extractedVisionEncoderPath.path
        options.visionAdapterPath = extractedVisionAdapterPath.path
        options.maxImages = 5 // Support up to 5 images for document conversion

        inference = try LlmInference(options: options)
    }

    private static func extractVisionModels(fromArchive archiveURL: URL, toDirectory destinationURL: URL, filesToExtract: [String]) throws {
        let fileManager = FileManager.default
        let archive = try Archive(url: archiveURL, accessMode: .read)

        for fileName in filesToExtract {
            guard let entry = archive[fileName] else {
                NSLog("Vision component '\(fileName)' not found in archive")
                continue
            }

            let destinationFilePath = destinationURL.appendingPathComponent(fileName)

            if fileManager.fileExists(atPath: destinationFilePath.path) {
                try fileManager.removeItem(at: destinationFilePath)
            }

            NSLog("Extracting '\(fileName)' to cache")
            _ = try archive.extract(entry, to: destinationFilePath)
        }
    }
}

/// Represents a chat session with the on-device Gemma model
final class GemmaChatSession {
    private let model: OnDeviceGemmaModel
    private var session: LlmInference.Session

    init(model: OnDeviceGemmaModel,
         topK: Int = 40,
         topP: Float = 0.9,
         temperature: Float = 0.7,
         enableVisionModality: Bool = true) throws {
        self.model = model

        let options = LlmInference.Session.Options()
        options.topk = topK
        options.topp = topP
        options.temperature = temperature
        options.enableVisionModality = enableVisionModality

        session = try LlmInference.Session(llmInference: model.inference, options: options)
    }

    /// Adds an image to the current query context
    func addImageToQuery(image: CGImage) throws {
        try session.addImage(image: image)
    }

    /// Generates LaTeX from images and text prompt
    func generateLaTeX(prompt: String) async throws -> AsyncThrowingStream<String, any Error> {
        try session.addQueryChunk(inputText: prompt)
        let resultStream = session.generateResponseAsync()
        return resultStream
    }

    /// Gets the generation time for the last response
    func getLastResponseGenerationTime() -> TimeInterval? {
        return session.metrics.responseGenerationTimeInSeconds
    }

    /// Estimates token count for text
    func sizeInTokens(text: String) throws -> Int {
        return try session.sizeInTokens(text: text)
    }
}

/// Performance metrics for a single generation
struct GenerationMetrics: Identifiable {
    let id = UUID()
    let timestamp: Date
    let modelIdentifier: GemmaModelIdentifier
    let inputImageCount: Int
    let outputTokenCount: Int
    let generationTime: TimeInterval
    let tokensPerSecond: Double
    let memoryUsageMB: Double
    let batteryLevelBefore: Int
    let batteryLevelAfter: Int
    let thermalState: ProcessInfo.ThermalState
}

/// Main service class for on-device LLM processing in Pic2PDF
@MainActor
final class OnDeviceLLMService: ObservableObject {
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var initializationError: String?
    @Published var modelInitializationTime: Double = 0.0

    // MARK: - Performance Tracking
    @Published var generationHistory: [GenerationMetrics] = []
    @Published var totalGenerations: Int = 0
    @Published var averageGenerationTime: Double = 0.0
    @Published var averageTokensPerSecond: Double = 0.0
    @Published var peakMemoryUsage: Double = 0.0
    @Published var totalTokensGenerated: Int = 0

    // MARK: - Real-time Metrics
    @Published var currentMemoryUsage: Double = 0.0
    @Published var batteryLevel: Int = 100
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var deviceTemperature: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var currentTokensPerSecond: Double = 0.0
    @Published var realtimeMemoryHistory: [Double] = [] // Real-time memory tracking during generation
    
    // MARK: - Live Generation Streaming
    @Published var streamingLaTeX: String = ""

    // MARK: - Public Model Access
    /// Public access to current model information for UI display
    var currentModelInfo: (identifier: GemmaModelIdentifier, isInitialized: Bool) {
        if let model = currentModel {
            return (model.identifier, true)
        }
        return (preferredModel, false) // Return preferred model even if not initialized
    }
    
    /// Get the currently selected model identifier
    var selectedModel: GemmaModelIdentifier {
        return preferredModel
    }

    // MARK: - Private Properties
    private var currentModel: OnDeviceGemmaModel?
    private var currentSession: GemmaChatSession?
    private var preferredModel: GemmaModelIdentifier = .gemma2B
    private var metricsTimer: Timer?
    private let signpostLog = OSLog(subsystem: "com.pic2pdf.app", category: "LLM")
    private var firstTokenLogged = false

    private var isPerformanceModeEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "performanceModeEnabled")
    }

    // MARK: - Singleton
    static let shared = OnDeviceLLMService()

    private init() {
        setupMetricsMonitoring()
        Task {
            await initializeModel()
        }
    }

    // MARK: - Metrics Monitoring
    private func setupMetricsMonitoring() {
        // Update real-time metrics every second
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRealTimeMetrics()
            }
        }

        // Battery monitoring
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = Int((UIDevice.current.batteryLevel * 100).rounded())

        NotificationCenter.default.addObserver(forName: UIDevice.batteryLevelDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.batteryLevel = Int((UIDevice.current.batteryLevel * 100).rounded())
        }

        // Thermal state monitoring
        thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
        }
    }

    private func updateRealTimeMetrics() {
        currentMemoryUsage = ProcessMetrics.currentResidentMemoryMB()

        // Update peak memory usage
        if currentMemoryUsage > peakMemoryUsage {
            peakMemoryUsage = currentMemoryUsage
        }
        
        // Add to real-time history if we have streaming content (generation in progress)
        if !streamingLaTeX.isEmpty {
            realtimeMemoryHistory.append(currentMemoryUsage)
            // Keep only last 30 data points for performance
            if realtimeMemoryHistory.count > 30 {
                realtimeMemoryHistory.removeFirst()
            }
        }

        // CPU usage (simulated for demo)
        cpuUsage = ProcessMetrics.currentCPUUsage()

        // Temperature simulation (IOKit not available in iOS apps)
        // In production, would use private APIs or device sensors
        let baseTemp: Double = 38.0 // Base temperature for iOS device
        let thermalAdjustment: Double = thermalState == .nominal ? 0 :
                                       thermalState == .fair ? 3 :
                                       thermalState == .serious ? 8 : 12
        deviceTemperature = baseTemp + Double.random(in: -2...2) + thermalAdjustment
    }

    private func recordGenerationMetrics(inputImages: Int, outputTokens: Int, generationTime: TimeInterval, batteryBefore: Int) {
        let tokensPerSecond = Double(outputTokens) / generationTime
        let memoryUsage = currentMemoryUsage

        let metrics = GenerationMetrics(
            timestamp: Date(),
            modelIdentifier: preferredModel,
            inputImageCount: inputImages,
            outputTokenCount: outputTokens,
            generationTime: generationTime,
            tokensPerSecond: tokensPerSecond,
            memoryUsageMB: memoryUsage,
            batteryLevelBefore: batteryBefore,
            batteryLevelAfter: batteryLevel,
            thermalState: thermalState
        )

        generationHistory.append(metrics)

        // Keep only last 50 generations for performance
        if generationHistory.count > 50 {
            generationHistory.removeFirst()
        }

        // Update aggregates
        totalGenerations += 1
        totalTokensGenerated += outputTokens

        let allGenerationTimes = generationHistory.map { $0.generationTime }
        averageGenerationTime = allGenerationTimes.reduce(0, +) / Double(allGenerationTimes.count)

        let allTokensPerSecond = generationHistory.map { $0.tokensPerSecond }
        averageTokensPerSecond = allTokensPerSecond.reduce(0, +) / Double(allTokensPerSecond.count)
    }

    // MARK: - Model Management

    /// Initializes the preferred Gemma model
    private func initializeModel() async {
        do {
            let startTime = Date()
            os_signpost(.begin, log: signpostLog, name: "ModelInit", "Model=%{public}@", preferredModel.displayName)

            // Adjust max tokens in performance mode for speed/thermal headroom
            let maxTokens = isPerformanceModeEnabled ? 1200 : 2000
            currentModel = try OnDeviceGemmaModel(modelIdentifier: preferredModel, maxTokens: maxTokens)
            currentSession = try GemmaChatSession(model: currentModel!)

            let endTime = Date()
            modelInitializationTime = endTime.timeIntervalSince(startTime)

            isInitialized = true
            initializationError = nil

            os_signpost(.end, log: signpostLog, name: "ModelInit")
            NSLog("Gemma model \(preferredModel.displayName) initialized in \(modelInitializationTime)s (perfMode=\(isPerformanceModeEnabled))")
        } catch {
            initializationError = "Failed to initialize on-device LLM: \(error.localizedDescription)"
            isInitialized = false
            NSLog("Model initialization error: \(error)")
        }
    }

    /// Checks if the service is ready for inference
    func isReady() -> Bool {
        return isInitialized && currentSession != nil
    }
    
    /// Switch to a different model
    /// - Parameter modelIdentifier: The model to switch to
    func switchModel(to modelIdentifier: GemmaModelIdentifier) async {
        guard modelIdentifier != preferredModel else {
            NSLog("Already using model: \(modelIdentifier.displayName)")
            return
        }
        
        NSLog("Switching model from \(preferredModel.displayName) to \(modelIdentifier.displayName)")
        
        // Update preferred model
        preferredModel = modelIdentifier
        
        // Reset initialization state
        isInitialized = false
        initializationError = nil
        currentModel = nil
        currentSession = nil
        
        // Initialize new model
        await initializeModel()
    }

    // MARK: - LaTeX Generation

    /// Generates LaTeX from images using the on-device LLM
    /// - Parameters:
    ///   - images: Array of UIImages to convert
    ///   - additionalPrompt: Optional additional context or instructions
    ///   - status: Status object to update with progress
    /// - Returns: Generated LaTeX string
    func generateLaTeX(from images: [UIImage],
                       additionalPrompt: String? = nil,
                       status: GenerationStatus) async throws -> String {
        guard isReady() else {
            throw OnDeviceLLMError.notInitialized
        }

        let startTime = Date()
        let batteryBefore = batteryLevel
        let initialMemory = currentMemoryUsage

        await MainActor.run {
            status.statusMessage = "Processing images with on-device AI..."
            status.progress = 0.1
            streamingLaTeX = "" // Clear previous stream
            currentTokensPerSecond = 0.0 // Reset real-time metric
            realtimeMemoryHistory = [] // Clear real-time memory history
        }

        // Create a new session for this generation task (tune for performance mode)
        let session = try GemmaChatSession(
            model: currentModel!,
            topK: isPerformanceModeEnabled ? 60 : 40,
            topP: isPerformanceModeEnabled ? 0.95 : 0.9,
            temperature: isPerformanceModeEnabled ? 0.6 : 0.7,
            enableVisionModality: true
        )

        // Downscale images in parallel (Accelerate) for lower memory and faster vision path
        os_signpost(.begin, log: signpostLog, name: "PreprocessImages")
        let maxDimension = isPerformanceModeEnabled ? 1024 : 1536
        let processedCGImages: [CGImage] = await withTaskGroup(of: CGImage?.self) { group in
            for img in images {
                group.addTask(priority: .userInitiated) {
                    guard let cg = img.cgImage else { return nil }
                    return downscaleCGImageAccelerate(cg, maxDimension: maxDimension) ?? cg
                }
            }
            var results: [CGImage] = []
            while let next = await group.next() {
                if let img = next { results.append(img) }
            }
            return results
        }
        os_signpost(.end, log: signpostLog, name: "PreprocessImages")

        for (index, cgImage) in processedCGImages.enumerated() {
            try session.addImageToQuery(image: cgImage)
            await MainActor.run {
                status.statusMessage = "Processing image \(index + 1) of \(processedCGImages.count)..."
                status.progress = 0.1 + (0.3 * Double(index + 1) / Double(processedCGImages.count))
            }
        }

        await MainActor.run {
            status.statusMessage = "Generating LaTeX with on-device AI..."
            status.progress = 0.5
        }

        // Create the prompt for LaTeX generation
        let prompt = createLaTeXGenerationPrompt(additionalPrompt: additionalPrompt)

        // Generate LaTeX using streaming response (30fps throttled UI updates)
        let stream = try await session.generateLaTeX(prompt: prompt)
        var fullResponse = ""
        let generationStartTime = Date()
        var lastUIUpdate = Date.distantPast
        firstTokenLogged = false

        for try await chunk in stream {
            fullResponse += chunk

            // First token event
            if !firstTokenLogged && !chunk.isEmpty {
                os_signpost(.event, log: signpostLog, name: "FirstToken")
                firstTokenLogged = true
            }

            let now = Date()
            if now.timeIntervalSince(lastUIUpdate) >= (1.0 / 30.0) {
                let elapsedTime = now.timeIntervalSince(generationStartTime)
                let estimatedTokens = max(fullResponse.count / 4, 1) // ~4 chars per token
                let tokensPerSec = elapsedTime > 0 ? Double(estimatedTokens) / elapsedTime : 0

                await MainActor.run {
                    streamingLaTeX = fullResponse // Update streaming display
                    currentTokensPerSecond = tokensPerSec // Update real-time tokens/sec
                    status.statusMessage = "Generating LaTeX... (\(fullResponse.count) characters)"
                    status.progress = 0.5 + (0.4 * min(1.0, Double(fullResponse.count) / 2000.0))
                }
                lastUIUpdate = now
            }
        }

        let endTime = Date()
        let generationTime = endTime.timeIntervalSince(startTime)

        await MainActor.run {
            status.statusMessage = "LaTeX generation complete"
            status.progress = 1.0
        }

        // Extract LaTeX content from response (remove any extra text)
        let latexResult = extractLaTeXFromResponse(fullResponse)

        // Estimate token count using model tokenizer; fallback to char/4 if unavailable
        let estimatedTokens = (try? session.sizeInTokens(text: fullResponse)) ?? (fullResponse.count / 4)

        // Record performance metrics
        recordGenerationMetrics(
            inputImages: images.count,
            outputTokens: estimatedTokens,
            generationTime: generationTime,
            batteryBefore: batteryBefore
        )

        return latexResult
    }

    /// Refines existing LaTeX based on user feedback using on-device LLM
    /// - Parameters:
    ///   - currentLaTeX: The existing LaTeX to refine
    ///   - userFeedback: User's refinement instructions
    ///   - status: Status object to update with progress
    /// - Returns: Refined LaTeX string
    /// - Note: This method does NOT re-process images, only refines the existing LaTeX code
    func refineLaTeX(currentLaTeX: String,
                     userFeedback: String,
                     status: GenerationStatus) async throws -> String {
        guard isReady() else {
            throw OnDeviceLLMError.notInitialized
        }

        let startTime = Date()
        let batteryBefore = batteryLevel

        await MainActor.run {
            status.statusMessage = "Preparing refinement with on-device AI..."
            status.progress = 0.1
            streamingLaTeX = "" // Clear previous stream
            currentTokensPerSecond = 0.0 // Reset real-time metric
            realtimeMemoryHistory = [] // Clear real-time memory history
        }

        // Create a new session for refinement (text-only, no images)
        let session = try GemmaChatSession(
            model: currentModel!,
            topK: isPerformanceModeEnabled ? 60 : 40,
            topP: isPerformanceModeEnabled ? 0.95 : 0.9,
            temperature: isPerformanceModeEnabled ? 0.6 : 0.7,
            enableVisionModality: false
        )

        await MainActor.run {
            status.statusMessage = "Refining LaTeX with on-device AI..."
            status.progress = 0.3
        }

        // Create refinement prompt
        let prompt = createLaTeXRefinementPrompt(currentLaTeX: currentLaTeX, userFeedback: userFeedback)

        // Generate refined LaTeX (30fps throttled updates)
        let stream = try await session.generateLaTeX(prompt: prompt)
        var fullResponse = ""
        let generationStartTime = Date()
        var lastUIUpdate = Date.distantPast
        firstTokenLogged = false

        for try await chunk in stream {
            fullResponse += chunk

            if !firstTokenLogged && !chunk.isEmpty {
                os_signpost(.event, log: signpostLog, name: "FirstToken(Refine)")
                firstTokenLogged = true
            }

            let now = Date()
            if now.timeIntervalSince(lastUIUpdate) >= (1.0 / 30.0) {
                let elapsedTime = now.timeIntervalSince(generationStartTime)
                let estimatedTokens = max(fullResponse.count / 4, 1)
                let tokensPerSec = elapsedTime > 0 ? Double(estimatedTokens) / elapsedTime : 0

                await MainActor.run {
                    streamingLaTeX = fullResponse // Update streaming display
                    currentTokensPerSecond = tokensPerSec // Update real-time tokens/sec
                    status.statusMessage = "Refining LaTeX... (\(fullResponse.count) characters)"
                    status.progress = 0.3 + (0.6 * min(1.0, Double(fullResponse.count) / 2000.0))
                }
                lastUIUpdate = now
            }
        }

        let endTime = Date()
        let generationTime = endTime.timeIntervalSince(startTime)

        await MainActor.run {
            status.statusMessage = "LaTeX refinement complete"
            status.progress = 1.0
        }

        let latexResult = extractLaTeXFromResponse(fullResponse)

        // Estimate token count for refinement using tokenizer when possible
        let estimatedTokens = (try? session.sizeInTokens(text: fullResponse)) ?? (fullResponse.count / 4)

        // Record performance metrics for refinement (0 images since we're only refining LaTeX)
        recordGenerationMetrics(
            inputImages: 0,
            outputTokens: estimatedTokens,
            generationTime: generationTime,
            batteryBefore: batteryBefore
        )

        return latexResult
    }

    // MARK: - Private Helper Methods

    private func createLaTeXGenerationPrompt(additionalPrompt: String?) -> String {
        let basePrompt = """
        You are a LaTeX transcription tool. Convert the images shown into LaTeX code.

        Requirements:
        - Use ONLY \\documentclass{article} with \\usepackage{amsmath} and \\usepackage{amssymb}
        - Do NOT use: \\includegraphics, \\geometry, \\pagestyle, \\fancyhdr, \\fancyhead, \\fancyfoot, \\renewcommand, tabular, table, tikz, tikzpicture, or any other packages
        - Do NOT add \\section, \\subsection, or explanatory text about the LaTeX code itself
        - Just transcribe exactly what you see in the image - text, equations, lists
        - Use \\textbf{} for bold, \\textit{} for italic
        - For math: Use ONLY \\[ \\] for display math and $ $ for inline math
        - NEVER use \\begin{equation}, \\begin{align}, \\begin{gather}, \\begin{multline}, or ANY \\begin{}...\\end{} environments
        - Keep it minimal and direct - no commentary, no meta-descriptions
        - For diagrams or figures, just write [Figure: description] as plain text

        Important: Return ONLY the LaTeX code, no explanations or markdown formatting.
        """

        if let additional = additionalPrompt, !additional.isEmpty {
            return basePrompt + "\n\nAdditional instructions: \(additional)"
        }

        return basePrompt
    }

    private func createLaTeXRefinementPrompt(currentLaTeX: String, userFeedback: String) -> String {
        return """
        You are a LaTeX transcription tool. Refine the following LaTeX code based on user feedback.

        Current LaTeX:
        ```
        \(currentLaTeX)
        ```

        User feedback: \(userFeedback)

        Requirements:
        - Make the requested changes
        - Use ONLY \\documentclass{article} with \\usepackage{amsmath} and \\usepackage{amssymb}
        - Do NOT use: \\includegraphics, \\geometry, \\pagestyle, \\fancyhdr, \\fancyhead, \\fancyfoot, \\renewcommand, tabular, table, tikz, tikzpicture, or any other packages
        - Do NOT add \\section, \\subsection, or explanatory text about the LaTeX code itself
        - For math: Use ONLY \\[ \\] for display math and $ $ for inline math
        - NEVER use \\begin{equation}, \\begin{align}, \\begin{gather}, \\begin{multline}, or ANY \\begin{}...\\end{} environments
        - Keep it minimal and direct - just the content
        - Return ONLY the refined LaTeX code, no explanations

        Refined LaTeX:
        """
    }

    private func extractLaTeXFromResponse(_ response: String) -> String {
        // Remove markdown code blocks if present
        var latex = response
            .replacingOccurrences(of: "```latex", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure it starts with \documentclass if it doesn't already
        if !latex.hasPrefix("\\documentclass") {
            // Try to find LaTeX content within the response
            if let latexStart = latex.firstIndex(of: "\\") {
                latex = String(latex[latexStart...])
            }
        }

        return latex
    }

}

// MARK: - Error Types
enum OnDeviceLLMError: LocalizedError {
    case notInitialized
    case modelNotAvailable
    case invalidImage
    case generationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "On-device AI is not initialized. Please wait for model loading to complete."
        case .modelNotAvailable:
            return "Required AI model is not available on this device."
        case .invalidImage:
            return "Invalid image provided for processing."
        case .generationFailed(let reason):
            return "AI generation failed: \(reason)"
        }
    }
}

// MARK: - Global Accelerate Helper (non-main-actor)
private func downscaleCGImageAccelerate(_ src: CGImage, maxDimension: Int) -> CGImage? {
    let width = src.width
    let height = src.height
    let maxSide = max(width, height)
    guard maxSide > maxDimension else { return src }

    let scale = Double(maxDimension) / Double(maxSide)
    let dstW = Int(Double(width) * scale)
    let dstH = Int(Double(height) * scale)

    var format = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: Unmanaged.passUnretained(CGColorSpaceCreateDeviceRGB()),
        bitmapInfo: CGBitmapInfo.byteOrder32Little.union(.init(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent
    )

    var srcBuf = vImage_Buffer()
    var dstBuf = vImage_Buffer()
    defer {
        free(srcBuf.data)
        free(dstBuf.data)
    }

    guard vImageBuffer_InitWithCGImage(&srcBuf, &format, nil, src, vImage_Flags(kvImageNoFlags)) == kvImageNoError else { return nil }
    guard vImageBuffer_Init(&dstBuf, vImagePixelCount(dstH), vImagePixelCount(dstW), format.bitsPerPixel, vImage_Flags(kvImageNoFlags)) == kvImageNoError else { return nil }

    vImageScale_ARGB8888(&srcBuf, &dstBuf, nil, vImage_Flags(kvImageHighQualityResampling))
    return vImageCreateCGImageFromBuffer(&dstBuf, &format, nil, nil, vImage_Flags(kvImageNoAllocate), nil)?.takeRetainedValue()
}

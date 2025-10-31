//
//  ModelDownloadManager.swift
//  Pic2PDF
//
//  Created for Arm AI Developer Challenge 2025
//

import Foundation
import Combine

/// Configuration for downloadable models
struct DownloadableModelConfig {
    let identifier: GemmaModelIdentifier
    let downloadURL: URL
    let expectedSizeMB: Double
    let checksum: String? // Optional SHA256 checksum for verification
    
    // Cloudflare R2 - Production URLs
    static let availableModels: [GemmaModelIdentifier: DownloadableModelConfig] = [
        .gemma2B: DownloadableModelConfig(
            identifier: .gemma2B,
            downloadURL: URL(string: "https://pub-69c747d5957f4104a2f87b0aca35a2af.r2.dev/gemma-3n-E2B-it-int4.task")!,
            expectedSizeMB: 2992.0, // ~2.9 GB
            checksum: nil
        ),
        .gemma4B: DownloadableModelConfig(
            identifier: .gemma4B,
            downloadURL: URL(string: "https://pub-69c747d5957f4104a2f87b0aca35a2af.r2.dev/gemma-3n-E4B-it-int4.task")!,
            expectedSizeMB: 4608.0, // ~4.5 GB
            checksum: nil
        )
    ]
}

/// Model download status
enum ModelDownloadStatus: Equatable {
    case notStarted
    case downloading(progress: Double, bytesDownloaded: Int64, totalBytes: Int64)
    case verifying
    case extracting
    case completed
    case failed(error: String)
    case cancelled
    
    var isInProgress: Bool {
        switch self {
        case .downloading, .verifying, .extracting:
            return true
        default:
            return false
        }
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

/// Manages downloading and storing ML models at runtime
@MainActor
final class ModelDownloadManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var downloadStatus: ModelDownloadStatus = .notStarted
    @Published var downloadSpeed: Double = 0.0 // MB/s
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    // MARK: - Private Properties
    private var downloadTask: URLSessionDownloadTask?
    private var downloadStartTime: Date?
    private var lastProgressUpdate: Date?
    private var lastBytesDownloaded: Int64 = 0
    
    // MARK: - Singleton
    static let shared = ModelDownloadManager()
    
    // MARK: - Model Storage
    private var modelsDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = documentsDir.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        return modelsDir
    }
    
    /// Get the local path for a model file
    func localModelPath(for identifier: GemmaModelIdentifier) -> URL {
        return modelsDirectory.appendingPathComponent(identifier.fileName)
    }
    
    /// Check if a model is already downloaded
    func isModelDownloaded(_ identifier: GemmaModelIdentifier) -> Bool {
        let path = localModelPath(for: identifier)
        return FileManager.default.fileExists(atPath: path.path)
    }
    
    /// Get the size of a downloaded model in MB
    func modelSize(_ identifier: GemmaModelIdentifier) -> Double? {
        let path = localModelPath(for: identifier)
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }
        return Double(fileSize) / (1024 * 1024)
    }
    
    // MARK: - Download Methods
    
    /// Download a model from the configured URL
    func downloadModel(_ identifier: GemmaModelIdentifier) async throws {
        guard let config = DownloadableModelConfig.availableModels[identifier] else {
            throw ModelDownloadError.configurationNotFound
        }
        
        // Check if already downloaded
        if isModelDownloaded(identifier) {
            downloadStatus = .completed
            return
        }
        
        // Check available disk space
        let requiredSpace = Int64(config.expectedSizeMB * 1024 * 1024)
        if !hasEnoughDiskSpace(requiredBytes: requiredSpace) {
            throw ModelDownloadError.insufficientDiskSpace(requiredMB: config.expectedSizeMB)
        }
        
        downloadStatus = .downloading(progress: 0, bytesDownloaded: 0, totalBytes: Int64(config.expectedSizeMB * 1024 * 1024))
        downloadStartTime = Date()
        lastProgressUpdate = Date()
        lastBytesDownloaded = 0
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: config.downloadURL)
            downloadTask = task
            
            // Store continuation for completion callback
            self.downloadContinuation = continuation
            
            task.resume()
        }
    }
    
    /// Cancel ongoing download
    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        downloadStatus = .cancelled
    }
    
    /// Delete a downloaded model
    func deleteModel(_ identifier: GemmaModelIdentifier) throws {
        let path = localModelPath(for: identifier)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private var downloadContinuation: CheckedContinuation<Void, Error>?
    
    private func hasEnoughDiskSpace(requiredBytes: Int64) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            return false
        }
        // Keep 500MB buffer
        return freeSpace > (requiredBytes + 500 * 1024 * 1024)
    }
    
    private func calculateDownloadSpeed(bytesDownloaded: Int64) {
        guard let lastUpdate = lastProgressUpdate else { return }
        
        let now = Date()
        let timeDiff = now.timeIntervalSince(lastUpdate)
        
        if timeDiff >= 1.0 { // Update speed every second
            let bytesDiff = bytesDownloaded - lastBytesDownloaded
            downloadSpeed = Double(bytesDiff) / (1024 * 1024) / timeDiff // MB/s
            
            lastProgressUpdate = now
            lastBytesDownloaded = bytesDownloaded
        }
    }
    
    private func calculateEstimatedTime(bytesDownloaded: Int64, totalBytes: Int64) {
        if downloadSpeed > 0 {
            let remainingBytes = totalBytes - bytesDownloaded
            let remainingMB = Double(remainingBytes) / (1024 * 1024)
            estimatedTimeRemaining = remainingMB / downloadSpeed
        }
    }
}

// MARK: - URLSessionDownloadDelegate
extension ModelDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // CRITICAL: Must copy file SYNCHRONOUSLY before this delegate method returns
        // iOS deletes the temp file after this method completes!
        
        NSLog("[ModelDownload] Download finished, temp file at: \(location.path)")
        
        // Get identifier synchronously
        guard let originalURL = downloadTask.originalRequest?.url,
              let identifier = DownloadableModelConfig.availableModels.first(where: { $0.value.downloadURL == originalURL })?.key else {
            NSLog("[ModelDownload] ERROR: Unknown model")
            Task { @MainActor in
                self.downloadStatus = .failed(error: "Unknown model")
                self.downloadContinuation?.resume(throwing: ModelDownloadError.unknownModel)
                self.downloadContinuation = nil
            }
            return
        }
        
        let destination = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent(identifier.fileName)
        
        // Copy file SYNCHRONOUSLY
        do {
            // Create Models directory if needed
            let modelsDir = destination.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
            
            NSLog("[ModelDownload] Copying from: \(location.path)")
            NSLog("[ModelDownload] Copying to: \(destination.path)")
            
            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            
            // Get file size
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            if let fileSize = attributes[.size] as? Int64 {
                NSLog("[ModelDownload] File size: \(fileSize) bytes (\(Double(fileSize)/(1024*1024)) MB)")
            }
            
            // Copy file IMMEDIATELY
            try FileManager.default.copyItem(at: location, to: destination)
            NSLog("[ModelDownload] Copy successful to: \(destination.path)")
            
            // Update UI on main actor
            Task { @MainActor in
                self.downloadStatus = .completed
                self.downloadContinuation?.resume()
                self.downloadContinuation = nil
                NSLog("[ModelDownload] Model \(identifier.displayName) downloaded successfully")
            }
            
        } catch {
            NSLog("[ModelDownload] ERROR: \(error)")
            NSLog("[ModelDownload] Error details: \(error.localizedDescription)")
            
            Task { @MainActor in
                self.downloadStatus = .failed(error: error.localizedDescription)
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            downloadStatus = .downloading(progress: progress, bytesDownloaded: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
            
            calculateDownloadSpeed(bytesDownloaded: totalBytesWritten)
            calculateEstimatedTime(bytesDownloaded: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                NSLog("[ModelDownload] Download failed with error: \(error)")
                NSLog("[ModelDownload] Error code: \((error as NSError).code)")
                
                if (error as NSError).code == NSURLErrorCancelled {
                    downloadStatus = .cancelled
                    downloadContinuation?.resume(throwing: error)
                } else {
                    downloadStatus = .failed(error: error.localizedDescription)
                    downloadContinuation?.resume(throwing: error)
                }
                downloadContinuation = nil
            }
        }
    }
}

// MARK: - Error Types
enum ModelDownloadError: LocalizedError {
    case configurationNotFound
    case insufficientDiskSpace(requiredMB: Double)
    case checksumMismatch
    case unknownModel
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationNotFound:
            return "Model configuration not found"
        case .insufficientDiskSpace(let requiredMB):
            return "Insufficient disk space. Need at least \(Int(requiredMB))MB free"
        case .checksumMismatch:
            return "Downloaded file checksum verification failed"
        case .unknownModel:
            return "Unknown model identifier"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        }
    }
}


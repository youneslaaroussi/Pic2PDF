//
//  ModelConfig.swift
//  Pic2PDF
//
//  Model download configuration
//  Update the URLs below with actual model download links
//

import Foundation

extension DownloadableModelConfig {
    /// Update these URLs with your actual model download links
    /// The models should be in .task format compatible with MediaPipe
    static func updateDownloadURLs() -> [ModelIdentifier: DownloadableModelConfig] {
        return [
            .gemma2B: DownloadableModelConfig(
                identifier: .gemma2B,
                // TODO: Replace with actual download URL for 2B model
                downloadURL: URL(string: "https://example.com/models/gemma-3n-E2B-it-int4.task")!,
                expectedSizeMB: 500.0,
                checksum: nil // Optional: Add SHA256 checksum for verification
            ),
            .gemma4B: DownloadableModelConfig(
                identifier: .gemma4B,
                // TODO: Replace with actual download URL for 4B model
                downloadURL: URL(string: "https://example.com/models/gemma-3n-E4B-it-int4.task")!,
                expectedSizeMB: 900.0,
                checksum: nil // Optional: Add SHA256 checksum for verification
            )
        ]
    }
}

/*
 INSTRUCTIONS FOR UPDATING MODEL URLS:
 
 1. Replace the placeholder URLs above with your actual model download links
 2. The URLs should point to direct downloads of the .task model files
 3. Update the expectedSizeMB values to match actual model sizes
 4. Optionally add SHA256 checksums for download verification
 
 Example:
 
 .gemma2B: DownloadableModelConfig(
     identifier: .gemma2B,
     downloadURL: URL(string: "https://storage.googleapis.com/your-bucket/model-2B.task")!,
     expectedSizeMB: 512.5,
     checksum: "abc123def456..." // Optional SHA256 hash
 )
 
 Supported hosting services:
 - Google Cloud Storage
 - AWS S3
 - Azure Blob Storage
 - Any direct download link that supports Range requests
 
 Note: Ensure your hosting service:
 - Supports HTTP/HTTPS downloads
 - Allows direct file access (not HTML pages)
 - Has sufficient bandwidth for user downloads
 - Supports resume downloads (Range requests) for better UX
*/


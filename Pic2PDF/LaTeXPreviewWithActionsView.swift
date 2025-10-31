//
//  LaTeXPreviewWithActionsView.swift
//  Pic2PDF
//

import SwiftUI
import PDFKit
import WebKit

struct LaTeXPreviewWithActionsView: View {
    @Binding var currentLaTeX: String
    let selectedImages: [UIImage]
    let onRefinement: (String) -> Void
    let onStartOver: () -> Void

    @State private var showRefinementSheet = false
    @State private var refinementFeedback = ""
    @State private var webView: WKWebView?
    @State private var isExporting = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @Environment(\.dismiss) var dismiss
    @StateObject private var storageManager = StorageManager.shared

    var body: some View {
        VStack(spacing: 0) {
            LaTeXWebView(latex: currentLaTeX) { view in
                webView = view
            }
            .background(Color(.systemBackground))

            HStack(spacing: 16) {
                Button(action: { showRefinementSheet = true }) {
                    VStack(spacing: 8) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 24, weight: .medium))
                        Text("Refine")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .foregroundColor(.primary)

                Button(action: sharePDF) {
                    VStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .font(.system(size: 24, weight: .medium))
                        Text("Share")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .foregroundColor(.primary)
                .disabled(isExporting)
            }
            .padding()
            .background(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: -2)
        }
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRefinementSheet) {
            RefinementView(
                feedback: $refinementFeedback,
                onSubmit: {
                    showRefinementSheet = false
                    dismiss()
                    onRefinement(refinementFeedback)
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(items: [shareURL])
            }
        }
    }

    private func exportPDF(completion: @escaping (Result<Data, Error>) -> Void) {
        guard let webView = webView else { return }
        isExporting = true
        webView.exportPDF { result in
            isExporting = false
            completion(result)
        }
    }

    private func sharePDF() {
        exportPDF { result in
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
                    print("[Preview] Share write failed: \(error)")
                }
            case .failure(let error):
                print("[Preview] Export failed: \(error)")
            }
        }
    }
}

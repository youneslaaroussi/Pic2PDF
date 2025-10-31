//
//  PDFViewer.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import SwiftUI
import PDFKit

struct PDFViewer: UIViewRepresentable {
    let pdfDocument: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = pdfDocument
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = pdfDocument
    }
}


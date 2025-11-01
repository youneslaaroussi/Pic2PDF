//
//  LaTeXRenderer.swift
//  Pic2PDF
//
//  Created by Younes Laaroussi on 2025-10-13.
//

import Foundation
import PDFKit
import WebKit

class LaTeXRenderer: NSObject {
    
    func renderLaTeXToPDF(latex: String) async throws -> PDFDocument {
        print("[Renderer] Starting LaTeX compilation using WebView")
        print("[Renderer] LaTeX length: \(latex.count) characters")
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let renderer = WebViewPDFRenderer()
                renderer.renderLaTeXToPDF(latex: latex) { result in
                    continuation.resume(with: result)
                }
            }
        }
    }
    
}

// MARK: - WebView PDF Renderer
class WebViewPDFRenderer: NSObject, WKNavigationDelegate {
    private var webView: WKWebView!
    private var completion: ((Result<PDFDocument, Error>) -> Void)?
    private var renderTimeout: Timer?
    
    override init() {
        super.init()
        
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        
        // Create webview with reasonable size for PDF rendering
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842), configuration: config)
        webView.navigationDelegate = self
    }
    
    func renderLaTeXToPDF(latex: String, completion: @escaping (Result<PDFDocument, Error>) -> Void) {
        self.completion = completion
        
        // Set a timeout for rendering
        renderTimeout = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { [weak self] _ in
            self?.completion?(.failure(LaTeXError.renderTimeout))
            self?.cleanup()
        }
        
        let html = makeHTMLDocument(latex: latex)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func makeHTMLDocument(latex: String) -> String {
        print("[LaTeXRenderer] makeHTMLDocument() called, latex length: \(latex.count)")
        print("[LaTeXRenderer] First 200 chars of latex: \(String(latex.prefix(200)))")
        
        // STRIP UNSUPPORTED PACKAGES AND COMMANDS
        let cleanedLatex = stripUnsupportedLaTeX(latex)
        print("[LaTeXRenderer] After cleaning: \(String(cleanedLatex.prefix(200)))")
        
        // Standard JavaScript string escaping
        let escaped = cleanedLatex
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let html = """
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <meta charset="UTF-8">
            <style>
              body { 
                margin: 20px; 
                background: #fff;
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
              }
              .error {
                color: red;
                font-family: monospace;
                white-space: pre-wrap;
                padding: 20px;
                background: #fee;
                border: 1px solid red;
                border-radius: 4px;
              }
            </style>
            <script src="https://cdn.jsdelivr.net/npm/latex.js/dist/latex.js"></script>
          </head>
          <body>
            <div id="container"></div>
            <script>
              (function(){
                try {
                  const src = "\(escaped)";
                  const generator = new latexjs.HtmlGenerator({ hyphenate: false });
                  latexjs.parse(src, { generator: generator });
                  
                  // Inject styles and scripts
                  document.head.appendChild(generator.stylesAndScripts("https://cdn.jsdelivr.net/npm/latex.js/dist/"));
                  
                  // Append the generated HTML
                  document.body.appendChild(generator.domFragment());
                } catch (e) {
                  document.body.innerHTML = '<pre style=\"color:red\">' + e.toString() + '</pre>';
                }
              })();
            </script>
          </body>
        </html>
        """
        
        print("[LaTeXRenderer] ========== INJECTED HTML START ==========")
        print(html)
        print("[LaTeXRenderer] ========== INJECTED HTML END ==========")
        
        return html
    }
    
    private func stripUnsupportedLaTeX(_ latex: String) -> String {
        var cleaned = latex
        
        // Remove entire lines with unsupported packages
        cleaned = cleaned.replacingOccurrences(of: #"\\usepackage\{graphicx\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\usepackage\{geometry\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\usepackage\{fancyhdr\}\n?"#, with: "", options: .regularExpression)
        
        // Remove geometry command with any arguments
        cleaned = cleaned.replacingOccurrences(of: #"\\geometry\{[^\}]+\}\n?"#, with: "", options: .regularExpression)
        
        // Remove ALL fancy header related lines (line by line)
        cleaned = cleaned.replacingOccurrences(of: #"\\pagestyle\{fancy\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\fancyhf\{\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\renewcommand\{[^\}]+\}\{[^\}]+\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\fancyhead\[[^\]]+\]\{[^\n]+\}\n?"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\fancyfoot\[[^\]]+\]\{[^\n]+\}\n?"#, with: "", options: .regularExpression)
        
        // Remove includegraphics (replace with placeholder text)
        cleaned = cleaned.replacingOccurrences(of: #"\\includegraphics(\[[^\]]*\])?\{[^\}]+\}"#, with: "[Image]", options: .regularExpression)
        
        // Remove tabular environments (replace with plain text)
        cleaned = cleaned.replacingOccurrences(of: #"\\begin\{tabular\}[^\n]*\n([^\\]*)(\\end\{tabular\})"#, with: "[Table data removed - not supported]", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\begin\{table\}[^\n]*\n([^\\]*)(\\end\{table\})"#, with: "[Table removed - not supported]", options: .regularExpression)
        
        // Remove tikz environments (replace with plain text)
        cleaned = cleaned.replacingOccurrences(of: #"\\begin\{tikzpicture\}[\s\S]*?\\end\{tikzpicture\}"#, with: "[Figure removed - not supported]", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\\usepackage\{tikz\}\n?"#, with: "", options: .regularExpression)
        
        // ===== REMOVE UNSUPPORTED MATH ENVIRONMENTS (equation, align, etc.) =====
        // Replace equation environment with \[ \] display math
        cleaned = replaceEnvironment(in: cleaned, name: "equation", removeAlignMarkers: false)
        
        // Replace align environment with \[ \] display math (remove & markers)
        cleaned = replaceEnvironment(in: cleaned, name: "align", removeAlignMarkers: true)
        
        // Replace gather environment with \[ \] display math
        cleaned = replaceEnvironment(in: cleaned, name: "gather", removeAlignMarkers: false)
        
        // Replace multline environment with \[ \] display math
        cleaned = replaceEnvironment(in: cleaned, name: "multline", removeAlignMarkers: false)
        
        // Remove other specific unsupported environments (but preserve document, itemize, enumerate)
        let unsupportedEnvs = ["figure", "table", "tabular", "tikzpicture", "minipage", "verbatim", "lstlisting"]
        for env in unsupportedEnvs {
            cleaned = cleaned.replacingOccurrences(
                of: #"\\begin\{\#(env)\*?\}[\s\S]*?\\end\{\#(env)\*?\}"#,
                with: "[Environment '\(env)' removed - not supported]",
                options: .regularExpression
            )
        }
        
        // Remove multiple blank lines
        cleaned = cleaned.replacingOccurrences(of: #"\n\n\n+"#, with: "\n\n", options: .regularExpression)
        
        return cleaned
    }
    
    private func replaceEnvironment(in text: String, name: String, removeAlignMarkers: Bool) -> String {
        let pattern = #"\\begin\{\#(name)\*?\}[\s\S]*?\\end\{\#(name)\*?\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        var result = text
        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            let matchRange = match.range
            let matchText = nsText.substring(with: matchRange)
            
            // Extract content between \begin and \end
            var content = matchText
                .replacingOccurrences(of: #"\\begin\{\#(name)\*?\}\s*"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s*\\end\{\#(name)\*?\}"#, with: "", options: .regularExpression)
            
            if removeAlignMarkers {
                content = content.replacingOccurrences(of: "&", with: "")
            }
            
            content = content
                .replacingOccurrences(of: #"\\\\"#, with: "\n", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let replacement = "\\[\n\(content)\n\\]"
            
            if let range = Range(matchRange, in: result) {
                result = result.replacingCharacters(in: range, with: replacement)
            }
        }
        
        return result
    }
    
    // WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a bit for JavaScript to execute and render
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.createPDFFromWebView()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completion?(.failure(error))
        cleanup()
    }
    
    private func createPDFFromWebView() {
        let config = WKPDFConfiguration()
        config.rect = .zero // Use default page size
        
        webView.createPDF(configuration: config) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let data):
                if let pdfDocument = PDFDocument(data: data) {
                    print("[Renderer] PDF created successfully with \(pdfDocument.pageCount) page(s)")
                    self.completion?(.success(pdfDocument))
                } else {
                    self.completion?(.failure(LaTeXError.pdfCreationFailed))
                }
            case .failure(let error):
                self.completion?(.failure(error))
            }
            
            self.cleanup()
        }
    }
    
    private func cleanup() {
        renderTimeout?.invalidate()
        renderTimeout = nil
        completion = nil
    }
}

// MARK: - Error Types
enum LaTeXError: LocalizedError {
    case compilationFailed(String)
    case pdfCreationFailed
    case renderTimeout
    case invalidURL
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .compilationFailed(let message):
            return "LaTeX compilation failed:\n\(message)"
        case .pdfCreationFailed:
            return "Failed to create PDF from rendered HTML."
        case .renderTimeout:
            return "PDF rendering timeout. Document may be too complex."
        case .invalidURL:
            return "Invalid URL."
        case .invalidResponse:
            return "Invalid response."
        }
    }
}


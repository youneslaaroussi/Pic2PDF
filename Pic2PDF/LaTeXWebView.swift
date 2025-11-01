//
//  LaTeXWebView.swift
//  Pic2PDF
//

import SwiftUI
import WebKit
import PDFKit

struct LaTeXWebView: UIViewRepresentable {
    let latex: String
    let onWebViewReady: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "jsLog")
        controller.add(context.coordinator, name: "renderStatus")
        config.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        print("[LaTeXWebView] makeUIView, latex length=\(latex.count)")
        context.coordinator.load(latex: latex, in: webView)
        DispatchQueue.main.async { onWebViewReady?(webView) }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Re-render if LaTeX changes
        context.coordinator.load(latex: latex, in: uiView)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "jsLog", let msg = message.body as? String {
                print("[LaTeXWebView][JS] \(msg)")
            } else if message.name == "renderStatus", let msg = message.body as? String {
                print("[LaTeXWebView][Status] \(msg)")
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[LaTeXWebView] didStartProvisionalNavigation")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[LaTeXWebView] didFinish navigation")
        }

        func load(latex: String, in webView: WKWebView) {
            print("[LaTeXWebView] load() called, latex length: \(latex.count)")
            print("[LaTeXWebView] First 200 chars of latex: \(String(latex.prefix(200)))")
            
            // STRIP UNSUPPORTED PACKAGES AND COMMANDS
            let cleanedLatex = stripUnsupportedLaTeX(latex)
            print("[LaTeXWebView] After cleaning: \(String(cleanedLatex.prefix(200)))")
            
            // Standard JavaScript string escaping
            let escaped = cleanedLatex
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\"", with: "\\\"")

            let html = """
            <!DOCTYPE html>
            <html>
              <head>
                <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
                <meta charset=\"UTF-8\">
                <style>
                  body { margin: 12px; background: #fff; }
                </style>
                <script src=\"https://cdn.jsdelivr.net/npm/latex.js/dist/latex.js\"></script>
              </head>
              <body>
                <script>
                  (function(){
                    try {
                      const src = "\(escaped)";
                      const generator = new latexjs.HtmlGenerator({ hyphenate: false });
                      latexjs.parse(src, { generator: generator });
                      
                      // Inject styles and scripts using the LaTeX.js base URL
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
            
            print("[LaTeXWebView] ========== INJECTED HTML START ==========")
            print(html)
            print("[LaTeXWebView] ========== INJECTED HTML END ==========")

            webView.loadHTMLString(html, baseURL: nil)
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
    }
}

extension WKWebView {
    func exportPDF(completion: @escaping (Result<Data, Error>) -> Void) {
        let config = WKPDFConfiguration()
        self.createPDF(configuration: config) { result in
            switch result {
            case .success(let data): completion(.success(data))
            case .failure(let error): completion(.failure(error))
            }
        }
    }
}

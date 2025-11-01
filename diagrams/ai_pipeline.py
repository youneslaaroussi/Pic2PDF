#!/usr/bin/env python3
"""
Image-to-PDF AI Pipeline
Shows the complete processing flow with ARM optimizations
Outputs: out/ai_pipeline.svg
"""

from graphviz import Digraph

dot = Digraph('AI_Pipeline', comment='Image-to-PDF Pipeline')
dot.attr(rankdir='LR', bgcolor='white', fontname='Comic Sans MS', 
         fontcolor='#2c3e50', dpi='300', nodesep='0.6', ranksep='1.2')
dot.attr('node', shape='box', style='rounded,filled', fontname='Comic Sans MS', 
         fontsize='10', penwidth='2', margin='0.3,0.15',
         fillcolor='#fffef7', color='#2c3e50')
dot.attr('edge', fontname='Comic Sans MS', fontsize='9', 
         fontcolor='#2c3e50', penwidth='1.5', color='#2c3e50')

# Input
with dot.subgraph(name='cluster_input') as inp:
    inp.attr(label='1. Image Input', style='rounded,dashed', 
             color='#0066CC', fontsize='10', labelloc='t')
    inp.node('photos', 'PhotosPicker', fillcolor='#E8F4F8', width='1.8')
    inp.node('camera', 'Camera', fillcolor='#E8F4F8', width='1.8')
    inp.node('images', 'UIImage[]\nup to 10', fillcolor='#B3E0FF', width='1.8')

# ARM Preprocessing
with dot.subgraph(name='cluster_arm') as arm:
    arm.attr(label='2. ARM64 Preprocessing', style='rounded,dashed', 
             color='#FF6B35', fontsize='10', labelloc='t')
    arm.node('vimage', 'vImage\nAccelerate', fillcolor='#FFE0B2', width='1.8')
    arm.node('parallel', 'Parallel\nTaskGroup', fillcolor='#FFCC80', width='1.8')
    arm.node('downscaled', 'CGImage[]\n1024-1536px', fillcolor='#FFB74D', width='1.8')

# Vision Encoding
with dot.subgraph(name='cluster_vision') as vis:
    vis.attr(label='3. Vision Encoding', style='rounded,dashed', 
             color='#9C27B0', fontsize='10', labelloc='t')
    vis.node('encoder', 'Vision Encoder\nTFLite', fillcolor='#E1BEE7', width='1.8')
    vis.node('adapter', 'Vision Adapter\nTFLite', fillcolor='#CE93D8', width='1.8')

# Gemma Inference
with dot.subgraph(name='cluster_gemma') as gem:
    gem.attr(label='4. Gemma 3N Inference', style='rounded,dashed', 
             color='#527FFF', fontsize='10', labelloc='t')
    gem.node('gemma', 'Gemma 3N\nINT4 Quantized\n2B or 4B', fillcolor='#BBD7FF', width='2.0')
    gem.node('stream', 'Token Stream\n30fps Updates', fillcolor='#90CAF9', width='1.8')

# LaTeX Generation
with dot.subgraph(name='cluster_latex') as ltx:
    ltx.attr(label='5. LaTeX Generation', style='rounded,dashed', 
             color='#4CAF50', fontsize='10', labelloc='t')
    ltx.node('extract', 'Extract\nLaTeX', fillcolor='#C8E6C9', width='1.8')
    ltx.node('latex', 'LaTeX Code\nValidated', fillcolor='#A5D6A7', width='1.8')

# PDF Rendering
with dot.subgraph(name='cluster_pdf') as pdf:
    pdf.attr(label='6. Client-Side Rendering', style='rounded,dashed', 
             color='#E91E63', fontsize='10', labelloc='t')
    pdf.node('webview', 'WKWebView\n+ latex.js', fillcolor='#F8BBD0', width='1.8')
    pdf.node('pdfgen', 'createPDF()', fillcolor='#F48FB1', width='1.8')
    pdf.node('pdfout', 'PDFDocument', fillcolor='#EC407A', width='1.8', fontcolor='white')

# Storage
dot.node('storage', 'SwiftData\nStorage', fillcolor='#81C784', width='1.8', fontcolor='white')

# Flow connections
dot.edge('photos', 'images')
dot.edge('camera', 'images')
dot.edge('images', 'vimage', label='up to 5\nfor inference', color='#0066CC')

# ARM preprocessing
dot.edge('vimage', 'parallel', label='ARM64\nSIMD', color='#FF6B35', penwidth='2.5')
dot.edge('parallel', 'downscaled', label='30-70%\nreduction', color='#FF6B35')

# Vision encoding
dot.edge('downscaled', 'encoder', color='#9C27B0')
dot.edge('encoder', 'adapter', label='embeddings', color='#9C27B0')

# Gemma inference
dot.edge('adapter', 'gemma', label='vision\ninput', color='#527FFF', penwidth='2.5')
dot.edge('gemma', 'stream', label='INT4 ops\nARM64', color='#527FFF')

# LaTeX generation
dot.edge('stream', 'extract', color='#4CAF50')
dot.edge('extract', 'latex', label='strip\nmarkdown', color='#4CAF50')

# PDF rendering
dot.edge('latex', 'webview', label='inject\nHTML', color='#E91E63')
dot.edge('webview', 'pdfgen', label='compile', color='#E91E63')
dot.edge('pdfgen', 'pdfout', color='#E91E63', penwidth='2')

# Storage
dot.edge('latex', 'storage', label='persist', color='#4CAF50', style='dashed')
dot.edge('pdfout', 'storage', label='persist', color='#E91E63', style='dashed')

dot.render('out/ai_pipeline', format='svg', cleanup=True)
print("✅ ai_pipeline.svg")

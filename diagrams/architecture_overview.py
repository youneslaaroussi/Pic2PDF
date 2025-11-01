#!/usr/bin/env python3
"""
System Architecture Overview
Shows the layered architecture of Pic2PDF iOS app
Outputs: out/architecture_overview.svg
"""

from graphviz import Digraph

dot = Digraph('Pic2PDF_Architecture', comment='System Architecture')
dot.attr(rankdir='TB', bgcolor='white', fontname='Comic Sans MS', 
         fontcolor='#2c3e50', dpi='300', nodesep='0.7', ranksep='1.0')
dot.attr('node', shape='box', style='rounded,filled', fontname='Comic Sans MS', 
         fontsize='10', penwidth='2', margin='0.3,0.15',
         fillcolor='#fffef7', color='#2c3e50')
dot.attr('edge', fontname='Comic Sans MS', fontsize='9', 
         fontcolor='#2c3e50', penwidth='1.5', color='#2c3e50')

# Presentation Layer
with dot.subgraph(name='cluster_ui') as ui:
    ui.attr(label='Presentation Layer (SwiftUI)', style='rounded,dashed', 
            color='#0066CC', fontsize='11', labelloc='t')
    ui.node('tabview', 'TabView\nMain Container', fillcolor='#E8F4F8', width='2.0')
    ui.node('generate', 'MainGenerationView\nPhoto Selection', fillcolor='#B3E0FF', width='2.2')
    ui.node('history', 'HistoryView\nPast Generations', fillcolor='#B3E0FF', width='2.2')
    ui.node('stats', 'StatsView\nAnalytics', fillcolor='#B3E0FF', width='2.2')
    ui.node('settings', 'SettingsView\nConfiguration', fillcolor='#B3E0FF', width='2.2')

# Business Logic Layer
with dot.subgraph(name='cluster_logic') as logic:
    logic.attr(label='Business Logic Layer', style='rounded,dashed', 
               color='#527FFF', fontsize='11', labelloc='t')
    logic.node('llm', 'OnDeviceLLMService\nGemma 3N Inference', fillcolor='#BBD7FF', width='2.4')
    logic.node('renderer', 'LaTeXRenderer\nWKWebView + latex.js', fillcolor='#BBD7FF', width='2.4')
    logic.node('downloader', 'ModelDownloadManager\nR2 Downloads', fillcolor='#BBD7FF', width='2.4')

# Data Layer
with dot.subgraph(name='cluster_data') as data:
    data.attr(label='Data Layer (SwiftData)', style='rounded,dashed', 
              color='#33AA55', fontsize='11', labelloc='t')
    data.node('storage', 'StorageManager\nPersistence', fillcolor='#C8E6C9', width='2.2')
    data.node('generation', 'Generation Model\nLaTeX + Images', fillcolor='#A5D6A7', width='2.2')
    data.node('refinement', 'RefinementEntry\nFeedback History', fillcolor='#A5D6A7', width='2.2')

# External Dependencies
with dot.subgraph(name='cluster_external') as ext:
    ext.attr(label='External Dependencies', style='rounded,dashed', 
             color='#FF9800', fontsize='11', labelloc='t')
    ext.node('mediapipe', 'MediaPipe\nTasks GenAI 0.10.24', fillcolor='#FFE0B2', width='2.4')
    ext.node('accelerate', 'Accelerate\nvImage (ARM64)', fillcolor='#FFE0B2', width='2.4')
    ext.node('zip', 'ZIPFoundation\nVision Extract', fillcolor='#FFE0B2', width='2.4')

# UI flow
dot.edge('tabview', 'generate')
dot.edge('tabview', 'history')
dot.edge('tabview', 'stats')
dot.edge('tabview', 'settings')

# Generation flow
dot.edge('generate', 'llm', label='images[]', color='#0066CC', penwidth='2')
dot.edge('llm', 'generate', label='stream\nLaTeX', color='#0066CC', style='dashed')
dot.edge('generate', 'renderer', label='LaTeX', color='#9C27B0')
dot.edge('renderer', 'generate', label='PDF', color='#9C27B0', style='dashed')

# Storage flow
dot.edge('generate', 'storage', label='save', color='#33AA55', penwidth='2')
dot.edge('history', 'storage', label='load', color='#33AA55', style='dashed')
dot.edge('storage', 'generation', label='manage')
dot.edge('storage', 'refinement', label='manage')

# Model management
dot.edge('settings', 'downloader', label='download/\nswitch', color='#FF9800')
dot.edge('downloader', 'llm', label='model\nfiles', color='#FF9800', style='dashed')

# LLM dependencies
dot.edge('llm', 'mediapipe', label='inference', color='#527FFF')
dot.edge('llm', 'accelerate', label='downscale', color='#527FFF')
dot.edge('llm', 'zip', label='extract', color='#527FFF')

# Metrics
dot.edge('llm', 'stats', label='real-time\nmetrics', color='#DD4477', style='dotted')

dot.render('out/architecture_overview', format='svg', cleanup=True)
print("✅ architecture_overview.svg")


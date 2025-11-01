#!/usr/bin/env python3
"""
Complete Data Flow
Shows all major data paths through the system
Outputs: out/data_flow.svg
"""

from graphviz import Digraph

dot = Digraph('Data_Flow', comment='Complete Data Flow')
dot.attr(rankdir='TB', bgcolor='white', fontname='Comic Sans MS', 
         fontcolor='#2c3e50', dpi='300', nodesep='0.6', ranksep='0.9')
dot.attr('node', shape='box', style='rounded,filled', fontname='Comic Sans MS', 
         fontsize='10', penwidth='2', margin='0.3,0.15',
         fillcolor='#fffef7', color='#2c3e50')
dot.attr('edge', fontname='Comic Sans MS', fontsize='9', 
         fontcolor='#2c3e50', penwidth='1.5', color='#2c3e50')

# Path 1: Generation
with dot.subgraph(name='cluster_gen') as gen:
    gen.attr(label='Path 1: Image → LaTeX → PDF', style='rounded,dashed', 
             color='#0066CC', fontsize='11', labelloc='t')
    gen.node('input', 'User Input\nPhotos/Camera', fillcolor='#E8F4F8', width='2.0')
    gen.node('llm_gen', 'OnDeviceLLMService\n.generateLaTeX()', fillcolor='#B3E0FF', width='2.4')
    gen.node('latex', 'LaTeX String', fillcolor='#90CAF9', width='2.0')
    gen.node('renderer', 'LaTeXRenderer\n.renderLaTeXToPDF()', fillcolor='#64B5F6', width='2.4')
    gen.node('pdf', 'PDFDocument', fillcolor='#42A5F5', width='2.0', fontcolor='white')

# Path 2: Refinement
with dot.subgraph(name='cluster_refine') as refine:
    refine.attr(label='Path 2: LaTeX Refinement', style='rounded,dashed', 
                color='#9C27B0', fontsize='11', labelloc='t')
    refine.node('existing', 'Existing LaTeX\nfrom Generation', fillcolor='#E1BEE7', width='2.2')
    refine.node('feedback', 'User Feedback\nText Input', fillcolor='#E1BEE7', width='2.2')
    refine.node('llm_refine', 'OnDeviceLLMService\n.refineLaTeX()', fillcolor='#CE93D8', width='2.4')
    refine.node('refined', 'Refined LaTeX', fillcolor='#BA68C8', width='2.0')

# Path 3: Model Management
with dot.subgraph(name='cluster_model') as model:
    model.attr(label='Path 3: Model Management', style='rounded,dashed', 
               color='#FF9800', fontsize='11', labelloc='t')
    model.node('settings', 'SettingsView\nDownload Request', fillcolor='#FFE0B2', width='2.2')
    model.node('downloader', 'Model Download\nManager', fillcolor='#FFCC80', width='2.2')
    model.node('r2', 'Cloudflare R2\nHTTPS Download', fillcolor='#FFB74D', width='2.2')
    model.node('local', 'Documents/\nmodels/*.task', fillcolor='#FFA726', width='2.2')
    model.node('init', 'OnDeviceLLMService\n.initializeModel()', fillcolor='#FF9800', width='2.4')
    model.node('extract', 'ZIPFoundation\nExtract Vision', fillcolor='#FB8C00', width='2.2')
    model.node('cache', 'AppSupport/\nVision Models', fillcolor='#F57C00', width='2.2')

# Storage
with dot.subgraph(name='cluster_storage') as storage:
    storage.attr(label='SwiftData Storage', style='rounded,dashed', 
                 color='#4CAF50', fontsize='11', labelloc='t')
    storage.node('mgr', 'StorageManager', fillcolor='#C8E6C9', width='2.0')
    storage.node('gen_model', 'Generation Model\nimages, latex, pdf', fillcolor='#A5D6A7', width='2.4')
    storage.node('ref_model', 'RefinementEntry\nfeedback, history', fillcolor='#A5D6A7', width='2.4')

# Path 4: History
with dot.subgraph(name='cluster_history') as history:
    history.attr(label='Path 4: History Access', style='rounded,dashed', 
                 color='#E91E63', fontsize='11', labelloc='t')
    history.node('hist_view', 'HistoryView', fillcolor='#F8BBD0', width='2.0')
    history.node('search', 'Search Query\n(optional)', fillcolor='#F8BBD0', width='2.0')
    history.node('results', 'Sorted Results\nby timestamp', fillcolor='#F48FB1', width='2.2')

# Path 1 flow
dot.edge('input', 'llm_gen', label='images[]', color='#0066CC', penwidth='2.5')
dot.edge('llm_gen', 'latex', label='stream', color='#0066CC', penwidth='2.5')
dot.edge('latex', 'renderer', label='on-demand', color='#0066CC')
dot.edge('renderer', 'pdf', label='create', color='#0066CC')
dot.edge('latex', 'mgr', label='auto-save', color='#4CAF50', penwidth='2')
dot.edge('pdf', 'mgr', label='auto-save', color='#4CAF50', penwidth='2')
dot.edge('mgr', 'gen_model', label='persist', color='#4CAF50')

# Path 2 flow
dot.edge('existing', 'llm_refine', color='#9C27B0')
dot.edge('feedback', 'llm_refine', color='#9C27B0')
dot.edge('llm_refine', 'refined', label='text-only\ninference', color='#9C27B0', penwidth='2')
dot.edge('refined', 'mgr', label='update', color='#4CAF50')
dot.edge('mgr', 'ref_model', label='append', color='#4CAF50')
dot.edge('ref_model', 'gen_model', label='linked', style='dashed', color='#4CAF50')

# Path 3 flow
dot.edge('settings', 'downloader', label='download', color='#FF9800', penwidth='2')
dot.edge('downloader', 'r2', label='HTTP GET', color='#FF9800')
dot.edge('r2', 'local', label='.task file', color='#FF9800')
dot.edge('local', 'init', label='initialize', color='#FF9800', penwidth='2')
dot.edge('init', 'extract', label='extract', color='#FF9800')
dot.edge('extract', 'cache', label='TF_LITE_*', color='#FF9800')
dot.edge('cache', 'llm_gen', label='load for\ninference', style='dashed', color='#527FFF')

# Path 4 flow
dot.edge('hist_view', 'mgr', label='load', color='#E91E63')
dot.edge('search', 'mgr', label='filter', color='#E91E63', style='dashed')
dot.edge('mgr', 'gen_model', label='query', color='#E91E63', style='dotted')
dot.edge('gen_model', 'results', label='fetch', color='#E91E63')

# Metrics side channel
dot.edge('llm_gen', 'hist_view', label='metrics', style='dotted', color='#2c3e50', constraint='false')
dot.edge('llm_refine', 'hist_view', label='metrics', style='dotted', color='#2c3e50', constraint='false')

dot.render('out/data_flow', format='svg', cleanup=True)
print("✅ data_flow.svg")


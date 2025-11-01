#!/usr/bin/env python3
"""
ARM64 Optimizations
Highlights ARM-specific optimizations in the application
Outputs: out/arm_optimizations.svg
"""

from graphviz import Digraph

dot = Digraph('ARM64_Optimizations', comment='ARM64 Optimizations')
dot.attr(rankdir='TB', bgcolor='white', fontname='Comic Sans MS', 
         fontcolor='#2c3e50', dpi='300', nodesep='0.7', ranksep='1.0')
dot.attr('node', shape='box', style='rounded,filled', fontname='Comic Sans MS', 
         fontsize='10', penwidth='2', margin='0.3,0.15',
         fillcolor='#fffef7', color='#2c3e50')
dot.attr('edge', fontname='Comic Sans MS', fontsize='9', 
         fontcolor='#2c3e50', penwidth='1.5', color='#2c3e50')

# vImage preprocessing
with dot.subgraph(name='cluster_vimage') as vim:
    vim.attr(label='vImage Preprocessing (Accelerate)', style='rounded,dashed', 
             color='#FF6B35', fontsize='11', labelloc='t')
    vim.node('input', 'Input Images\nup to 10', fillcolor='#FFE0B2', width='2.0')
    vim.node('taskgroup', 'Parallel TaskGroup\nPriority: userInitiated', fillcolor='#FFCC80', width='2.4')
    vim.node('vimage_scale', 'vImageScale_ARGB8888\nARM NEON SIMD', fillcolor='#FFB74D', width='2.4')
    vim.node('output', 'Downscaled CGImage\n30-70% reduction', fillcolor='#FFA726', width='2.4', fontcolor='white')

# Model quantization
with dot.subgraph(name='cluster_quant') as quant:
    quant.attr(label='Model Quantization', style='rounded,dashed', 
               color='#9C27B0', fontsize='11', labelloc='t')
    quant.node('fp16', 'FP16 Model\n~2GB (2B)\n~3.6GB (4B)', fillcolor='#E1BEE7', width='2.2')
    quant.node('int4', 'INT4 Quantization\n4-bit integers', fillcolor='#CE93D8', width='2.2')
    quant.node('compressed', 'Gemma 3N INT4\n~500MB (2B)\n~900MB (4B)', fillcolor='#BA68C8', width='2.4', fontcolor='white')

# Performance tuning
with dot.subgraph(name='cluster_perf') as perf:
    perf.attr(label='Performance Mode Tuning', style='rounded,dashed', 
              color='#0066CC', fontsize='11', labelloc='t')
    perf.node('mode', 'Performance Mode\nUserDefaults', fillcolor='#E8F4F8', width='2.2')
    perf.node('tokens', 'Max Tokens\n1200 / 2000', fillcolor='#B3E0FF', width='2.0')
    perf.node('size', 'Image Size\n1024 / 1536px', fillcolor='#B3E0FF', width='2.0')
    perf.node('sampling', 'Sampling\ntopK/topP/temp', fillcolor='#B3E0FF', width='2.0')

# Thermal management
with dot.subgraph(name='cluster_thermal') as therm:
    therm.attr(label='Thermal Management', style='rounded,dashed', 
               color='#E91E63', fontsize='11', labelloc='t')
    therm.node('monitor', 'ProcessInfo\n.thermalState', fillcolor='#F8BBD0', width='2.2')
    therm.node('nominal', 'Nominal\nFull Speed', fillcolor='#C8E6C9', width='1.6')
    therm.node('fair', 'Fair\n+3°C', fillcolor='#FFF9C4', width='1.6')
    therm.node('serious', 'Serious\n+8°C', fillcolor='#FFCC80', width='1.6')
    therm.node('critical', 'Critical\n+12°C', fillcolor='#FFAB91', width='1.6')

# Real-time metrics
with dot.subgraph(name='cluster_metrics') as metr:
    metr.attr(label='Real-Time Metrics', style='rounded,dashed', 
              color='#4CAF50', fontsize='11', labelloc='t')
    metr.node('timer', 'Timer\n1s interval', fillcolor='#C8E6C9', width='1.8')
    metr.node('memory', 'Memory\nResident MB', fillcolor='#A5D6A7', width='1.8')
    metr.node('cpu', 'CPU Usage\n%', fillcolor='#A5D6A7', width='1.8')
    metr.node('battery', 'Battery\nImpact', fillcolor='#A5D6A7', width='1.8')

# vImage flow
dot.edge('input', 'taskgroup', label='parallelize', color='#FF6B35')
dot.edge('taskgroup', 'vimage_scale', label='ARM64\nSIMD', color='#FF6B35', penwidth='2.5')
dot.edge('vimage_scale', 'output', label='fast\nresize', color='#FF6B35', penwidth='2.5')

# Quantization flow
dot.edge('fp16', 'int4', label='quantize', color='#9C27B0', penwidth='2.5')
dot.edge('int4', 'compressed', label='4x\ncompression', color='#9C27B0', penwidth='2.5')

# Performance tuning flow
dot.edge('mode', 'tokens', label='configure', color='#0066CC')
dot.edge('mode', 'size', label='configure', color='#0066CC')
dot.edge('mode', 'sampling', label='configure', color='#0066CC')

# Thermal monitoring
dot.edge('monitor', 'nominal', color='#4CAF50')
dot.edge('monitor', 'fair', color='#FFC107')
dot.edge('monitor', 'serious', color='#FF9800')
dot.edge('monitor', 'critical', color='#F44336', penwidth='2')

# Metrics collection
dot.edge('timer', 'memory', label='poll', color='#4CAF50')
dot.edge('timer', 'cpu', label='poll', color='#4CAF50')
dot.edge('timer', 'battery', label='poll', color='#4CAF50')

# Connections between sections
dot.edge('output', 'compressed', label='feeds into\ninference', style='dashed', color='#2c3e50')
dot.edge('mode', 'size', label='affects', style='dashed', constraint='false', color='#2c3e50')
dot.edge('monitor', 'mode', label='adapts', style='dashed', color='#E91E63')

dot.render('out/arm_optimizations', format='svg', cleanup=True)
print("✅ arm_optimizations.svg")


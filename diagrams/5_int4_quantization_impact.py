#!/usr/bin/env python3
"""
INT4 Quantization Impact - Memory and performance benefits
"""
from graphviz import Digraph

def create_quantization_diagram():
    dot = Digraph(comment='INT4 Quantization Impact', engine='dot')
    dot.attr(rankdir='LR', splines='ortho', nodesep='1.0', ranksep='1.5')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightblue',
             fontname='Comic Sans MS', fontsize='11')
    dot.attr('edge', fontname='Comic Sans MS', fontsize='10')
    
    # FP16 baseline
    with dot.subgraph(name='cluster_fp16') as c:
        c.attr(label='FP16 Baseline (Not Used)', style='rounded,filled',
               fillcolor='#FFE6E6', fontname='Comic Sans MS', fontsize='12')
        c.node('fp16_model', 'Gemma 2B\nFP16 weights\n~4GB on disk\n16 bits/param',
               fillcolor='#FFB6C1')
        c.node('fp16_mem', 'Runtime Memory\n~5-6GB RAM\n(weights + activations)',
               fillcolor='#FFB6C1')
        c.node('fp16_perf', 'Performance\n~15 tok/s\niPhone 15 Pro',
               fillcolor='#FFB6C1')
    
    # INT4 quantized
    with dot.subgraph(name='cluster_int4') as c:
        c.attr(label='INT4 Quantized (Actual)', style='rounded,filled',
               fillcolor='#E6FFE6', fontname='Comic Sans MS', fontsize='12')
        c.node('int4_model', 'Gemma 2B\nINT4 weights\n~1GB on disk\n4 bits/param',
               fillcolor='#90EE90')
        c.node('int4_mem', 'Runtime Memory\n~1.5-2GB RAM\n4× reduction',
               fillcolor='#90EE90')
        c.node('int4_perf', 'Performance\n~40-50 tok/s\niPhone 15 Pro',
               fillcolor='#90EE90')
    
    # Quantization process
    with dot.subgraph(name='cluster_quant') as c:
        c.attr(label='Quantization Process', style='rounded,filled',
               fillcolor='#FFF8DC', fontname='Comic Sans MS', fontsize='12')
        c.node('scale', 'Per-channel scaling\nW_int4 = round(W_fp16 / scale)',
               fillcolor='#FAFAD2')
        c.node('lookup', 'Dequant lookup tables\nStored with model',
               fillcolor='#FAFAD2')
        c.node('runtime', 'Runtime dequantization\nINT4 → FP16 on-the-fly\nCached in L1',
               fillcolor='#FAFAD2')
    
    # Benefits
    with dot.subgraph(name='cluster_benefits') as c:
        c.attr(label='ARM64 Benefits', style='rounded,filled',
               fillcolor='#E6F3FF', fontname='Comic Sans MS', fontsize='12')
        c.node('bandwidth', 'Memory Bandwidth\n4× less DRAM traffic\nFits in L2/L3 cache',
               fillcolor='#B0E0E6')
        c.node('battery', 'Power Efficiency\nLess DRAM access\nLower thermal load',
               fillcolor='#B0E0E6')
        c.node('latency', 'Lower Latency\nFaster weight loading\nBetter tok/s',
               fillcolor='#B0E0E6')
    
    # Flow
    dot.edge('fp16_model', 'scale', label='offline quantization', style='dashed')
    dot.edge('scale', 'lookup')
    dot.edge('lookup', 'int4_model')
    
    dot.edge('int4_model', 'runtime', label='load time')
    dot.edge('runtime', 'int4_mem', label='minimal overhead')
    dot.edge('int4_mem', 'int4_perf', label='inference')
    
    dot.edge('int4_mem', 'bandwidth', color='green')
    dot.edge('int4_mem', 'battery', color='green')
    dot.edge('int4_perf', 'latency', color='green')
    
    # Comparison edges
    dot.edge('fp16_model', 'int4_model', label='4× compression', color='blue', 
             constraint='false', style='dashed')
    dot.edge('fp16_mem', 'int4_mem', label='4× RAM reduction', color='blue',
             constraint='false', style='dashed')
    dot.edge('fp16_perf', 'int4_perf', label='3× speedup', color='blue',
             constraint='false', style='dashed')
    
    return dot

if __name__ == '__main__':
    diagram = create_quantization_diagram()
    diagram.render('out/5_int4_quantization_impact', format='svg', cleanup=True)
    print("Generated: out/5_int4_quantization_impact.svg")


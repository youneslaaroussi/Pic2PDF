#!/usr/bin/env python3
"""
ARM64 Compute Pipeline - Shows how the app leverages ARM-specific optimizations
"""
from graphviz import Digraph

def create_arm64_pipeline():
    dot = Digraph(comment='ARM64 Compute Pipeline', engine='dot')
    dot.attr(rankdir='TB', splines='ortho', nodesep='0.8', ranksep='1.0')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightblue',
             fontname='Comic Sans MS', fontsize='11')
    dot.attr('edge', fontname='Comic Sans MS', fontsize='10')
    
    # Input layer
    dot.node('input', 'UIImage\n(RGBA, up to 4K)', fillcolor='lightgreen')
    
    # ARM64 Preprocessing subgraph
    with dot.subgraph(name='cluster_preprocessing') as c:
        c.attr(label='ARM64 Image Preprocessing', style='rounded,filled', 
               fillcolor='lightyellow', fontname='Comic Sans MS', fontsize='12')
        c.node('vimage', 'vImage (Accelerate)\nSIMD-optimized scaling\nARMv8 NEON instructions', 
               fillcolor='#FFE4B5')
        c.node('resize', 'Resize to 224×224\n~0.5ms on A17 Pro', fillcolor='#FFE4B5')
        c.node('normalize', 'Normalize [-1, 1]\nFP16 → INT8 quantization', fillcolor='#FFE4B5')
    
    # MediaPipe inference subgraph
    with dot.subgraph(name='cluster_mediapipe') as c:
        c.attr(label='MediaPipe Tasks GenAI', style='rounded,filled',
               fillcolor='#E6F3FF', fontname='Comic Sans MS', fontsize='12')
        c.node('vision_enc', 'Vision Encoder\n(TFLite, INT4 quantized)\nKleidiAI accelerated', 
               fillcolor='#B0E0E6')
        c.node('vision_adapt', 'Vision Adapter\n(Cross-attention)', fillcolor='#B0E0E6')
        c.node('gemma_llm', 'Gemma 3N LLM\n(2B/4B params, INT4)\nXNNPACK + SME2', 
               fillcolor='#B0E0E6')
    
    # ARM Backend subgraph
    with dot.subgraph(name='cluster_backend') as c:
        c.attr(label='ARM Compute Backend', style='rounded,filled',
               fillcolor='#FFE6E6', fontname='Comic Sans MS', fontsize='12')
        c.node('kleidiai', 'KleidiAI\nARM Kleidi library\nMatmul optimization', fillcolor='#FFB6C1')
        c.node('xnnpack', 'XNNPACK\nQuantized ops\nINT4/INT8 kernels', fillcolor='#FFB6C1')
        c.node('sme2', 'SME2 Compatible\nScalable Matrix Ext\n(A-series ready)', fillcolor='#FFB6C1')
    
    # Output
    dot.node('latex_output', 'LaTeX String\n~100-500 tokens', fillcolor='lightgreen')
    
    # Edges - main flow
    dot.edge('input', 'vimage')
    dot.edge('vimage', 'resize')
    dot.edge('resize', 'normalize')
    dot.edge('normalize', 'vision_enc', label='[224×224×3] tensor')
    dot.edge('vision_enc', 'vision_adapt', label='768-dim embeddings')
    dot.edge('vision_adapt', 'gemma_llm', label='Multimodal tokens')
    dot.edge('gemma_llm', 'latex_output', label='~2-8s inference')
    
    # Backend connections
    dot.edge('vision_enc', 'kleidiai', style='dashed', label='matmul', color='red')
    dot.edge('gemma_llm', 'xnnpack', style='dashed', label='quantized ops', color='red')
    dot.edge('gemma_llm', 'sme2', style='dashed', label='matrix ext', color='red')
    
    return dot

if __name__ == '__main__':
    diagram = create_arm64_pipeline()
    diagram.render('out/1_arm64_compute_pipeline', format='svg', cleanup=True)
    print("Generated: out/1_arm64_compute_pipeline.svg")


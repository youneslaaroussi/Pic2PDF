#!/usr/bin/env python3
"""
Multimodal Inference Flow - Detailed token-level flow through Gemma 3N
"""
from graphviz import Digraph

def create_multimodal_flow():
    dot = Digraph(comment='Multimodal Inference Flow', engine='dot')
    dot.attr(rankdir='LR', splines='ortho', nodesep='0.6', ranksep='1.2')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightblue',
             fontname='Comic Sans MS', fontsize='11')
    dot.attr('edge', fontname='Comic Sans MS', fontsize='10')
    
    # Input
    dot.node('img_in', 'Input Image\n224×224×3', fillcolor='lightgreen')
    
    # Vision processing
    with dot.subgraph(name='cluster_vision') as c:
        c.attr(label='Vision Processing (TFLite)', style='rounded,filled',
               fillcolor='#FFF8DC', fontname='Comic Sans MS', fontsize='12')
        c.node('encoder', 'SigLIP Encoder\n12 layers\nINT4 quantized\n~150ms', fillcolor='#FAFAD2')
        c.node('pool', 'Attention Pooling\n256 patches → 64 tokens', fillcolor='#FAFAD2')
    
    # Cross-modal fusion
    with dot.subgraph(name='cluster_adapter') as c:
        c.attr(label='Vision-Language Adapter', style='rounded,filled',
               fillcolor='#E6F3FF', fontname='Comic Sans MS', fontsize='12')
        c.node('cross_attn', 'Cross-Attention\n768-dim → 2048-dim\nLinear projection', 
               fillcolor='#B0E0E6')
        c.node('prefix', 'Multimodal Prefix\n64 vision tokens\n+\n32 prompt tokens', 
               fillcolor='#B0E0E6')
    
    # LLM generation
    with dot.subgraph(name='cluster_llm') as c:
        c.attr(label='Gemma 3N LLM (Autoregressive)', style='rounded,filled',
               fillcolor='#FFE6F0', fontname='Comic Sans MS', fontsize='12')
        c.node('embed', 'Token Embedding\n2048-dim', fillcolor='#FFB6C1')
        c.node('transformer', 'Transformer Stack\n18 layers (2B)\n26 layers (4B)\nMQA, RoPE',
               fillcolor='#FFB6C1')
        c.node('lm_head', 'LM Head\nSoftmax → token_id\n~256k vocab', fillcolor='#FFB6C1')
    
    # Output
    dot.node('latex_out', 'LaTeX Output\n~100-500 tokens\n2-8s total', fillcolor='lightgreen')
    
    # Main flow
    dot.edge('img_in', 'encoder')
    dot.edge('encoder', 'pool', label='[768] embeddings')
    dot.edge('pool', 'cross_attn', label='64 vision tokens')
    dot.edge('cross_attn', 'prefix', label='projected to LLM dim')
    dot.edge('prefix', 'embed', label='96 multimodal tokens')
    dot.edge('embed', 'transformer', label='[B, 96, 2048]')
    dot.edge('transformer', 'lm_head', label='hidden states')
    dot.edge('lm_head', 'latex_out', label='autoregressive\n~50 tok/s')
    
    # Feedback loop for autoregressive generation
    dot.edge('lm_head', 'embed', label='next token', style='dashed', color='blue',
             constraint='false')
    
    return dot

if __name__ == '__main__':
    diagram = create_multimodal_flow()
    diagram.render('out/2_multimodal_inference_flow', format='svg', cleanup=True)
    print("Generated: out/2_multimodal_inference_flow.svg")


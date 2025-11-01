#!/usr/bin/env python3
"""
MediaPipe Architecture - Integration with ARM compute backends
"""
from graphviz import Digraph

def create_mediapipe_arch():
    dot = Digraph(comment='MediaPipe Architecture', engine='dot')
    dot.attr(rankdir='TB', splines='ortho', nodesep='0.8', ranksep='1.0')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightblue',
             fontname='Comic Sans MS', fontsize='11')
    dot.attr('edge', fontname='Comic Sans MS', fontsize='10')
    
    # Swift application layer
    dot.node('swift_app', 'OnDeviceLLMService.swift\nSwift application', fillcolor='lightgreen')
    
    # MediaPipe Swift wrapper
    with dot.subgraph(name='cluster_wrapper') as c:
        c.attr(label='MediaPipeTasksGenAI (CocoaPod)', style='rounded,filled',
               fillcolor='#E6F3FF', fontname='Comic Sans MS', fontsize='12')
        c.node('llm_inf', 'LlmInference\nSwift class wrapper', fillcolor='#B0E0E6')
        c.node('options', 'LlmInferenceOptions\nmaxTokens\ntemperature\ntopK/topP',
               fillcolor='#B0E0E6')
    
    # C++ MediaPipe core
    with dot.subgraph(name='cluster_cpp') as c:
        c.attr(label='MediaPipe C++ Core', style='rounded,filled',
               fillcolor='#FFF8DC', fontname='Comic Sans MS', fontsize='12')
        c.node('task_runner', 'GenAI Task Runner\nGraph executor', fillcolor='#FAFAD2')
        c.node('tflite', 'TFLite Runtime\nModel interpreter\nDelegate dispatch',
               fillcolor='#FAFAD2')
    
    # TFLite delegates
    with dot.subgraph(name='cluster_delegates') as c:
        c.attr(label='TFLite Delegates', style='rounded,filled',
               fillcolor='#FFE6F0', fontname='Comic Sans MS', fontsize='12')
        c.node('xnn_del', 'XNNPACK Delegate\nCPU-optimized ops\nINT4/INT8 quantization',
               fillcolor='#FFB6C1')
        c.node('kleidi_del', 'KleidiAI Integration\nARM Kleidi microkernels\nMatmul acceleration',
               fillcolor='#FFB6C1')
    
    # ARM hardware
    with dot.subgraph(name='cluster_hardware') as c:
        c.attr(label='ARM64 Hardware', style='rounded,filled',
               fillcolor='#E6E6FA', fontname='Comic Sans MS', fontsize='12')
        c.node('neon', 'NEON (ARMv8 SIMD)\n128-bit vectors\nFP16/INT8 arithmetic',
               fillcolor='#DDA0DD')
        c.node('sme2', 'SME2 (A-series)\nScalable Matrix Ext\n2D register arrays',
               fillcolor='#DDA0DD')
        c.node('cores', 'CPU Cores\nPerformance + Efficiency\nScheduled by OS',
               fillcolor='#DDA0DD')
    
    # Flow
    dot.edge('swift_app', 'llm_inf', label='addImage()\ngenerateResponse()')
    dot.edge('swift_app', 'options', label='configure')
    dot.edge('llm_inf', 'task_runner', label='C++ bridge')
    dot.edge('options', 'task_runner')
    dot.edge('task_runner', 'tflite', label='load .task model')
    dot.edge('tflite', 'xnn_del', label='delegate ops')
    dot.edge('tflite', 'kleidi_del', label='delegate matmul')
    
    dot.edge('xnn_del', 'neon', label='vectorized ops', color='red')
    dot.edge('xnn_del', 'cores', label='thread pool', color='red')
    dot.edge('kleidi_del', 'neon', label='optimized kernels', color='blue')
    dot.edge('kleidi_del', 'sme2', label='if available', style='dashed', color='blue')
    
    return dot

if __name__ == '__main__':
    diagram = create_mediapipe_arch()
    diagram.render('out/4_mediapipe_architecture', format='svg', cleanup=True)
    print("Generated: out/4_mediapipe_architecture.svg")


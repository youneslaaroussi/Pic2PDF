#!/usr/bin/env python3
"""
Memory & Thermal Management - Real-time monitoring and optimization
"""
from graphviz import Digraph

def create_thermal_management():
    dot = Digraph(comment='Memory & Thermal Management', engine='dot')
    dot.attr(rankdir='TB', splines='ortho', nodesep='0.7', ranksep='0.8')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightblue',
             fontname='Comic Sans MS', fontsize='11')
    dot.attr('edge', fontname='Comic Sans MS', fontsize='10')
    
    # Monitoring layer
    with dot.subgraph(name='cluster_monitoring') as c:
        c.attr(label='Real-Time Monitoring', style='rounded,filled',
               fillcolor='#E6FFE6', fontname='Comic Sans MS', fontsize='12')
        c.node('mach_task', 'mach_task_basic_info()\nResident memory (RSS)\nReal measurements', 
               fillcolor='#90EE90')
        c.node('thermal', 'ProcessInfo.thermalState\nNominal/Fair/Serious/Critical',
               fillcolor='#90EE90')
        c.node('battery', 'UIDevice.batteryLevel\nUIDevice.batteryState',
               fillcolor='#90EE90')
        c.node('signpost', 'os.signpost\nInstruments integration\nPerf profiling',
               fillcolor='#90EE90')
    
    # Analysis layer
    with dot.subgraph(name='cluster_analysis') as c:
        c.attr(label='Performance Analysis', style='rounded,filled',
               fillcolor='#FFF8DC', fontname='Comic Sans MS', fontsize='12')
        c.node('stats', 'ProcessMetrics\nMemory: ±10MB delta\nThermal: state changes',
               fillcolor='#FAFAD2')
        c.node('history', 'SwiftData Storage\nPer-generation metrics\nHistorical trends',
               fillcolor='#FAFAD2')
    
    # Decision layer
    with dot.subgraph(name='cluster_decisions') as c:
        c.attr(label='Adaptive Optimization', style='rounded,filled',
               fillcolor='#FFE6E6', fontname='Comic Sans MS', fontsize='12')
        c.node('mode_switch', 'Performance Mode\nBalanced/Power Saver',
               fillcolor='#FFB6C1')
        c.node('throttle', 'Thermal Throttling\nReduce maxTokens\nBatch size = 1',
               fillcolor='#FFB6C1')
        c.node('cache', 'Model Caching\nKeep in RAM\nvs. reload from disk',
               fillcolor='#FFB6C1')
    
    # Execution
    dot.node('inference', 'LlmInference\n(MediaPipe)\nRunning inference', fillcolor='#B0E0E6')
    
    # Flow
    dot.edge('inference', 'mach_task', label='continuous', style='dashed')
    dot.edge('inference', 'thermal', label='observe', style='dashed')
    dot.edge('inference', 'battery', label='poll', style='dashed')
    dot.edge('inference', 'signpost', label='log events', style='dashed')
    
    dot.edge('mach_task', 'stats')
    dot.edge('thermal', 'stats')
    dot.edge('battery', 'stats')
    dot.edge('signpost', 'stats')
    
    dot.edge('stats', 'history', label='persist')
    dot.edge('stats', 'mode_switch', label='threshold check')
    dot.edge('stats', 'throttle', label='if thermal > Fair')
    dot.edge('stats', 'cache', label='if memory < 2GB')
    
    dot.edge('mode_switch', 'inference', label='update config', color='blue')
    dot.edge('throttle', 'inference', label='reduce load', color='red')
    dot.edge('cache', 'inference', label='optimize I/O', color='green')
    
    return dot

if __name__ == '__main__':
    diagram = create_thermal_management()
    diagram.render('out/3_memory_thermal_management', format='svg', cleanup=True)
    print("Generated: out/3_memory_thermal_management.svg")


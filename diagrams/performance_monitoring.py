#!/usr/bin/env python3
"""
Performance Monitoring System
Shows metrics collection, aggregation, and display
Outputs: out/performance_monitoring.svg
"""

from graphviz import Digraph

dot = Digraph('Performance_Monitoring', comment='Performance Monitoring')
dot.attr(rankdir='LR', bgcolor='white', fontname='Comic Sans MS', 
         fontcolor='#2c3e50', dpi='300', nodesep='0.7', ranksep='1.2')
dot.attr('node', shape='box', style='rounded,filled', fontname='Comic Sans MS', 
         fontsize='10', penwidth='2', margin='0.3,0.15',
         fillcolor='#fffef7', color='#2c3e50')
dot.attr('edge', fontname='Comic Sans MS', fontsize='9', 
         fontcolor='#2c3e50', penwidth='1.5', color='#2c3e50')

# Metrics Collection
with dot.subgraph(name='cluster_collect') as collect:
    collect.attr(label='Metrics Collection', style='rounded,dashed', 
                 color='#4CAF50', fontsize='11', labelloc='t')
    collect.node('timer', 'Timer\n1s interval', fillcolor='#C8E6C9', width='1.8')
    collect.node('process', 'ProcessMetrics\nUtility', fillcolor='#A5D6A7', width='1.8')
    collect.node('memory_fn', 'currentResident\nMemoryMB()', fillcolor='#81C784', width='2.0')
    collect.node('cpu_fn', 'currentCPU\nUsage()', fillcolor='#81C784', width='2.0')
    collect.node('battery', 'UIDevice\nbatteryLevel', fillcolor='#81C784', width='2.0')
    collect.node('thermal', 'ProcessInfo\nthermalState', fillcolor='#81C784', width='2.0')

# Service State
with dot.subgraph(name='cluster_service') as service:
    service.attr(label='OnDeviceLLMService (@Published)', style='rounded,dashed', 
                 color='#527FFF', fontsize='11', labelloc='t')
    service.node('service', 'LLM Service\nSingleton', fillcolor='#BBD7FF', width='2.0')
    service.node('realtime', 'Real-Time:\nmemory, CPU,\nbattery, thermal,\ntokens/sec', fillcolor='#90CAF9', width='2.2')
    service.node('history', 'Historical:\ngenerationHistory[]\nlast 50', fillcolor='#64B5F6', width='2.2')

# Aggregation
with dot.subgraph(name='cluster_agg') as agg:
    agg.attr(label='Data Aggregation', style='rounded,dashed', 
             color='#9C27B0', fontsize='11', labelloc='t')
    agg.node('record', 'recordGeneration\nMetrics()', fillcolor='#E1BEE7', width='2.2')
    agg.node('metric', 'GenerationMetrics\ntimestamp, tokens,\ntime, memory', fillcolor='#CE93D8', width='2.4')
    agg.node('stats', 'Computed Stats:\navg time, avg tok/s,\npeak memory', fillcolor='#BA68C8', width='2.4')

# UI Display
with dot.subgraph(name='cluster_ui') as ui:
    ui.attr(label='UI Display Layer', style='rounded,dashed', 
            color='#FF9800', fontsize='11', labelloc='t')
    ui.node('statsview', 'StatsView\nCharts Framework', fillcolor='#FFE0B2', width='2.2')
    ui.node('charts', 'Line/Bar/Gauge\nCharts', fillcolor='#FFCC80', width='2.0')
    ui.node('overlay', 'Generation\nOverlay', fillcolor='#FFCC80', width='2.0')
    ui.node('cards', 'Metric Cards\n+ Sparklines', fillcolor='#FFCC80', width='2.0')

# Instruments
dot.node('instruments', 'Xcode Instruments\nOSLog Signposts', fillcolor='#F8BBD0', width='2.4', shape='ellipse')

# Collection flow
dot.edge('timer', 'process', label='trigger\nevery 1s', color='#4CAF50', penwidth='2')
dot.edge('process', 'memory_fn', color='#4CAF50')
dot.edge('process', 'cpu_fn', color='#4CAF50')

# Update service
dot.edge('memory_fn', 'service', label='update', color='#527FFF', penwidth='2')
dot.edge('cpu_fn', 'service', label='update', color='#527FFF', penwidth='2')
dot.edge('battery', 'service', label='notify', color='#527FFF')
dot.edge('thermal', 'service', label='notify', color='#527FFF')

# Service state
dot.edge('service', 'realtime', label='@Published', color='#527FFF')
dot.edge('service', 'history', label='@Published', color='#527FFF')

# Aggregation
dot.edge('service', 'record', label='after\ngeneration', color='#9C27B0')
dot.edge('record', 'metric', color='#9C27B0')
dot.edge('metric', 'history', label='append', color='#9C27B0', style='dashed')
dot.edge('history', 'stats', label='compute', color='#9C27B0')

# UI display
dot.edge('realtime', 'overlay', label='live\ndata', color='#FF9800', penwidth='2')
dot.edge('realtime', 'cards', label='live\ndata', color='#FF9800', penwidth='2')
dot.edge('history', 'statsview', label='historical\ndata', color='#FF9800', penwidth='2')
dot.edge('stats', 'statsview', label='aggregates', color='#FF9800')
dot.edge('statsview', 'charts', label='visualize', color='#FF9800')

# Instruments
dot.edge('service', 'instruments', label='signposts:\nModelInit,\nFirstToken', style='dotted', color='#E91E63')

dot.render('out/performance_monitoring', format='svg', cleanup=True)
print("✅ performance_monitoring.svg")


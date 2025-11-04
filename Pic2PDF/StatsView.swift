//
//  StatsView.swift
//  Pic2PDF
//
//  Created by AI Assistant on 2025-01-30.
//

import SwiftUI
import Charts
import UIKit

struct StatsView: View {
    @StateObject private var llmService = OnDeviceLLMService.shared

    // Chart data filters
    @State private var selectedTimeRange: TimeRange = .last10
    @State private var showBatteryImpact = true
    @State private var showMemoryUsage = true
    @State private var showTokenPerformance = true

    enum TimeRange: String, CaseIterable {
        case last5 = "Last 5"
        case last10 = "Last 10"
        case last20 = "Last 20"
        case all = "All"

        var maxCount: Int {
            switch self {
            case .last5: return 5
            case .last10: return 10
            case .last20: return 20
            case .all: return .max
            }
        }
    }

    var filteredMetrics: [GenerationMetrics] {
        let allMetrics = llmService.generationHistory
        let count = min(selectedTimeRange.maxCount, allMetrics.count)
        return Array(allMetrics.suffix(count))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("ARM AI Performance")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Real-time metrics from on-device AI")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)

                    // Quick Stats Grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                        StatCard(
                            title: "Total Generations",
                            value: "\(llmService.totalGenerations)",
                            icon: "number.circle.fill",
                            color: .blue
                        )

                        StatCard(
                            title: "Avg Generation Time",
                            value: String(format: "%.1fs", llmService.averageGenerationTime),
                            icon: "timer",
                            color: .green
                        )

                        StatCard(
                            title: "Avg Tokens/sec",
                            value: String(format: "%.1f", llmService.averageTokensPerSecond),
                            icon: "speedometer",
                            color: .purple
                        )

                        StatCard(
                            title: "Total Tokens",
                            value: "\(llmService.totalTokensGenerated)",
                            icon: "text.bubble.fill",
                            color: .orange
                        )

                        StatCard(
                            title: "Peak Memory",
                            value: String(format: "%.1f MB", llmService.peakMemoryUsage),
                            icon: "memorychip",
                            color: .red
                        )

                        StatCard(
                            title: "Battery Level",
                            value: "\(llmService.batteryLevel)%",
                            icon: "battery.100",
                            color: .green
                        )
                    }
                    .padding(.horizontal)

                    // Real-time Metrics Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Live System Metrics")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            MetricGauge(
                                title: "CPU",
                                value: llmService.cpuUsage,
                                maxValue: 100,
                                unit: "%",
                                color: .blue
                            )

                            MetricGauge(
                                title: "Memory",
                                value: llmService.currentMemoryUsage,
                                maxValue: max(llmService.peakMemoryUsage, 100),
                                unit: "MB",
                                color: .green
                            )

                            MetricGauge(
                                title: "Temp",
                                value: llmService.deviceTemperature,
                                maxValue: 60,
                                unit: "°C",
                                color: .red
                            )
                        }
                        .padding(.horizontal)

                        // Thermal State Indicator
                        HStack(spacing: 12) {
                            Text("Thermal State:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ThermalStateBadge(state: llmService.thermalState)
                            Spacer()
                            Text(UIDevice.current.model)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }

                    // Charts Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Performance Trends")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Spacer()

                            Picker("Range", selection: $selectedTimeRange) {
                                ForEach(TimeRange.allCases, id: \.self) { range in
                                    Text(range.rawValue).tag(range)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal)

                        if !filteredMetrics.isEmpty {
                            // Generation Time Chart
                            ChartCard(title: "Generation Time") {
                                Chart(filteredMetrics) { metric in
                                    LineMark(
                                        x: .value("Time", metric.timestamp),
                                        y: .value("Time (s)", metric.generationTime)
                                    )
                                    .foregroundStyle(.blue)
                                    .symbol(.circle)
                                }
                                .frame(height: 140)
                                .chartYAxisLabel("Seconds", position: .leading)
                            }

                            // Tokens per Second Chart
                            ChartCard(title: "Token Generation Rate") {
                                Chart(filteredMetrics) { metric in
                                    BarMark(
                                        x: .value("Generation", metric.timestamp),
                                        y: .value("Tokens/sec", metric.tokensPerSecond)
                                    )
                                    .foregroundStyle(.purple)
                                }
                                .frame(height: 140)
                                .chartYAxisLabel("Tok/s", position: .leading)
                            }

                            // Memory Usage Over Time
                            ChartCard(title: "Memory Usage") {
                                Chart(filteredMetrics) { metric in
                                    AreaMark(
                                        x: .value("Time", metric.timestamp),
                                        y: .value("Memory (MB)", metric.memoryUsageMB)
                                    )
                                    .foregroundStyle(.linearGradient(
                                        colors: [.green.opacity(0.3), .green],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    ))
                                }
                                .frame(height: 140)
                                .chartYAxisLabel("MB", position: .leading)
                            }

                            // Battery Impact Chart
                            ChartCard(title: "Battery Impact") {
                                Chart(filteredMetrics) { metric in
                                    PointMark(
                                        x: .value("Generation", metric.timestamp),
                                        y: .value("Battery Drain", metric.batteryLevelBefore - metric.batteryLevelAfter)
                                    )
                                    .foregroundStyle(.orange)
                                    .symbol(.triangle)
                                }
                                .frame(height: 140)
                                .chartYAxisLabel("%", position: .leading)
                            }
                        } else {
                            VStack {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No performance data yet")
                                    .foregroundColor(.secondary)
                                Text("Generate some PDFs to see metrics!")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 200)
                        }
                    }

                    // Model Information
                    InfoSection(title: "Model & System") {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(label: "Current Model", value: llmService.currentModelInfo.isInitialized ? llmService.currentModelInfo.identifier.displayName : "Not loaded")
                            InfoRow(label: "Model Size", value: llmService.currentModelInfo.identifier == .gemma2B ? "~2B parameters" : "~4B parameters")
                            InfoRow(label: "Init Time", value: String(format: "%.2fs", llmService.modelInitializationTime))
                            Divider()
                            InfoRow(label: "iOS Version", value: UIDevice.current.systemVersion)
                            InfoRow(label: "Device", value: UIDevice.current.model)
                            InfoRow(label: "Architecture", value: "ARM64")
                        }
                    }

                    // Usage Statistics (Credits section removed as per task 2)
                    InfoSection(title: "Usage Statistics") {
                        VStack(alignment: .leading, spacing: 10) {
                            InfoRow(label: "AI Generations", value: "\(llmService.totalGenerations)")
                            InfoRow(label: "PDF Compilations", value: "\(llmService.generationHistory.count)")
                            InfoRow(label: "Total Tokens", value: "\(llmService.totalTokensGenerated)")
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("AI Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct MetricGauge: View {
    let title: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color

    var percentage: Double {
        min(value / maxValue, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
            }

            Text(String(format: "%.1f\(unit)", value))
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ThermalStateBadge: View {
    let state: ProcessInfo.ThermalState

    var color: Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        @unknown default: return .gray
        }
    }

    var text: String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// Chart container with consistent styling
struct ChartCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// Info section container
struct InfoSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// Technical detail row
struct TechDetail: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text(text)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    StatsView()
}

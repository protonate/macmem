//
//  ContentView.swift
//  MemoryMonitor
//
//  Main dashboard view
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var metricsCollector: MetricsCollector
    @State private var selectedTimeRange: TimeRange = .oneHour

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Memory Monitor")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                if let metrics = metricsCollector.currentMetrics {
                    Text("Last updated: \(formatTime(metrics.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: {
                    if metricsCollector.isCollecting {
                        metricsCollector.stopCollecting()
                    } else {
                        metricsCollector.startCollecting()
                    }
                }) {
                    Image(systemName: metricsCollector.isCollecting ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(metricsCollector.isCollecting ? .orange : .green)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            ScrollView {
                VStack(spacing: 20) {
                    // Real-time gauges
                    if let metrics = metricsCollector.currentMetrics {
                        gaugesSection(metrics: metrics)
                    } else {
                        Text("Waiting for data...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    Divider()

                    // Thrashing indicator
                    if let thrashing = metricsCollector.thrashingMetrics {
                        thrashingSection(thrashing: thrashing)
                    }

                    Divider()

                    // Top thrashing processes
                    ThrashingProcessesView(processes: metricsCollector.topThrashingProcesses)

                    Divider()

                    // Time-series charts
                    chartsSection()
                }
                .padding()
            }
        }
        .onAppear {
            metricsCollector.startCollecting()
        }
    }

    private func gaugesSection(metrics: SystemMetrics) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Real-Time Metrics")
                .font(.title2)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                MetricGaugeView(
                    title: "Swap Used",
                    value: metrics.swapUsed,
                    unit: "MB",
                    max: metrics.swapTotal,
                    alertLevel: metrics.swapAlertLevel
                )

                MetricGaugeView(
                    title: "WindowServer",
                    value: metrics.windowServerMemory,
                    unit: "MB",
                    max: 2048,
                    alertLevel: metrics.windowServerAlertLevel
                )

                MetricGaugeView(
                    title: "Compressor",
                    value: metrics.compressorSizeMB,
                    unit: "MB",
                    max: 4096,
                    alertLevel: metrics.compressorAlertLevel
                )

                MetricGaugeView(
                    title: "Free Memory",
                    value: metrics.freeMemoryMB,
                    unit: "MB",
                    max: 8192,
                    alertLevel: metrics.freeMemoryAlertLevel,
                    reverseColors: true
                )

                MetricGaugeView(
                    title: "Load Average (1m)",
                    value: metrics.loadAverage1m,
                    unit: "",
                    max: 8.0,
                    alertLevel: metrics.loadAlertLevel
                )

                MetricGaugeView(
                    title: "Swap Usage",
                    value: metrics.swapUsedPercent,
                    unit: "%",
                    max: 100,
                    alertLevel: metrics.swapAlertLevel
                )
            }

            // Detailed stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Detailed Statistics")
                    .font(.headline)
                    .padding(.top)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(label: "Pages Free", value: formatPages(metrics.pagesFree))
                        StatRow(label: "Pages Active", value: formatPages(metrics.pagesActive))
                        StatRow(label: "Pages Wired", value: formatPages(metrics.pagesWired))
                        StatRow(label: "Pages Compressed", value: formatPages(metrics.pagesCompressed))
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(label: "Swap Ins", value: "\(formatNumber(metrics.swapins))")
                        StatRow(label: "Swap Outs", value: "\(formatNumber(metrics.swapouts))")
                        StatRow(label: "Compressions", value: "\(formatNumber(metrics.compressions))")
                        StatRow(label: "Decompressions", value: "\(formatNumber(metrics.decompressions))")
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        StatRow(label: "Load Avg (1m)", value: String(format: "%.2f", metrics.loadAverage1m))
                        StatRow(label: "Load Avg (5m)", value: String(format: "%.2f", metrics.loadAverage5m))
                        StatRow(label: "Load Avg (15m)", value: String(format: "%.2f", metrics.loadAverage15m))
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func thrashingSection(thrashing: ThrashingMetrics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Memory Thrashing")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if thrashing.isThrashing {
                    AlertBadgeView(level: .critical, text: thrashing.thrashingLevel)
                } else {
                    AlertBadgeView(level: .normal, text: "None")
                }
            }

            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Text("Swap-in Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", thrashing.swapinRate)) pages/sec")
                        .font(.headline)
                }

                VStack(alignment: .leading) {
                    Text("Swap-out Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(String(format: "%.1f", thrashing.swapoutRate)) pages/sec")
                        .font(.headline)
                }

                if thrashing.isThrashing {
                    VStack(alignment: .leading) {
                        Text("Warning")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("System is thrashing!")
                            .font(.headline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .background(thrashing.isThrashing ? Color.red.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    private func chartsSection() -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Historical Trends")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Picker("Time Range", selection: $selectedTimeRange) {
                    Text("15 min").tag(TimeRange.fifteenMinutes)
                    Text("1 hour").tag(TimeRange.oneHour)
                    Text("6 hours").tag(TimeRange.sixHours)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            if !metricsCollector.metricsHistory.isEmpty {
                ChartView(
                    title: "Swap Usage",
                    data: getFilteredData(),
                    keyPath: \.swapUsed,
                    color: .orange,
                    unit: "MB"
                )

                ChartView(
                    title: "WindowServer Memory",
                    data: getFilteredData(),
                    keyPath: \.windowServerMemory,
                    color: .blue,
                    unit: "MB"
                )

                ChartView(
                    title: "Compressor Size",
                    data: getFilteredData(),
                    keyPath: \.compressorSizeMB,
                    color: .purple,
                    unit: "MB"
                )

                ChartView(
                    title: "Free Memory",
                    data: getFilteredData(),
                    keyPath: \.freeMemoryMB,
                    color: .green,
                    unit: "MB"
                )

                ChartView(
                    title: "Load Average (1m)",
                    data: getFilteredData(),
                    keyPath: \.loadAverage1m,
                    color: .red,
                    unit: ""
                )
            } else {
                Text("Collecting data...")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private func getFilteredData() -> [SystemMetrics] {
        let cutoff = Date().addingTimeInterval(-selectedTimeRange.seconds)
        return metricsCollector.metricsHistory.filter { $0.timestamp >= cutoff }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    private func formatPages(_ pages: Int64) -> String {
        let mb = Double(pages) * 16384.0 / 1024.0 / 1024.0
        return String(format: "%.1f MB", mb)
    }

    private func formatNumber(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

struct StatRow: View {
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
    }
}

enum TimeRange {
    case fifteenMinutes
    case oneHour
    case sixHours

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .sixHours: return 6 * 60 * 60
        }
    }
}

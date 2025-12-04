//
//  MetricGaugeView.swift
//  MemoryMonitor
//
//  Reusable gauge component for displaying metrics
//

import SwiftUI

struct MetricGaugeView: View {
    let title: String
    let value: Double
    let unit: String
    let max: Double
    let alertLevel: AlertLevel
    var reverseColors: Bool = false

    private var percentage: Double {
        guard max > 0 else { return 0 }
        return min((value / max) * 100, 100)
    }

    private var displayColor: Color {
        if reverseColors {
            // For metrics where higher is better (like free memory)
            switch alertLevel {
            case .critical: return .red
            case .warning: return .orange
            case .caution: return .yellow
            case .normal: return .green
            }
        } else {
            // For metrics where lower is better
            switch alertLevel {
            case .critical: return .red
            case .warning: return .orange
            case .caution: return .yellow
            case .normal: return .green
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                AlertBadgeView(level: alertLevel, text: "")
            }

            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 24)

                // Progress
                RoundedRectangle(cornerRadius: 4)
                    .fill(displayColor)
                    .frame(width: max(CGFloat(percentage) / 100.0 * 200, 0), height: 24)

                // Value text
                Text("\(formatValue(value)) \(unit)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formatValue(max)) \(unit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1f", value)
        } else if value >= 100 {
            return String(format: "%.1f", value)
        } else if value >= 10 {
            return String(format: "%.2f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
}

struct AlertBadgeView: View {
    let level: AlertLevel
    let text: String

    private var color: Color {
        switch level {
        case .normal: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var icon: String {
        switch level {
        case .normal: return "checkmark.circle.fill"
        case .caution: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            if !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
    }
}

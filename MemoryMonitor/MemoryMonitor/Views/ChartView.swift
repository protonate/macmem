//
//  ChartView.swift
//  MemoryMonitor
//
//  Time-series chart component
//

import SwiftUI

struct ChartView: View {
    let title: String
    let data: [SystemMetrics]
    let keyPath: KeyPath<SystemMetrics, Double>
    let color: Color
    let unit: String

    private var values: [Double] {
        data.map { $0[keyPath: keyPath] }
    }

    private var maxValue: Double {
        values.max() ?? 1.0
    }

    private var minValue: Double {
        values.min() ?? 0.0
    }

    private var currentValue: Double {
        values.last ?? 0.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Current: \(formatValue(currentValue)) \(unit)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("Max: \(formatValue(maxValue)) \(unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Background grid
                    Path { path in
                        let width = geometry.size.width
                        let height = geometry.size.height

                        // Horizontal lines
                        for i in 0...4 {
                            let y = height * CGFloat(i) / 4.0
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)

                    // Chart line
                    if !values.isEmpty {
                        ChartPath(
                            data: values,
                            max: maxValue,
                            min: minValue,
                            size: geometry.size
                        )
                        .stroke(color, lineWidth: 2)

                        // Fill area under curve
                        ChartPath(
                            data: values,
                            max: maxValue,
                            min: minValue,
                            size: geometry.size,
                            fill: true
                        )
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .frame(height: 150)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Time labels
            if !data.isEmpty {
                HStack {
                    Text(formatTime(data.first?.timestamp ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(data.last?.timestamp ?? Date()))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1f", value)
        } else if value >= 100 {
            return String(format: "%.1f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ChartPath: Shape {
    let data: [Double]
    let max: Double
    let min: Double
    let size: CGSize
    var fill: Bool = false

    func path(in rect: CGRect) -> Path {
        guard !data.isEmpty else { return Path() }

        let range = max - min
        guard range > 0 else { return Path() }

        let width = rect.width
        let height = rect.height
        let stepX = width / CGFloat(Swift.max(1, data.count - 1))

        var path = Path()

        for (index, value) in data.enumerated() {
            let x = CGFloat(index) * stepX
            let normalizedValue = (value - min) / range
            let y = height - (CGFloat(normalizedValue) * height)

            if index == 0 {
                if fill {
                    path.move(to: CGPoint(x: x, y: height))
                    path.addLine(to: CGPoint(x: x, y: y))
                } else {
                    path.move(to: CGPoint(x: x, y: y))
                }
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        if fill {
            path.addLine(to: CGPoint(x: width, y: height))
            path.closeSubpath()
        }

        return path
    }
}

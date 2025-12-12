//
//  ThrashingProcessesView.swift
//  MemoryMonitor
//
//  View for displaying top thrashing processes
//

import SwiftUI

struct ThrashingProcessesView: View {
    let processes: [ProcessThrashingScore]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Memory Thrashing Contributors")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if !processes.isEmpty {
                    Text("\(processes.count) process\(processes.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if processes.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                        Text("No significant thrashing detected")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Process Name")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 200, alignment: .leading)

                        Text("PID")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)

                        Text("Memory")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Text("Change")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .trailing)

                        Text("Thrashing Score")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(width: 120, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                    Divider()

                    // Process list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                                ProcessRowView(process: process, rank: index + 1)

                                if index < processes.count - 1 {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 300)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }
}

struct ProcessRowView: View {
    let process: ProcessThrashingScore
    let rank: Int

    private var scoreColor: Color {
        if process.thrashingScore > 1000 {
            return .red
        } else if process.thrashingScore > 500 {
            return .orange
        } else if process.thrashingScore > 100 {
            return .yellow
        } else {
            return .blue
        }
    }

    private var scoreLevel: String {
        if process.thrashingScore > 1000 {
            return "Critical"
        } else if process.thrashingScore > 500 {
            return "High"
        } else if process.thrashingScore > 100 {
            return "Moderate"
        } else {
            return "Low"
        }
    }

    var body: some View {
        HStack {
            // Rank badge
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(rankColor)
                .clipShape(Circle())

            // Process name (truncated)
            Text(process.name)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 170, alignment: .leading)

            // PID
            Text("\(process.pid)")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            // Current memory
            Text(formatMemory(process.currentMemoryMB))
                .font(.system(.body, design: .monospaced))
                .frame(width: 100, alignment: .trailing)

            // Memory change
            HStack(spacing: 2) {
                if process.memoryDeltaMB > 0 {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.red)
                } else if process.memoryDeltaMB < 0 {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "minus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(formatMemory(abs(process.memoryDeltaMB)))
                    .font(.system(.body, design: .monospaced))
            }
            .frame(width: 100, alignment: .trailing)

            // Thrashing score with level indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(scoreColor)
                    .frame(width: 8, height: 8)

                Text(String(format: "%.1f", process.thrashingScore))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(scoreColor)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rank <= 3 ? scoreColor.opacity(0.05) : Color.clear)
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }

    private func formatMemory(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        } else {
            return String(format: "%.0f MB", mb)
        }
    }
}

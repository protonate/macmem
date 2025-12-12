//
//  MetricsCollector.swift
//  MemoryMonitor
//
//  Collects system metrics by running macOS commands
//

import Foundation
import Combine

class MetricsCollector: ObservableObject {
    @Published var currentMetrics: SystemMetrics?
    @Published var metricsHistory: [SystemMetrics] = []
    @Published var thrashingMetrics: ThrashingMetrics?
    @Published var isCollecting = false
    @Published var topThrashingProcesses: [ProcessThrashingScore] = []

    private var timer: Timer?
    private let pollingInterval: TimeInterval = 5.0  // 5 seconds
    private var previousMetrics: SystemMetrics?
    private let dbManager = DatabaseManager()
    private var processHistory: [Int: [ProcessMemoryInfo]] = [:]  // pid -> history
    private var previousProcesses: [Int: ProcessMemoryInfo] = [:]  // pid -> last snapshot

    init() {
        // Load recent history from database
        loadRecentHistory()
    }

    func startCollecting() {
        guard !isCollecting else { return }
        isCollecting = true

        // Collect immediately
        collectMetrics()

        // Then collect every polling interval
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.collectMetrics()
        }
    }

    func stopCollecting() {
        isCollecting = false
        timer?.invalidate()
        timer = nil
    }

    private func collectMetrics() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let swap = try self.collectSwapUsage()
                let vmStats = try self.collectVMStats()
                let windowServer = try self.collectWindowServerMemory()
                let load = try self.collectLoadAverage()

                let metrics = SystemMetrics(
                    timestamp: Date(),
                    swapTotal: swap.total,
                    swapUsed: swap.used,
                    swapFree: swap.free,
                    pagesFree: vmStats.pagesFree,
                    pagesActive: vmStats.pagesActive,
                    pagesWired: vmStats.pagesWired,
                    pagesCompressed: vmStats.pagesCompressed,
                    pagesOccupiedByCompressor: vmStats.pagesOccupiedByCompressor,
                    swapins: vmStats.swapins,
                    swapouts: vmStats.swapouts,
                    compressions: vmStats.compressions,
                    decompressions: vmStats.decompressions,
                    windowServerMemory: windowServer.memory,
                    windowServerPercent: windowServer.percent,
                    loadAverage1m: load.avg1m,
                    loadAverage5m: load.avg5m,
                    loadAverage15m: load.avg15m
                )

                // Calculate thrashing metrics
                if let previous = self.previousMetrics {
                    let timeDelta = metrics.timestamp.timeIntervalSince(previous.timestamp)
                    let swapinDelta = metrics.swapins - previous.swapins
                    let swapoutDelta = metrics.swapouts - previous.swapouts

                    let swapinRate = Double(swapinDelta) / timeDelta
                    let swapoutRate = Double(swapoutDelta) / timeDelta

                    // Thrashing: high swap activity with roughly balanced in/out
                    let isThrashing = swapinRate > 10 && swapoutRate > 10 &&
                                     abs(swapinRate - swapoutRate) / Swift.max(swapinRate, swapoutRate) < 0.5

                    let thrashing = ThrashingMetrics(
                        swapinRate: swapinRate,
                        swapoutRate: swapoutRate,
                        isThrashing: isThrashing
                    )

                    DispatchQueue.main.async {
                        self.thrashingMetrics = thrashing
                    }
                }

                // Collect process information
                let processes = try self.collectProcessMemory()
                self.updateThrashingScores(processes: processes, isThrashing: self.thrashingMetrics?.isThrashing ?? false)

                // Save to database
                try? self.dbManager.saveMetrics(metrics)

                DispatchQueue.main.async {
                    self.currentMetrics = metrics
                    self.metricsHistory.append(metrics)

                    // Keep only last 2 hours of data in memory (1440 samples at 5s interval)
                    if self.metricsHistory.count > 1440 {
                        self.metricsHistory.removeFirst()
                    }

                    self.previousMetrics = metrics
                }

            } catch {
                print("Error collecting metrics: \(error)")
            }
        }
    }

    private func collectSwapUsage() throws -> (total: Double, used: Double, free: Double) {
        let output = try runCommand("/usr/sbin/sysctl", arguments: ["vm.swapusage"])

        // Parse: vm.swapusage: total = 5120.00M  used = 3861.94M  free = 1258.06M  (encrypted)
        let components = output.components(separatedBy: " ")
        var total: Double = 0
        var used: Double = 0
        var free: Double = 0

        for (index, component) in components.enumerated() {
            if component == "total" && index + 2 < components.count {
                total = parseMemoryValue(components[index + 2])
            } else if component == "used" && index + 2 < components.count {
                used = parseMemoryValue(components[index + 2])
            } else if component == "free" && index + 2 < components.count {
                free = parseMemoryValue(components[index + 2])
            }
        }

        return (total, used, free)
    }

    private func collectVMStats() throws -> (pagesFree: Int64, pagesActive: Int64, pagesWired: Int64,
                                             pagesCompressed: Int64, pagesOccupiedByCompressor: Int64,
                                             swapins: Int64, swapouts: Int64,
                                             compressions: Int64, decompressions: Int64) {
        let output = try runCommand("/usr/bin/vm_stat", arguments: [])

        var pagesFree: Int64 = 0
        var pagesActive: Int64 = 0
        var pagesWired: Int64 = 0
        var pagesCompressed: Int64 = 0
        var pagesOccupiedByCompressor: Int64 = 0
        var swapins: Int64 = 0
        var swapouts: Int64 = 0
        var compressions: Int64 = 0
        var decompressions: Int64 = 0

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Pages free:") {
                pagesFree = extractNumber(from: line)
            } else if line.contains("Pages active:") {
                pagesActive = extractNumber(from: line)
            } else if line.contains("Pages wired down:") {
                pagesWired = extractNumber(from: line)
            } else if line.contains("Pages stored in compressor:") {
                pagesCompressed = extractNumber(from: line)
            } else if line.contains("Pages occupied by compressor:") {
                pagesOccupiedByCompressor = extractNumber(from: line)
            } else if line.contains("Swapins:") {
                swapins = extractNumber(from: line)
            } else if line.contains("Swapouts:") {
                swapouts = extractNumber(from: line)
            } else if line.contains("Compressions:") {
                compressions = extractNumber(from: line)
            } else if line.contains("Decompressions:") {
                decompressions = extractNumber(from: line)
            }
        }

        return (pagesFree, pagesActive, pagesWired, pagesCompressed, pagesOccupiedByCompressor,
                swapins, swapouts, compressions, decompressions)
    }

    private func collectWindowServerMemory() throws -> (memory: Double, percent: Double) {
        let output = try runCommand("/bin/ps", arguments: ["-eo", "pmem,rss,comm"])

        let lines = output.components(separatedBy: "\n")
        for line in lines {
            if line.contains("WindowServer") {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces)
                if components.count >= 2 {
                    let percent = Double(components[0]) ?? 0.0
                    let rss = Double(components[1]) ?? 0.0
                    let memoryMB = rss / 1024.0
                    return (memoryMB, percent)
                }
            }
        }

        return (0, 0)
    }

    private func collectLoadAverage() throws -> (avg1m: Double, avg5m: Double, avg15m: Double) {
        let output = try runCommand("/usr/bin/uptime", arguments: [])

        // Parse: "10:10  up 20:17, 2 users, load averages: 3.10 2.90 3.04"
        if let range = output.range(of: "load averages:") {
            let substring = output[range.upperBound...].trimmingCharacters(in: .whitespaces)
            let values = substring.components(separatedBy: .whitespaces)
            if values.count >= 3 {
                let avg1m = Double(values[0]) ?? 0.0
                let avg5m = Double(values[1]) ?? 0.0
                let avg15m = Double(values[2]) ?? 0.0
                return (avg1m, avg5m, avg15m)
            }
        }

        return (0, 0, 0)
    }

    private func runCommand(_ path: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func parseMemoryValue(_ value: String) -> Double {
        let cleaned = value.replacingOccurrences(of: "M", with: "")
                          .replacingOccurrences(of: "G", with: "")
        if value.contains("G") {
            return (Double(cleaned) ?? 0) * 1024
        }
        return Double(cleaned) ?? 0
    }

    private func extractNumber(from line: String) -> Int64 {
        let components = line.components(separatedBy: .whitespaces)
        for component in components {
            let cleaned = component.replacingOccurrences(of: ".", with: "")
            if let number = Int64(cleaned) {
                return number
            }
        }
        return 0
    }

    private func collectProcessMemory() throws -> [ProcessMemoryInfo] {
        let output = try runCommand("/bin/ps", arguments: ["-eo", "pid,pmem,rss,comm"])
        let lines = output.components(separatedBy: "\n")
        var processes: [ProcessMemoryInfo] = []
        let now = Date()

        // Skip header line
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let components = trimmed.components(separatedBy: .whitespaces)
            guard components.count >= 4 else { continue }

            guard let pid = Int(components[0]),
                  let percentMem = Double(components[1]),
                  let rss = Double(components[2]) else { continue }

            // Get process name (everything after the first 3 components)
            let name = components[3...].joined(separator: " ")

            // Convert RSS (in KB) to MB
            let memoryMB = rss / 1024.0

            // Only track processes using more than 10MB
            guard memoryMB > 10.0 else { continue }

            let processInfo = ProcessMemoryInfo(
                id: pid,
                pid: pid,
                name: name,
                memoryMB: memoryMB,
                percentMemory: percentMem,
                timestamp: now
            )

            processes.append(processInfo)
        }

        return processes
    }

    private func updateThrashingScores(processes: [ProcessMemoryInfo], isThrashing: Bool) {
        let now = Date()
        var scores: [ProcessThrashingScore] = []

        // Update process history
        for process in processes {
            if processHistory[process.pid] == nil {
                processHistory[process.pid] = []
            }

            processHistory[process.pid]?.append(process)

            // Keep only last 5 minutes of history (60 samples at 5s interval)
            if let history = processHistory[process.pid], history.count > 60 {
                processHistory[process.pid] = Array(history.suffix(60))
            }
        }

        // Calculate thrashing scores
        for process in processes {
            guard let history = processHistory[process.pid], history.count > 1 else {
                continue
            }

            // Calculate memory change over the last few samples
            let recentHistory = Array(history.suffix(6))  // Last 30 seconds
            guard recentHistory.count >= 2 else { continue }

            let memoryChanges = zip(recentHistory.dropLast(), recentHistory.dropFirst()).map { prev, current in
                abs(current.memoryMB - prev.memoryMB)
            }

            let avgMemoryChange = memoryChanges.reduce(0, +) / Double(memoryChanges.count)
            let maxMemoryChange = memoryChanges.max() ?? 0

            // Score calculation:
            // - Higher score = more likely to be causing thrashing
            // - Consider: memory volatility, current memory usage, and system thrashing state
            var score = avgMemoryChange * 10.0  // Base score on average memory change

            // Amplify score if system is thrashing
            if isThrashing {
                score *= 3.0
            }

            // Add weight for large processes
            if process.memoryMB > 500 {
                score *= 1.5
            }

            // Add weight for high volatility
            if maxMemoryChange > 100 {
                score *= 2.0
            }

            let memoryDelta = process.memoryMB - (previousProcesses[process.pid]?.memoryMB ?? process.memoryMB)

            let thrashingScore = ProcessThrashingScore(
                id: process.pid,
                pid: process.pid,
                name: process.name,
                thrashingScore: score,
                currentMemoryMB: process.memoryMB,
                memoryDeltaMB: memoryDelta,
                lastSeen: now
            )

            if score > 0.1 {  // Only include processes with meaningful scores
                scores.append(thrashingScore)
            }

            previousProcesses[process.pid] = process
        }

        // Sort by score (descending) and take top 10
        let topScores = scores.sorted(by: >).prefix(10)

        // Clean up old process history (not seen in last 5 minutes)
        let cutoffTime = now.addingTimeInterval(-300)
        processHistory = processHistory.filter { pid, history in
            guard let lastSeen = history.last?.timestamp else { return false }
            return lastSeen >= cutoffTime
        }

        DispatchQueue.main.async {
            self.topThrashingProcesses = Array(topScores)
        }
    }

    private func loadRecentHistory() {
        if let history = try? dbManager.loadRecentMetrics(limit: 720) {  // Last hour at 5s interval
            DispatchQueue.main.async {
                self.metricsHistory = history
                self.currentMetrics = history.last
            }
        }
    }
}

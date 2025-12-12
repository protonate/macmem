//
//  SystemMetrics.swift
//  MemoryMonitor
//
//  Data models for system metrics
//

import Foundation

struct SystemMetrics: Codable, Identifiable {
    let id: UUID
    let timestamp: Date

    // Swap metrics
    let swapTotal: Double  // MB
    let swapUsed: Double   // MB
    let swapFree: Double   // MB

    // VM statistics
    let pagesFree: Int64
    let pagesActive: Int64
    let pagesWired: Int64
    let pagesCompressed: Int64
    let pagesOccupiedByCompressor: Int64
    let swapins: Int64
    let swapouts: Int64
    let compressions: Int64
    let decompressions: Int64

    // WindowServer
    let windowServerMemory: Double  // MB
    let windowServerPercent: Double

    // System
    let loadAverage1m: Double
    let loadAverage5m: Double
    let loadAverage15m: Double

    // Computed properties
    var compressorSizeMB: Double {
        Double(pagesOccupiedByCompressor) * 16384.0 / 1024.0 / 1024.0
    }

    var freeMemoryMB: Double {
        Double(pagesFree) * 16384.0 / 1024.0 / 1024.0
    }

    var swapUsedPercent: Double {
        guard swapTotal > 0 else { return 0 }
        return (swapUsed / swapTotal) * 100.0
    }

    // Alert levels
    var swapAlertLevel: AlertLevel {
        if swapUsed > 4096 { return .critical }
        if swapUsed > 2048 { return .warning }
        return .normal
    }

    var windowServerAlertLevel: AlertLevel {
        if windowServerMemory > 2048 { return .critical }
        if windowServerMemory > 1024 { return .warning }
        if windowServerMemory > 512 { return .caution }
        return .normal
    }

    var loadAlertLevel: AlertLevel {
        if loadAverage1m > 5.0 { return .critical }
        if loadAverage1m > 3.0 { return .warning }
        return .normal
    }

    var compressorAlertLevel: AlertLevel {
        if compressorSizeMB > 3072 { return .critical }
        if compressorSizeMB > 2048 { return .warning }
        return .normal
    }

    var freeMemoryAlertLevel: AlertLevel {
        if freeMemoryMB < 100 { return .critical }
        if freeMemoryMB < 500 { return .warning }
        return .normal
    }

    init(id: UUID = UUID(), timestamp: Date = Date(),
         swapTotal: Double, swapUsed: Double, swapFree: Double,
         pagesFree: Int64, pagesActive: Int64, pagesWired: Int64,
         pagesCompressed: Int64, pagesOccupiedByCompressor: Int64,
         swapins: Int64, swapouts: Int64, compressions: Int64, decompressions: Int64,
         windowServerMemory: Double, windowServerPercent: Double,
         loadAverage1m: Double, loadAverage5m: Double, loadAverage15m: Double) {
        self.id = id
        self.timestamp = timestamp
        self.swapTotal = swapTotal
        self.swapUsed = swapUsed
        self.swapFree = swapFree
        self.pagesFree = pagesFree
        self.pagesActive = pagesActive
        self.pagesWired = pagesWired
        self.pagesCompressed = pagesCompressed
        self.pagesOccupiedByCompressor = pagesOccupiedByCompressor
        self.swapins = swapins
        self.swapouts = swapouts
        self.compressions = compressions
        self.decompressions = decompressions
        self.windowServerMemory = windowServerMemory
        self.windowServerPercent = windowServerPercent
        self.loadAverage1m = loadAverage1m
        self.loadAverage5m = loadAverage5m
        self.loadAverage15m = loadAverage15m
    }
}

enum AlertLevel {
    case normal
    case caution
    case warning
    case critical

    var color: String {
        switch self {
        case .normal: return "green"
        case .caution: return "yellow"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

struct ThrashingMetrics {
    let swapinRate: Double  // pages per second
    let swapoutRate: Double // pages per second
    let isThrashing: Bool

    var thrashingLevel: String {
        if !isThrashing { return "None" }
        let totalRate = swapinRate + swapoutRate
        if totalRate > 1000 { return "Severe" }
        if totalRate > 500 { return "High" }
        if totalRate > 100 { return "Moderate" }
        return "Low"
    }
}

struct ProcessMemoryInfo: Identifiable, Hashable {
    let id: Int  // pid
    let pid: Int
    let name: String
    let memoryMB: Double
    let percentMemory: Double
    let timestamp: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(pid)
    }

    static func == (lhs: ProcessMemoryInfo, rhs: ProcessMemoryInfo) -> Bool {
        lhs.pid == rhs.pid
    }
}

struct ProcessThrashingScore: Identifiable, Comparable {
    let id: Int  // pid
    let pid: Int
    let name: String
    let thrashingScore: Double  // Weighted score based on memory changes and system thrashing
    let currentMemoryMB: Double
    let memoryDeltaMB: Double  // Change in memory usage
    let lastSeen: Date

    static func < (lhs: ProcessThrashingScore, rhs: ProcessThrashingScore) -> Bool {
        lhs.thrashingScore < rhs.thrashingScore
    }
}

//
//  MemoryMonitorApp.swift
//  MemoryMonitor
//
//  Main application entry point
//

import SwiftUI

@main
struct MemoryMonitorApp: App {
    @StateObject private var metricsCollector = MetricsCollector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metricsCollector)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

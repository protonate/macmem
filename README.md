# Memory Monitor for macOS

A comprehensive macOS application that provides deep insights into memory usage, swap activity, WindowServer performance, and memory thrashing beyond what Activity Monitor offers.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-enabled-green)

## Features

### Real-Time Monitoring
- **Swap Usage**: Track swap memory consumption with alert thresholds
- **WindowServer Memory**: Monitor WindowServer RAM usage and detect memory leaks
- **Memory Compressor**: View compressed memory size and overhead
- **Free Memory**: Real-time available memory tracking
- **Load Average**: System load monitoring (1m, 5m, 15m)

### Memory Thrashing Detection
- Real-time swap-in/swap-out rate calculation
- Automatic thrashing detection with severity levels
- Visual indicators for memory pressure

### Historical Analysis
- Time-series charts for all metrics
- Configurable time ranges (15 min, 1 hour, 6 hours)
- SQLite database storage (retains 7 days of data)
- Trend visualization for long-term analysis

### Alert System
- Color-coded alert levels (Normal, Caution, Warning, Critical)
- Threshold-based warnings for:
  - Swap usage (> 2GB warning, > 4GB critical)
  - WindowServer (> 512MB caution, > 1GB warning, > 2GB critical)
  - Free memory (< 500MB warning, < 100MB critical)
  - Load average (> 3.0 warning, > 5.0 critical)
  - Memory compressor size (> 2GB warning, > 3GB critical)

### Detailed Statistics
- Pages free/active/wired
- Compression statistics
- Cumulative swap operations
- Load averages across multiple time periods

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- Xcode 15.0+ (for building from source)

## Installation

### Building from Source

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd macmem
   ```

2. **Open in Xcode**
   ```bash
   open MemoryMonitor/MemoryMonitor.xcodeproj
   ```

3. **Build and Run**
   - Select the MemoryMonitor target
   - Choose your Mac as the destination
   - Press `Cmd+R` or click the Run button
   - The app will build and launch automatically

### Running the Pre-built App

If a pre-built `.app` bundle is available:

1. Download the `MemoryMonitor.app` package
2. Move it to your Applications folder
3. Right-click and select "Open" (first launch only, due to Gatekeeper)
4. Click "Open" in the security dialog

## Usage

### Starting Monitoring

The app begins collecting metrics automatically when launched. The collection interval is 5 seconds.

- **Play/Pause Button**: Click the button in the top-right to pause or resume data collection
- **Real-Time Gauges**: View current metrics in the gauge section
- **Historical Charts**: Scroll down to see time-series graphs

### Understanding the Dashboard

#### Gauge Section
Each gauge displays:
- Current value with units
- Color-coded alert indicator
- Maximum scale for context
- Visual progress bar

#### Thrashing Section
When memory thrashing is detected:
- **Swap-in Rate**: Pages being read from disk per second
- **Swap-out Rate**: Pages being written to disk per second
- **Thrashing Level**: None, Low, Moderate, High, or Severe
- Visual warning when thrashing is active

#### Historical Charts
- Select time range: 15 minutes, 1 hour, or 6 hours
- Each chart shows:
  - Current value
  - Maximum value in time range
  - Time-series line graph with gradient fill
  - Timestamp labels

### Interpreting Alerts

| Alert Level | Color | Meaning |
|------------|-------|---------|
| **Normal** | Green | System is operating within healthy parameters |
| **Caution** | Yellow | Metric is elevated but not concerning |
| **Warning** | Orange | Action recommended, monitor closely |
| **Critical** | Red | Immediate attention needed, performance impacted |

### Common Scenarios

#### High Swap Usage
**Symptoms**: Swap gauge shows orange/red, high swap-in/out rates

**Solutions**:
- Close unused applications
- Check for memory leaks in specific apps
- Consider upgrading RAM

#### WindowServer Memory Leak
**Symptoms**: WindowServer gauge steadily increases over time, exceeds 1-2GB

**Solutions**:
- Restart the WindowServer: `sudo killall -HUP WindowServer` (logs you out)
- Close windows and apps with many graphical elements
- Restart your Mac

#### Memory Thrashing
**Symptoms**: Red thrashing alert, high swap rates, system sluggishness

**Solutions**:
- Immediately close memory-intensive applications
- Restart applications that show large VSZ vs RSS gap
- Free up memory pressure
- Reboot if condition persists

#### High Load Average with Idle CPU
**Symptoms**: Load average > 5 but CPU shows idle

**Solutions**:
- Indicates I/O bottleneck (likely swap thrashing)
- Follow memory thrashing solutions above
- Check for disk issues with Disk Utility

## Technical Details

### Data Collection

The app executes the following macOS commands:

```bash
# Swap usage
sysctl vm.swapusage

# Virtual memory statistics
vm_stat

# Process memory (WindowServer)
ps -eo pmem,rss,comm

# System load
uptime
```

### Database Storage

Metrics are stored in SQLite database:
- Location: `~/Library/Application Support/MemoryMonitor/metrics.db`
- Retention: 7 days (automatic cleanup)
- Schema: One table with 19 metrics per record

### Performance Impact

- CPU usage: < 0.5% average
- Memory footprint: ~50MB typical
- Disk writes: Minimal (every 5 seconds, ~2KB per record)
- No sudo/elevated privileges required (except for powermetrics)

## Architecture

```
MemoryMonitor/
├── MemoryMonitorApp.swift       # App entry point
├── Models/
│   └── SystemMetrics.swift      # Data models, alert levels
├── Services/
│   ├── MetricsCollector.swift   # Command execution, parsing
│   └── DatabaseManager.swift    # SQLite persistence
└── Views/
    ├── ContentView.swift        # Main dashboard
    ├── MetricGaugeView.swift    # Gauge components
    └── ChartView.swift          # Time-series charts
```

### Key Components

- **MetricsCollector**: Executes shell commands, parses output, calculates derived metrics
- **DatabaseManager**: SQLite wrapper for historical data storage
- **SystemMetrics**: Codable data model with computed properties and alert thresholds
- **SwiftUI Views**: Reactive UI components that update automatically when data changes

## Development

### Adding New Metrics

1. Update `SystemMetrics` model with new properties
2. Add parsing logic in `MetricsCollector`
3. Update database schema in `DatabaseManager.createTable()`
4. Add UI components in `ContentView` and create new gauge/chart views

### Customizing Thresholds

Edit alert thresholds in `SystemMetrics.swift`:

```swift
var swapAlertLevel: AlertLevel {
    if swapUsed > 4096 { return .critical }  // Adjust these values
    if swapUsed > 2048 { return .warning }
    return .normal
}
```

### Changing Polling Interval

Modify in `MetricsCollector.swift`:

```swift
private let pollingInterval: TimeInterval = 5.0  // Change to desired seconds
```

## Troubleshooting

### App Won't Launch
- Check macOS version (requires 13.0+)
- Right-click app, select "Open" to bypass Gatekeeper
- Check Console.app for error messages

### No Data Appearing
- Ensure app has started collecting (play button icon should be filled)
- Check that system commands are available: `which vm_stat sysctl ps uptime`
- Verify database location exists: `~/Library/Application Support/MemoryMonitor/`

### Inaccurate Metrics
- Page size is hardcoded to 16384 bytes (16KB) for Apple Silicon
- Intel Macs may use 4096 bytes - adjust in code if needed
- Restart app to clear any cached/stale data

### High Memory Usage by App Itself
- Historical data in memory limited to 1440 samples (2 hours at 5s interval)
- Database cleaned automatically (7-day retention)
- Restart app if memory grows unexpectedly

## Command Reference

This app implements monitoring for the following diagnostic commands. You can run these manually in Terminal for spot checks:

| Command | Purpose |
|---------|---------|
| `sysctl vm.swapusage` | Swap space usage |
| `vm_stat` | Virtual memory statistics |
| `ps -eo pmem,rss,comm \| grep WindowServer` | WindowServer memory |
| `uptime` | Load averages |
| `memory_pressure` | Memory pressure summary (alternative) |
| `top -l 1 -o cpu` | System overview |
| `ps -eo vsz,rss,comm` | Virtual vs resident memory |

## License

Copyright © 2024. All rights reserved.

## Contributing

Contributions welcome! Areas for enhancement:

- [ ] Export data to CSV/JSON
- [ ] Configurable alert thresholds via UI
- [ ] Menu bar mode with mini-dashboard
- [ ] Notifications for critical alerts
- [ ] Per-process memory breakdown
- [ ] Network usage monitoring
- [ ] Disk I/O statistics
- [ ] Dark mode support improvements
- [ ] Preferences panel
- [ ] Multiple window support for comparing time periods

## Acknowledgments

Built with:
- Swift 5.0
- SwiftUI
- SQLite3
- macOS system utilities

Inspired by the need for deeper memory diagnostics beyond Activity Monitor's capabilities.

## Support

For issues, feature requests, or questions:
- Open an issue in the GitHub repository
- Check existing issues for solutions
- Review Console.app logs for error details

---

**Note**: This tool is for diagnostics and monitoring only. It does not modify system settings or interfere with memory management.

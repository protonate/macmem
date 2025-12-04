# Memory Monitor - Quick Usage Guide

## Quick Start

### Building the App
```bash
./build.sh
```

Or with Xcode:
```bash
open MemoryMonitor/MemoryMonitor.xcodeproj
# Then press Cmd+R
```

### Installing
```bash
cp -R build/Build/Products/Release/MemoryMonitor.app /Applications/
```

## Dashboard Overview

### Top Section: Real-Time Gauges
- **Swap Used**: How much swap space is currently in use
- **WindowServer**: Memory used by the window management system
- **Compressor**: Size of compressed memory
- **Free Memory**: Available RAM
- **Load Average**: System load (1-minute average)
- **Swap Usage**: Percentage of swap space used

### Middle Section: Memory Thrashing
Displays real-time swap activity rates:
- **Swap-in Rate**: Pages being read from disk
- **Swap-out Rate**: Pages being written to disk
- **Thrashing Status**: None/Low/Moderate/High/Severe

### Bottom Section: Historical Charts
Time-series graphs showing:
- Swap usage over time
- WindowServer memory over time
- Compressor size over time
- Free memory over time
- Load average over time

Use the time range selector (15 min / 1 hour / 6 hours) to zoom in/out.

## Alert Colors

| Color | Level | Action |
|-------|-------|--------|
| 🟢 Green | Normal | No action needed |
| 🟡 Yellow | Caution | Monitor situation |
| 🟠 Orange | Warning | Consider closing apps |
| 🔴 Red | Critical | Take immediate action |

## Common Issues & Solutions

### Issue: Swap usage is high (orange/red)
**What it means**: Your Mac is using disk storage as RAM

**Solutions**:
1. Close unused applications
2. Check Activity Monitor for memory-hungry apps
3. Restart memory-leaking applications
4. Consider upgrading RAM

### Issue: WindowServer memory is growing
**What it means**: The display server might have a memory leak

**Solutions**:
1. Close unnecessary windows
2. Quit apps with many graphical elements
3. As last resort: `sudo killall -HUP WindowServer` (logs you out)

### Issue: Thrashing detected (red warning)
**What it means**: System is constantly swapping memory to/from disk

**Solutions**:
1. **Immediate**: Close largest memory consumers
2. Check "Virtual vs Resident" memory gap in Activity Monitor
3. Restart affected applications
4. Reboot if problem persists

### Issue: High load but CPU is idle
**What it means**: I/O bottleneck, usually from swapping

**Solutions**:
- This is typically caused by memory thrashing
- Follow thrashing solutions above
- Check disk health in Disk Utility

## Understanding the Numbers

### Swap Usage Thresholds
- **< 1 GB**: Normal for 8GB RAM systems
- **1-2 GB**: Acceptable under load
- **2-4 GB**: Warning - consider closing apps
- **> 4 GB**: Critical - immediate action needed

### WindowServer Thresholds
- **< 500 MB**: Healthy
- **500 MB - 1 GB**: Elevated but acceptable
- **1-2 GB**: Warning - possible leak
- **> 2 GB**: Critical - restart required

### Load Average Guidelines
For a typical Mac:
- **< 2.0**: System responsive
- **2.0 - 4.0**: Moderate load
- **4.0 - 8.0**: High load
- **> 8.0**: Severe load (check for thrashing)

### Free Memory Guidelines
- **> 1 GB**: Comfortable
- **500 MB - 1 GB**: Adequate
- **100-500 MB**: Low - close apps
- **< 100 MB**: Critical - immediate action

## Monitoring Best Practices

### Daily Use
- Keep the app running in the background
- Glance at gauges periodically
- Pay attention to alert colors

### When System Feels Slow
1. Open Memory Monitor
2. Check swap usage gauge
3. Look for thrashing indicators
4. Review WindowServer memory
5. Check load average vs CPU idle

### After Installing New Apps
- Monitor for memory leaks
- Check if WindowServer grows over time
- Verify swap usage returns to baseline

### Before Major Work
- Restart if swap usage is high
- Close unnecessary applications
- Check free memory is adequate

## Advanced Tips

### Reset WindowServer Without Logging Out
```bash
# This will log you out - save work first!
sudo killall -HUP WindowServer
```

### Check Which Processes Use Most Swap
```bash
# Virtual vs Resident memory (large gap = swapped out)
ps -eo vsz,rss,comm | sort -rn | head -15
```

### Check Current Memory Pressure
```bash
memory_pressure
```

### View Detailed VM Stats
```bash
vm_stat
```

### Monitor Real-Time Swap Activity
```bash
# Run vm_stat with 1-second updates
vm_stat 1
```

### Check Spotlight Indexing
```bash
# Indexing can cause memory pressure
mdutil -s /
```

## Data Storage

The app stores metrics in:
```
~/Library/Application Support/MemoryMonitor/metrics.db
```

Data retention: 7 days (automatic cleanup)

To clear history:
```bash
rm -f ~/Library/Application\ Support/MemoryMonitor/metrics.db
```

## Keyboard Shortcuts

- `Cmd+Q`: Quit app
- `Cmd+W`: Close window (pauses monitoring)
- `Cmd+M`: Minimize window

## Polling Interval

Default: 5 seconds

To change: Edit `MetricsCollector.swift`:
```swift
private let pollingInterval: TimeInterval = 5.0  // Your desired interval
```

## Memory Consumption

Typical app footprint:
- **RAM**: ~50 MB
- **CPU**: < 0.5% average
- **Disk**: ~2 KB per sample (every 5 seconds)

## When to Reboot

Consider rebooting if:
- Swap usage remains high despite closing apps
- WindowServer memory exceeds 2 GB
- Persistent thrashing for > 10 minutes
- Load average > 8 with idle CPU
- Free memory < 100 MB constantly

## Troubleshooting

### App shows "Waiting for data..."
- Wait 5 seconds for first sample
- Ensure monitoring is started (play button)
- Check Console.app for errors

### Charts are empty
- Need at least 2 data points
- Wait 10-15 seconds after launch
- Check if monitoring is running

### Database errors
- Clear database: `rm ~/Library/Application\ Support/MemoryMonitor/metrics.db`
- Restart app
- Check disk space

### Gauges show zero
- Commands may not be available
- Check: `which vm_stat sysctl ps uptime`
- Verify you're running on macOS

## Pro Tips

1. **Leave it running**: The app uses minimal resources and provides continuous monitoring
2. **Check trends**: Use 6-hour view to spot gradual memory leaks
3. **Baseline your system**: Note normal values for your workflow
4. **Watch after updates**: OS/app updates can change memory behavior
5. **Compare with Activity Monitor**: Cross-reference with system tools

## Getting Help

If you encounter issues:
1. Check Console.app for error messages
2. Verify system commands work in Terminal
3. Try deleting the database and restarting
4. Check GitHub issues for similar problems

---

For detailed technical information, see [README.md](README.md)

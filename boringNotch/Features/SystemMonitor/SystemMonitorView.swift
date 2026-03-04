//
//  SystemMonitorView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

/// System Monitor tab view for the expanded notch.
struct SystemMonitorView: View {
    @ObservedObject var manager = SystemMonitorManager.shared
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        HStack(spacing: 20) {
            cpuGauge
            metricsGrid
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    // MARK: - CPU Gauge

    private var cpuGauge: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(manager.cpuUsage / 100.0, 1.0))
                .stroke(
                    cpuColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: manager.cpuUsage)

            // Center display
            VStack(spacing: 1) {
                Text("\(Int(manager.cpuUsage))%")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text("CPU")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(cpuColor)

                // Sparkline — last 30s of CPU history
                if manager.cpuHistory.count > 1 {
                    SparklineView(
                        data: manager.cpuHistory,
                        color: cpuColor
                    )
                    .frame(width: 40, height: 14)
                    .padding(.top, 1)
                }
            }
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Metrics Grid

    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            if Defaults[.showRAMUsage] {
                metricCard(
                    icon: "memorychip",
                    label: "RAM",
                    value: String(format: "%.1f / %.1f GB", manager.ramUsedGB, manager.ramTotalGB),
                    color: ramColor,
                    progress: manager.ramUsagePercent / 100.0,
                    progressColor: ramColor
                )
            }

            if Defaults[.showNetworkSpeed] {
                metricCard(
                    icon: "arrow.down.circle",
                    label: "Down",
                    value: SystemMonitorManager.formatBytes(manager.networkDownSpeed),
                    color: .cyan
                )

                metricCard(
                    icon: "arrow.up.circle",
                    label: "Up",
                    value: SystemMonitorManager.formatBytes(manager.networkUpSpeed),
                    color: .cyan
                )
            }

            if Defaults[.showDiskUsage] {
                metricCard(
                    icon: "internaldrive",
                    label: "Disk",
                    value: String(format: "%.0f / %.0f GB", manager.diskUsedGB, manager.diskTotalGB),
                    color: diskColor,
                    progress: manager.diskUsagePercent / 100.0,
                    progressColor: diskColor
                )
            }

            if Defaults[.showCPUTemperature] {
                metricCard(
                    icon: "thermometer.medium",
                    label: "Temp",
                    value: manager.cpuTemperature.map { String(format: "%.0f\u{00B0}C", $0) } ?? "N/A",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Metric Card

    private func metricCard(
        icon: String,
        label: String,
        value: String,
        color: Color,
        progress: Double? = nil,
        progressColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color)
                    .frame(width: 12)

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 30, alignment: .leading)

                Spacer(minLength: 0)

                Text(value)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }

            if let progress = progress, let progressColor = progressColor {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 3)

                        Capsule()
                            .fill(progressColor)
                            .frame(width: max(0, geo.size.width * min(CGFloat(progress), 1.0)), height: 3)
                            .animation(.easeInOut(duration: 0.4), value: progress)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        )
    }

    // MARK: - Colors

    private var cpuColor: Color {
        if manager.cpuUsage < 50 { return .green }
        if manager.cpuUsage < 80 { return .orange }
        return .red
    }

    private var ramColor: Color {
        let percent = manager.ramUsagePercent
        if percent < 60 { return .cyan }
        if percent < 85 { return .orange }
        return .red
    }

    private var diskColor: Color {
        let percent = manager.diskUsagePercent
        if percent < 70 { return .teal }
        if percent < 90 { return .orange }
        return .red
    }
}

// MARK: - Sparkline

/// Tiny line chart for CPU history trend.
struct SparklineView: View {
    let data: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(data.max() ?? 100, 1)
            let minVal = data.min() ?? 0
            let range = max(maxVal - minVal, 1)

            Path { path in
                guard data.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(data.count - 1)

                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalized = (value - minVal) / range
                    let y = geo.size.height * (1.0 - CGFloat(normalized))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                color.opacity(0.8),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

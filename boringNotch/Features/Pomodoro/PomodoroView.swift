//
//  PomodoroView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

/// Pomodoro tab view for the expanded notch.
struct PomodoroView: View {
    @ObservedObject var manager = PomodoroManager.shared
    @EnvironmentObject var vm: BoringViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Left: Timer + Controls
            timerSection

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
                .padding(.vertical, 8)

            // Right: Task + Stats
            statsSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 10)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity
        ))
    }

    // MARK: - Timer Section (Left)

    private var timerSection: some View {
        VStack(spacing: 8) {
            circularProgress
            controlButtons
        }
        .frame(maxWidth: .infinity)
    }

    private var circularProgress: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: manager.progress)
                .stroke(
                    phaseColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: manager.progress)

            VStack(spacing: 2) {
                Text(timeString(from: manager.remainingSeconds))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text(manager.phase.rawValue)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(phaseColor)
            }
        }
        .frame(width: 80, height: 80)
    }

    private var controlButtons: some View {
        VStack(spacing: 6) {
            // Cycle dots
            HStack(spacing: 3) {
                let cyclesBeforeLong = Int(Defaults[.pomodoroCyclesBeforeLongBreak])
                ForEach(0..<cyclesBeforeLong, id: \.self) { i in
                    Circle()
                        .fill(i < manager.completedCycles ? phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            // Control buttons
            HStack(spacing: 8) {
                // Play / Pause
                Button {
                    if manager.isRunning {
                        manager.pause()
                    } else {
                        manager.start()
                    }
                } label: {
                    Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(phaseColor.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Skip
                Button {
                    manager.skip()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: 22, height: 22)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Reset
                Button {
                    manager.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: 22, height: 22)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Stats Section (Right)

    private var statsSection: some View {
        VStack(spacing: 8) {
            // Task name
            TextField("What are you working on?", text: $manager.taskName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                )

            // Today stats
            HStack(spacing: 12) {
                statBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(manager.todayCycles)",
                    label: "Cycles"
                )
                statBadge(
                    icon: "clock.fill",
                    value: "\(manager.todayFocusMinutes)m",
                    label: "Focus"
                )
            }

            // Weekly bar chart
            weeklyChart
        }
        .frame(maxWidth: .infinity)
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(phaseColor)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 7))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        let days = last7Days()
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(days, id: \.self) { day in
                let cycles = cyclesFor(day: day)
                let maxCycles = max(days.map { cyclesFor(day: $0) }.max() ?? 1, 1)
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(day == todayKey ? phaseColor : phaseColor.opacity(0.4))
                        .frame(width: 12, height: max(3, CGFloat(cycles) / CGFloat(maxCycles) * 30))
                    Text(shortDayLabel(day))
                        .font(.system(size: 6))
                        .foregroundColor(.gray)
                }
            }
        }
        .frame(height: 46)
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func last7Days() -> [String] {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        var cal = Calendar(identifier: .iso8601) // Monday = first weekday
        cal.locale = Locale.current
        // Find this week's Monday
        let today = Date()
        guard let weekInterval = cal.dateInterval(of: .weekOfYear, for: today) else {
            return []
        }
        let monday = weekInterval.start
        return (0..<7).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday) ?? today
            return f.string(from: date)
        }
    }

    private func cyclesFor(day: String) -> Int {
        if day == todayKey {
            return manager.todayCycles
        }
        return manager.weeklyHistory.first(where: { $0.date == day })?.completedCycles ?? 0
    }

    private func shortDayLabel(_ dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return "" }
        let dayF = DateFormatter()
        dayF.dateFormat = "E"
        return String(dayF.string(from: date).prefix(1))
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        switch manager.phase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

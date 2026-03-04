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
        HStack(spacing: 20) {
            circularProgress
            controlPanel
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Circular Progress

    private var circularProgress: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            // Progress ring
            Circle()
                .trim(from: 0, to: manager.progress)
                .stroke(
                    phaseColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: manager.progress)

            // Time display
            VStack(spacing: 2) {
                Text(timeString(from: manager.remainingSeconds))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Text(manager.phase.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(phaseColor)
            }
        }
        .frame(width: 90, height: 90)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cycle counter
            HStack(spacing: 4) {
                let cyclesBeforeLong = Int(Defaults[.pomodoroCyclesBeforeLongBreak])
                ForEach(0..<cyclesBeforeLong, id: \.self) { i in
                    Circle()
                        .fill(i < manager.completedCycles ? phaseColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                Spacer()
            }

            // Phase label
            Text(phaseLabel)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(1)

            // Control buttons
            HStack(spacing: 10) {
                // Play / Pause
                Button {
                    if manager.isRunning {
                        manager.pause()
                    } else {
                        manager.start()
                    }
                } label: {
                    Image(systemName: manager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(phaseColor.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Skip
                Button {
                    manager.skip()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                // Reset
                Button {
                    manager.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    // MARK: - Helpers

    private var phaseColor: Color {
        switch manager.phase {
        case .work: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }

    private var phaseLabel: String {
        switch manager.timerState {
        case .idle:
            return "Ready to start"
        case .running:
            return manager.phase == .work ? "Stay focused" : "Take a break"
        case .paused:
            return "Paused"
        }
    }

    private func timeString(from seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

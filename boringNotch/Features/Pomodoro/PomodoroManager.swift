//
//  PomodoroManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Combine
import Defaults
import Foundation
import os
import UserNotifications

/// Pomodoro session phase.
enum PomodoroPhase: String {
    case work = "Work"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
}

/// Pomodoro timer state.
enum PomodoroTimerState {
    case idle
    case running
    case paused
}

/// Centralized Pomodoro timer manager.
class PomodoroManager: ObservableObject {

    static let shared = PomodoroManager()

    private let logger = Logger(subsystem: "com.dynanotch", category: "Pomodoro")

    // MARK: - Published State

    @Published var phase: PomodoroPhase = .work
    @Published var timerState: PomodoroTimerState = .idle
    @Published var remainingSeconds: TimeInterval = 0
    @Published var completedCycles: Int = 0
    @Published var taskName: String = "" {
        didSet { Defaults[.pomodoroTaskName] = taskName }
    }
    @Published var todayCycles: Int = 0
    @Published var todayFocusMinutes: Int = 0
    @Published var weeklyHistory: [PomodoroDailyStats] = []

    // MARK: - Computed

    var totalSeconds: TimeInterval {
        switch phase {
        case .work: return Defaults[.pomodoroWorkDuration]
        case .shortBreak: return Defaults[.pomodoroShortBreakDuration]
        case .longBreak: return Defaults[.pomodoroLongBreakDuration]
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (remainingSeconds / totalSeconds)
    }

    var isRunning: Bool { timerState == .running }

    // MARK: - Private

    private var timer: AnyCancellable?

    // MARK: - Init

    private init() {
        remainingSeconds = Defaults[.pomodoroWorkDuration]
        taskName = Defaults[.pomodoroTaskName]
        loadTodayStats()
        weeklyHistory = Defaults[.pomodoroWeeklyHistory]
        requestNotificationPermission()
    }

    // MARK: - Public API

    func start() {
        guard timerState != .running else { return }
        logger.info("[POMODORO] start — phase=\(self.phase.rawValue) remaining=\(Int(self.remainingSeconds))")

        if timerState == .idle {
            remainingSeconds = totalSeconds
        }

        timerState = .running
        startTimer()
    }

    func pause() {
        guard timerState == .running else { return }
        logger.info("[POMODORO] pause — remaining=\(Int(self.remainingSeconds))")
        timerState = .paused
        stopTimer()
    }

    func reset() {
        logger.info("[POMODORO] reset")
        stopTimer()
        timerState = .idle
        phase = .work
        completedCycles = 0
        remainingSeconds = Defaults[.pomodoroWorkDuration]
    }

    func skip() {
        logger.info("[POMODORO] skip phase=\(self.phase.rawValue)")
        stopTimer()
        advancePhase()
    }

    // MARK: - Private Timer

    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        remainingSeconds -= 1

        if remainingSeconds <= 0 {
            remainingSeconds = 0
            onPhaseComplete()
        }
    }

    private func onPhaseComplete() {
        logger.info("[POMODORO] phase complete — phase=\(self.phase.rawValue) cycles=\(self.completedCycles)")
        stopTimer()

        sendNotification(for: phase)
        advancePhase()
    }

    private func advancePhase() {
        switch phase {
        case .work:
            completedCycles += 1
            recordWorkCompletion()
            let cyclesBeforeLong = Int(Defaults[.pomodoroCyclesBeforeLongBreak])
            if completedCycles >= cyclesBeforeLong {
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            if phase == .longBreak {
                completedCycles = 0
            }
            phase = .work
        }

        remainingSeconds = totalSeconds
        timerState = .idle
        logger.info("[POMODORO] next phase=\(self.phase.rawValue) remaining=\(Int(self.remainingSeconds))")
    }

    // MARK: - Stats Persistence

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var todayKey: String {
        Self.dateFormatter.string(from: Date())
    }

    private func loadTodayStats() {
        let today = todayKey
        if Defaults[.pomodoroTodayDate] == today {
            todayCycles = Defaults[.pomodoroTodayCycles]
            todayFocusMinutes = Defaults[.pomodoroTodayFocusMinutes]
        } else {
            // Day rolled over — archive yesterday and reset
            archiveYesterday()
            todayCycles = 0
            todayFocusMinutes = 0
            Defaults[.pomodoroTodayDate] = today
            Defaults[.pomodoroTodayCycles] = 0
            Defaults[.pomodoroTodayFocusMinutes] = 0
        }
    }

    private func archiveYesterday() {
        let prevDate = Defaults[.pomodoroTodayDate]
        let prevCycles = Defaults[.pomodoroTodayCycles]
        guard !prevDate.isEmpty, prevCycles > 0 else { return }

        var history = Defaults[.pomodoroWeeklyHistory]
        // Remove existing entry for that date if present
        history.removeAll { $0.date == prevDate }
        history.append(PomodoroDailyStats(
            date: prevDate,
            completedCycles: prevCycles,
            focusMinutes: Defaults[.pomodoroTodayFocusMinutes]
        ))
        // Keep only last 7 days
        if history.count > 7 {
            history = Array(history.suffix(7))
        }
        Defaults[.pomodoroWeeklyHistory] = history
        weeklyHistory = history
    }

    private func recordWorkCompletion() {
        loadTodayStats() // Ensure day is current
        let workMinutes = Int(Defaults[.pomodoroWorkDuration] / 60)
        todayCycles += 1
        todayFocusMinutes += workMinutes
        Defaults[.pomodoroTodayCycles] = todayCycles
        Defaults[.pomodoroTodayFocusMinutes] = todayFocusMinutes

        // Also update weekly history live for today
        var history = Defaults[.pomodoroWeeklyHistory]
        history.removeAll { $0.date == todayKey }
        history.append(PomodoroDailyStats(
            date: todayKey,
            completedCycles: todayCycles,
            focusMinutes: todayFocusMinutes
        ))
        if history.count > 7 {
            history = Array(history.suffix(7))
        }
        Defaults[.pomodoroWeeklyHistory] = history
        weeklyHistory = history
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                self.logger.error("[POMODORO] notification auth error: \(error.localizedDescription)")
            } else {
                self.logger.info("[POMODORO] notification auth granted=\(granted)")
            }
        }
    }

    private func sendNotification(for completedPhase: PomodoroPhase) {
        guard Defaults[.pomodoroNotifications] else { return }
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch completedPhase {
        case .work:
            content.title = "Work Session Complete"
            content.body = "Time for a break! You've completed \(completedCycles) cycle\(completedCycles == 1 ? "" : "s")."
        case .shortBreak:
            content.title = "Break Over"
            content.body = "Ready to focus? Start your next work session."
        case .longBreak:
            content.title = "Long Break Over"
            content.body = "Great job! Ready for a fresh set of cycles."
        }

        let request = UNNotificationRequest(
            identifier: "pomodoro-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("[POMODORO] notification send error: \(error.localizedDescription)")
            }
        }
    }
}

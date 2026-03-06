//
//  SportsManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Combine
import Defaults
import Foundation
import os

final class SportsManager: ObservableObject {
    static let shared = SportsManager()
    private let logger = Logger(subsystem: "com.dynanotch.app", category: "SportsManager")

    // MARK: - Published State

    @Published var liveEvents: [SportEvent] = []
    @Published var isActive: Bool = false
    @Published var pickerDataReady: Bool = false

    // Providers (public for view access)
    let footballProvider = FootballProvider()
    let basketballProvider = BasketballProvider()
    let f1Provider = F1Provider()

    // MARK: - Private

    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // React to enable toggle
        Defaults.publisher(.enableSports)
            .map(\.newValue)
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.startMonitoring()
                } else {
                    self?.stopMonitoring()
                }
            }
            .store(in: &cancellables)

        // React to sport toggles changing
        let footballPub = Defaults.publisher(.enableFootball).map { _ in () }.eraseToAnyPublisher()
        let basketballPub = Defaults.publisher(.enableBasketball).map { _ in () }.eraseToAnyPublisher()
        let euroLeaguePub = Defaults.publisher(.enableEuroLeague).map { _ in () }.eraseToAnyPublisher()
        let f1Pub = Defaults.publisher(.enableF1).map { _ in () }.eraseToAnyPublisher()
        let leaguesPub = Defaults.publisher(.sportsFootballLeagues).map { _ in () }.eraseToAnyPublisher()

        Publishers.MergeMany([footballPub, basketballPub, euroLeaguePub, f1Pub, leaguesPub])
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard Defaults[.enableSports] else { return }
                self?.scheduleRefresh()
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        guard Defaults[.enableSports] else { return }
        isActive = true
        scheduleRefresh()
        logger.info("Sports monitoring started")
    }

    func stopMonitoring() {
        isActive = false
        refreshTask?.cancel()
        refreshTask = nil
        liveEvents = []
        logger.info("Sports monitoring stopped")
    }

    // MARK: - Refresh

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // Night mode: pause 00:00-08:00
                let hour = Calendar.current.component(.hour, from: Date())
                if hour >= 0 && hour < 8 {
                    try? await Task.sleep(for: .seconds(1800))
                    continue
                }

                await self.performRefresh()

                let interval = self.calculateRefreshInterval()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    @MainActor
    private func performRefresh() async {
        var events: [SportEvent] = []

        await withTaskGroup(of: [SportEvent].self) { group in
            if Defaults[.enableFootball] {
                group.addTask {
                    try? await self.footballProvider.refresh()
                    return self.footballProvider.liveEvents()
                }
            }
            if Defaults[.enableBasketball] || Defaults[.enableEuroLeague] {
                group.addTask {
                    try? await self.basketballProvider.refresh()
                    return self.basketballProvider.liveEvents()
                }
            }
            if Defaults[.enableF1] {
                group.addTask {
                    try? await self.f1Provider.refresh()
                    return self.f1Provider.liveEvents()
                }
            }
            for await result in group {
                events.append(contentsOf: result)
            }
        }

        liveEvents = events.sorted { $0.startDate < $1.startDate }
        pickerDataReady = true
    }

    /// Ensures picker data is available. Triggers a refresh if providers have no data yet.
    func ensurePickerData() async {
        // Reset so @Published always fires objectWillChange (false → true)
        await MainActor.run { pickerDataReady = false }

        let enabledLeagues = Defaults[.sportsFootballLeagues]
        let needsFootball = Defaults[.enableFootball] && !footballProvider.hasStandingsForAll(leagues: enabledLeagues)
        let needsBasketball = (Defaults[.enableBasketball] || Defaults[.enableEuroLeague]) && !basketballProvider.hasStandingsData
        let needsF1 = Defaults[.enableF1] && !f1Provider.hasDriverData

        logger.info("ensurePickerData: needs football=\(needsFootball), basketball=\(needsBasketball), f1=\(needsF1)")

        if needsFootball || needsBasketball || needsF1 {
            await withTaskGroup(of: Void.self) { group in
                if needsFootball {
                    group.addTask { try? await self.footballProvider.refresh() }
                }
                if needsBasketball {
                    group.addTask { try? await self.basketballProvider.refresh() }
                }
                if needsF1 {
                    group.addTask { try? await self.f1Provider.refresh() }
                }
            }
        }

        logger.info("ensurePickerData done: football=\(self.footballProvider.hasStandingsData) (\(self.footballProvider.allTeams().count) teams), basketball=\(self.basketballProvider.hasStandingsData) (\(self.basketballProvider.allTeams().count) teams), f1=\(self.f1Provider.hasDriverData) (\(self.f1Provider.allDrivers().count) drivers)")

        await MainActor.run {
            self.objectWillChange.send()
            pickerDataReady = true
        }
    }

    private func calculateRefreshInterval() -> TimeInterval {
        let hasLive = !liveEvents.isEmpty
        let hasF1Live = f1Provider.currentSession?.isLive == true

        if hasF1Live {
            return 10  // F1 live: 10s
        } else if hasLive {
            return 30  // Football/basketball live: 30s
        } else {
            return 900 // No live events: 15 minutes
        }
    }

    // MARK: - Collapsed Indicator

    var hasLiveEvent: Bool { !liveEvents.isEmpty }

    /// Text for the carousel collapsed indicator.
    var currentCollapsedText: String? {
        liveEvents.first?.collapsedText
    }
}

//
//  SportsSettings.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

struct SportsSettings: View {
    @Default(.enableSports) var enableSports
    @Default(.enableFootball) var enableFootball
    @Default(.enableBasketball) var enableBasketball
    @Default(.enableEuroLeague) var enableEuroLeague
    @Default(.enableF1) var enableF1
    @Default(.sportsFootballLeagues) var footballLeagues
    @Default(.sportsFavoriteFootballTeam) var favoriteFootballTeam
    @Default(.sportsFavoriteBasketballTeam) var favoriteBasketballTeam
    @Default(.sportsFavoriteEuroLeagueTeam) var favoriteEuroLeagueTeam
    @Default(.sportsFavoriteF1Driver) var favoriteF1Driver
    @Default(.sportsSlot1) var slot1
    @Default(.sportsSlot2) var slot2
    @Default(.sportsSlot3) var slot3

    @ObservedObject private var manager = SportsManager.shared
    @State private var isLoadingPickerData = false

    var body: some View {
        Form {
            // Beta badge + enable
            Section {
                HStack {
                    Toggle("Enable Sports", isOn: $enableSports)
                    Spacer()
                    Text("BETA")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            } header: {
                Text("Sports Tracker")
            } footer: {
                Text("Track live scores, standings, and race results directly in your notch.")
            }

            if enableSports {
                // Sport toggles
                Section("Sports") {
                    Toggle("⚽ Football", isOn: $enableFootball)
                    Toggle("🏀 Basketball (NBA)", isOn: $enableBasketball)
                    Toggle("🏀 EuroLeague", isOn: $enableEuroLeague)
                    Toggle("🏎️ Formula 1", isOn: $enableF1)
                }

                // Football settings
                if enableFootball {
                    Section("Football Leagues") {
                        ForEach(FootballLeague.allLeagues) { league in
                            Toggle(league.name, isOn: Binding(
                                get: { footballLeagues.contains(league) },
                                set: { enabled in
                                    if enabled {
                                        if !footballLeagues.contains(league) {
                                            footballLeagues.append(league)
                                        }
                                    } else {
                                        footballLeagues.removeAll { $0.id == league.id }
                                    }
                                }
                            ))
                        }
                    }

                    Section("Favorite Football Team") {
                        favoritePickerOrField(
                            items: manager.footballProvider.allTeams(),
                            selection: $favoriteFootballTeam,
                            valuePath: \.abbrev,
                            labelPath: \.displayName,
                            hasData: manager.footballProvider.hasStandingsData,
                            placeholder: "Team abbreviation (e.g. LIV, BAR, FB)"
                        )
                    }
                }

                // Basketball settings
                if enableBasketball {
                    Section("Favorite NBA Team") {
                        favoritePickerOrField(
                            items: manager.basketballProvider.allNBATeams(),
                            selection: $favoriteBasketballTeam,
                            valuePath: \.abbrev,
                            labelPath: \.displayName,
                            hasData: manager.basketballProvider.hasNBAStandingsData,
                            placeholder: "Team abbreviation (e.g. LAL, BOS, GSW)"
                        )
                    }
                }

                if enableEuroLeague {
                    Section("Favorite EuroLeague Team") {
                        favoritePickerOrField(
                            items: manager.basketballProvider.allEuroLeagueTeams(),
                            selection: $favoriteEuroLeagueTeam,
                            valuePath: \.abbrev,
                            labelPath: \.displayName,
                            hasData: manager.basketballProvider.hasEuroLeagueStandingsData,
                            placeholder: "Team code (e.g. ULK, FEN, PAO)"
                        )
                    }
                }

                // F1 settings
                if enableF1 {
                    Section("Favorite F1 Driver") {
                        favoritePickerOrField(
                            items: manager.f1Provider.allDrivers(),
                            selection: $favoriteF1Driver,
                            valuePath: \.code,
                            labelPath: \.displayName,
                            hasData: manager.f1Provider.hasDriverData,
                            placeholder: "Driver code (e.g. VER, HAM, NOR)"
                        )
                    }
                }

                // Widget slots — .id forces Picker re-creation when options change
                Section {
                    Picker("Slot 1", selection: $slot1) {
                        ForEach(availableWidgets) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .id("slot1-\(widgetOptionsKey)")

                    Picker("Slot 2", selection: $slot2) {
                        ForEach(availableWidgets) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .id("slot2-\(widgetOptionsKey)")

                    Picker("Slot 3", selection: $slot3) {
                        ForEach(availableWidgets) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .id("slot3-\(widgetOptionsKey)")
                } header: {
                    Text("Widget Slots")
                } footer: {
                    Text("Choose which widgets appear in the expanded sports view.")
                }
            }
        }
        .formStyle(.grouped)
        // Re-run when sport toggles change (not just on first appear)
        .task(id: pickerTaskTrigger) {
            guard enableSports else { return }
            isLoadingPickerData = true
            await manager.ensurePickerData()
            isLoadingPickerData = false
        }
        .onChange(of: enableFootball) { _, newValue in
            if !newValue { resetInvalidSlots() }
        }
        .onChange(of: enableBasketball) { _, newValue in
            if !newValue { resetInvalidSlots() }
        }
        .onChange(of: enableEuroLeague) { _, newValue in
            if !newValue { resetInvalidSlots() }
        }
        .onChange(of: enableF1) { _, newValue in
            if !newValue { resetInvalidSlots() }
        }
    }

    // MARK: - Picker Helper

    @ViewBuilder
    private func favoritePickerOrField<T>(
        items: [T],
        selection: Binding<String>,
        valuePath: KeyPath<T, String>,
        labelPath: KeyPath<T, String>,
        hasData: Bool,
        placeholder: String
    ) -> some View {
        if isLoadingPickerData && !hasData {
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Loading...")
                    .foregroundStyle(.secondary)
            }
        } else if hasData && !items.isEmpty {
            Picker("Favorite", selection: selection) {
                Text("No favorite").tag("")
                ForEach(items, id: valuePath) { item in
                    Text(item[keyPath: labelPath]).tag(item[keyPath: valuePath])
                }
            }
        } else {
            TextField(placeholder, text: selection)
                .textFieldStyle(.roundedBorder)
        }
    }

    // MARK: - Widget Slots

    /// Stable key that changes when available widget options change.
    private var widgetOptionsKey: String {
        availableWidgets.map(\.rawValue).joined(separator: ",")
    }

    /// Trigger for .task(id:) — re-runs when sport toggles or league selection changes.
    private var pickerTaskTrigger: String {
        let leagueIds = footballLeagues.map(\.id).sorted().joined(separator: ",")
        return "\(enableSports)-\(enableFootball)-\(enableBasketball)-\(enableEuroLeague)-\(enableF1)-\(leagueIds)"
    }

    /// Reset slot selections that reference a now-disabled sport.
    private func resetInvalidSlots() {
        let valid = Set(availableWidgets)
        let fallback = availableWidgets.first
        if !valid.contains(slot1) { slot1 = fallback ?? slot1 }
        if !valid.contains(slot2) { slot2 = fallback ?? slot2 }
        if !valid.contains(slot3) { slot3 = fallback ?? slot3 }
    }

    private var availableWidgets: [SportsWidgetKind] {
        var result: [SportsWidgetKind] = []
        if enableFootball {
            result.append(contentsOf: [.footballLive, .footballFixture, .footballStandings])
        }
        if enableBasketball || enableEuroLeague {
            result.append(contentsOf: [.basketballLive, .basketballFixture, .basketballStandings])
        }
        if enableF1 {
            result.append(contentsOf: [.f1LiveTiming, .f1Calendar, .f1WDC, .f1WCC])
        }
        return result
    }
}

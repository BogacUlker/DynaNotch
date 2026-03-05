//
//  SportsView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

struct SportsView: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsSlot1) var slot1
    @Default(.sportsSlot2) var slot2
    @Default(.sportsSlot3) var slot3

    var body: some View {
        HStack(spacing: 8) {
            slotWidget(slot1)
            slotWidget(slot2)
            slotWidget(slot3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func slotWidget(_ kind: SportsWidgetKind) -> some View {
        Group {
            switch kind {
            case .footballLive:
                FootballLiveWidget()
            case .footballFixture:
                FootballFixtureWidget()
            case .footballStandings:
                FootballStandingsWidget()
            case .basketballLive:
                BasketballLiveWidget()
            case .basketballFixture:
                BasketballFixtureWidget()
            case .basketballStandings:
                BasketballStandingsWidget()
            case .f1LiveTiming:
                F1LiveTimingWidget()
            case .f1Calendar:
                F1CalendarWidget()
            case .f1WDC:
                F1WDCWidget()
            case .f1WCC:
                F1WCCWidget()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Football Widgets

private struct FootballLiveWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        let live = manager.footballProvider.matches.filter(\.isLive)
        VStack(spacing: 4) {
            Text("⚽ LIVE").font(.system(size: 8, weight: .bold)).foregroundColor(.red)
            if live.isEmpty {
                Text("No live matches").font(.system(size: 9)).foregroundColor(.gray)
            } else {
                ForEach(live.prefix(3)) { m in
                    HStack(spacing: 4) {
                        Text(m.homeAbbrev).font(.system(size: 8, weight: .semibold)).foregroundColor(.white)
                        Text("\(m.homeScore ?? 0)-\(m.awayScore ?? 0)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        Text(m.awayAbbrev).font(.system(size: 8, weight: .semibold)).foregroundColor(.white)
                        if let min = m.minute { Text("\(min)'").font(.system(size: 7)).foregroundColor(.green) }
                    }
                }
            }
        }
        .padding(6)
    }
}

private struct FootballFixtureWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("⚽ NEXT").font(.system(size: 8, weight: .bold)).foregroundColor(.cyan)
            if let m = manager.footballProvider.nextFixture() {
                Text("\(m.homeAbbrev) vs \(m.awayAbbrev)")
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                Text(m.startDate, style: .relative)
                    .font(.system(size: 7)).foregroundColor(.gray)
            } else {
                Text("No upcoming").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .padding(6)
    }
}

private struct FootballStandingsWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFootballLeagues) var leagues
    var body: some View {
        VStack(spacing: 4) {
            Text("⚽ TABLE").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
            let leagueId = leagues.first?.id ?? "eng.1"
            let (rows, favIdx) = manager.footballProvider.standingsWindow(league: leagueId)
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 6) {
                    Text("\(row.position)").font(.system(size: 10, design: .monospaced)).frame(width: 16, alignment: .trailing)
                    Text(row.teamAbbrev).font(.system(size: 13, weight: idx == favIdx ? .bold : .medium))
                        .foregroundColor(idx == favIdx ? .yellow : .white)
                    Spacer()
                    Text("\(row.points)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(idx == favIdx ? .yellow : .gray)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx == favIdx ? Color.yellow.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

// MARK: - Basketball Widgets

private struct BasketballLiveWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        let live = manager.basketballProvider.games.filter(\.isLive)
        VStack(spacing: 4) {
            Text("🏀 LIVE").font(.system(size: 8, weight: .bold)).foregroundColor(.red)
            if live.isEmpty {
                Text("No live games").font(.system(size: 9)).foregroundColor(.gray)
            } else {
                ForEach(live.prefix(3)) { g in
                    HStack(spacing: 4) {
                        Text(g.homeAbbrev).font(.system(size: 8, weight: .semibold)).foregroundColor(.white)
                        Text("\(g.homeScore ?? 0)-\(g.awayScore ?? 0)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(.white)
                        Text(g.awayAbbrev).font(.system(size: 8, weight: .semibold)).foregroundColor(.white)
                        if let q = g.period { Text(q).font(.system(size: 7)).foregroundColor(.orange) }
                    }
                }
            }
        }
        .padding(6)
    }
}

private struct BasketballFixtureWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("🏀 NEXT").font(.system(size: 8, weight: .bold)).foregroundColor(.cyan)
            if let g = manager.basketballProvider.nextFixture() {
                Text("\(g.homeAbbrev) vs \(g.awayAbbrev)")
                    .font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
                Text(g.startDate, style: .relative)
                    .font(.system(size: 7)).foregroundColor(.gray)
            } else {
                Text("No upcoming").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .padding(6)
    }
}

private struct BasketballStandingsWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("🏀 TABLE").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
            let (rows, favIdx) = manager.basketballProvider.standingsWindow()
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 6) {
                    Text("\(row.position)").font(.system(size: 10, design: .monospaced)).frame(width: 16, alignment: .trailing)
                    Text(row.teamAbbrev).font(.system(size: 13, weight: idx == favIdx ? .bold : .medium))
                        .foregroundColor(idx == favIdx ? .yellow : .white)
                    Spacer()
                    Text("\(row.wins)-\(row.losses)").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(idx == favIdx ? .yellow : .gray)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx == favIdx ? Color.yellow.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

// MARK: - F1 Widgets

private struct F1LiveTimingWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFavoriteF1Driver) var favoriteDriver
    var body: some View {
        VStack(spacing: 2) {
            if let session = manager.f1Provider.currentSession, session.isLive {
                Text("🏎️ \(session.sessionName.uppercased())").font(.system(size: 8, weight: .bold)).foregroundColor(.red)
                let positions = manager.f1Provider.livePositions
                let top5 = Array(positions.prefix(5))
                ForEach(top5) { p in
                    HStack(spacing: 4) {
                        Text("P\(p.position)").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        Text(p.driverCode).font(.system(size: 8, weight: p.driverCode == favoriteDriver ? .bold : .regular))
                            .foregroundColor(p.driverCode == favoriteDriver ? .cyan : .white)
                        Spacer()
                        if let gap = p.gap { Text(gap).font(.system(size: 7, design: .monospaced)).foregroundColor(.gray) }
                    }
                }
                // Favorite outside top 5
                if !favoriteDriver.isEmpty,
                   !top5.contains(where: { $0.driverCode == favoriteDriver }),
                   let fav = positions.first(where: { $0.driverCode == favoriteDriver })
                {
                    Divider().background(Color.gray.opacity(0.3))
                    HStack(spacing: 4) {
                        Text("P\(fav.position)").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        Text(fav.driverCode).font(.system(size: 8, weight: .bold)).foregroundColor(.cyan)
                        Spacer()
                    }
                }
            } else {
                Text("🏎️ TIMING").font(.system(size: 8, weight: .bold)).foregroundColor(.gray)
                Text("No live session").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .padding(6)
    }
}

private struct F1CalendarWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("🏎️ CALENDAR").font(.system(size: 8, weight: .bold)).foregroundColor(.cyan)
            if let next = manager.f1Provider.nextSession() {
                Text(next.race.raceName).font(.system(size: 9, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(next.session.type).font(.system(size: 8)).foregroundColor(.gray)
                Text(next.session.date, style: .relative).font(.system(size: 7)).foregroundColor(.green)
            } else {
                Text("Season over").font(.system(size: 9)).foregroundColor(.gray)
            }
        }
        .padding(6)
    }
}

private struct F1WDCWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFavoriteF1Driver) var favoriteDriver
    var body: some View {
        VStack(spacing: 4) {
            Text("🏎️ WDC").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
            let (rows, favIdx) = manager.f1Provider.driverStandingsWindow()
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 6) {
                    Text("P\(row.position)").font(.system(size: 10, design: .monospaced)).frame(width: 20, alignment: .trailing)
                    Text(row.driverCode).font(.system(size: 13, weight: idx == favIdx ? .bold : .medium))
                        .foregroundColor(idx == favIdx ? .cyan : .white)
                    Spacer()
                    Text("\(Int(row.points))").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(idx == favIdx ? .cyan : .gray)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx == favIdx ? Color.cyan.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

private struct F1WCCWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("🏎️ WCC").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
            let (rows, favIdx) = manager.f1Provider.constructorStandingsWindow()
            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                HStack(spacing: 6) {
                    Text("P\(row.position)").font(.system(size: 10, design: .monospaced)).frame(width: 20, alignment: .trailing)
                    Text(row.teamName).font(.system(size: 13, weight: idx == favIdx ? .bold : .medium))
                        .foregroundColor(idx == favIdx ? .yellow : .white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(Int(row.points))").font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(idx == favIdx ? .yellow : .gray)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(idx == favIdx ? Color.yellow.opacity(0.12) : Color.clear)
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

//
//  SportsView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

// MARK: - Live Pulse Dot

private struct LiveDot: View {
    @State private var isAnimating = false
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 5, height: 5)
            .opacity(isAnimating ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

// MARK: - Main View

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
            case .footballLive: FootballLiveWidget()
            case .footballFixture: FootballFixtureWidget()
            case .footballStandings: FootballStandingsWidget()
            case .basketballLive: BasketballLiveWidget()
            case .basketballFixture: BasketballFixtureWidget()
            case .basketballStandings: BasketballStandingsWidget()
            case .f1LiveTiming: F1LiveTimingWidget()
            case .f1Calendar: F1CalendarWidget()
            case .f1WDC: F1WDCWidget()
            case .f1WCC: F1WCCWidget()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.linearGradient(
                    colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Football Widgets

private struct FootballLiveWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFavoriteFootballTeam) var favoriteTeam
    var body: some View {
        let live = manager.footballProvider.matches.filter(\.isLive)
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if !live.isEmpty { LiveDot() }
                Text("⚽ LIVE").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
            }
            if live.isEmpty {
                Spacer()
                Text("No live matches").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            } else {
                ForEach(live.prefix(3)) { m in
                    HStack(spacing: 4) {
                        Text(m.homeAbbrev)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(m.homeAbbrev == favoriteTeam ? .yellow : .white)
                        Spacer()
                        Text("\(m.homeScore ?? 0)-\(m.awayScore ?? 0)")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(m.awayAbbrev)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(m.awayAbbrev == favoriteTeam ? .yellow : .white)
                        if let min = m.minute {
                            HStack(spacing: 2) {
                                LiveDot()
                                Text("\(min)'")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

private struct FootballFixtureWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFavoriteFootballTeam) var favoriteTeam
    var body: some View {
        VStack(spacing: 3) {
            Text("⚽ NEXT").font(.system(size: 9, weight: .bold)).foregroundColor(.cyan)
            if let m = manager.footballProvider.nextFixture() {
                Spacer()
                HStack(spacing: 6) {
                    Text(m.homeAbbrev)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(m.homeAbbrev == favoriteTeam ? .yellow : .white)
                    Text("vs")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(m.awayAbbrev)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(m.awayAbbrev == favoriteTeam ? .yellow : .white)
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                Text(m.startDate, style: .relative)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                Spacer()
            } else {
                Spacer()
                Text("No upcoming").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
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
        let favs = manager.basketballProvider.favoriteAbbrevs
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if !live.isEmpty { LiveDot() }
                Text("🏀 LIVE").font(.system(size: 9, weight: .bold)).foregroundColor(.red)
            }
            if live.isEmpty {
                Spacer()
                Text("No live games").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            } else {
                ForEach(live.prefix(3)) { g in
                    HStack(spacing: 4) {
                        Text(g.homeAbbrev)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(favs.contains(g.homeAbbrev) ? .yellow : .white)
                        Spacer()
                        Text("\(g.homeScore ?? 0)-\(g.awayScore ?? 0)")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        Spacer()
                        Text(g.awayAbbrev)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(favs.contains(g.awayAbbrev) ? .yellow : .white)
                        if let q = g.period {
                            HStack(spacing: 2) {
                                LiveDot()
                                Text(q)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

private struct BasketballFixtureWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        let favs = manager.basketballProvider.favoriteAbbrevs
        VStack(spacing: 3) {
            Text("🏀 NEXT").font(.system(size: 9, weight: .bold)).foregroundColor(.cyan)
            if let g = manager.basketballProvider.nextFixture() {
                Spacer()
                HStack(spacing: 6) {
                    Text(g.homeAbbrev)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(favs.contains(g.homeAbbrev) ? .yellow : .white)
                    Text("vs")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(g.awayAbbrev)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(favs.contains(g.awayAbbrev) ? .yellow : .white)
                }
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                Text(g.startDate, style: .relative)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                Spacer()
            } else {
                Spacer()
                Text("No upcoming").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
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
        VStack(spacing: 3) {
            if let session = manager.f1Provider.currentSession, session.isLive {
                HStack(spacing: 4) {
                    LiveDot()
                    Text("🏎️ \(session.sessionName.uppercased())")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.red)
                }
                let positions = manager.f1Provider.livePositions
                let top5 = Array(positions.prefix(5))
                ForEach(top5) { p in
                    let isFav = p.driverCode == favoriteDriver
                    HStack(spacing: 4) {
                        Text("P\(p.position)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        Text(p.driverCode)
                            .font(.system(size: 11, weight: isFav ? .bold : .medium))
                            .foregroundColor(isFav ? .cyan : .white)
                        Spacer()
                        if let gap = p.gap {
                            Text(gap)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(isFav ? .cyan : .gray)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(isFav ? Color.cyan.opacity(0.12) : Color.clear)
                    )
                }
                // Favorite outside top 5
                if !favoriteDriver.isEmpty,
                   !top5.contains(where: { $0.driverCode == favoriteDriver }),
                   let fav = positions.first(where: { $0.driverCode == favoriteDriver })
                {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 0.5)
                    HStack(spacing: 4) {
                        Text("P\(fav.position)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        Text(fav.driverCode)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                        Spacer()
                    }
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.cyan.opacity(0.12)))
                }
            } else {
                Text("🏎️ TIMING").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                Spacer()
                Text("No live session").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

private struct F1CalendarWidget: View {
    @ObservedObject var manager = SportsManager.shared
    var body: some View {
        VStack(spacing: 4) {
            Text("🏎️ CALENDAR").font(.system(size: 9, weight: .bold)).foregroundColor(.cyan)
            if let next = manager.f1Provider.nextSession() {
                Spacer()
                HStack(spacing: 4) {
                    Text(next.race.countryFlag).font(.system(size: 16))
                    Text(next.race.raceName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                // Session type pill
                Text(next.session.type)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.6)))
                Text(next.session.date, style: .relative)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.green)
                Spacer()
            } else {
                Spacer()
                Text("Season over").font(.system(size: 11)).foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

private struct F1WDCWidget: View {
    @ObservedObject var manager = SportsManager.shared
    @Default(.sportsFavoriteF1Driver) var favoriteDriver
    var body: some View {
        VStack(spacing: 4) {
            Text("🏎️ WDC").font(.system(size: 9, weight: .bold)).foregroundColor(.yellow)
            let (rows, favIdx) = manager.f1Provider.driverStandingsWindow()
            if rows.isEmpty {
                Spacer()
                Text("No data yet").font(.system(size: 10)).foregroundColor(.gray)
                Text("Season not started").font(.system(size: 8)).foregroundColor(.gray.opacity(0.6))
                Spacer()
            } else {
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
            if rows.isEmpty {
                Spacer()
                Text("No data yet").font(.system(size: 10)).foregroundColor(.gray)
                Text("Season not started").font(.system(size: 8)).foregroundColor(.gray.opacity(0.6))
                Spacer()
            } else {
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
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 6)
    }
}

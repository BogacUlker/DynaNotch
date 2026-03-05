//
//  BasketballProvider.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import Foundation
import os

/// Fetches basketball (NBA) data from ESPN hidden API.
final class BasketballProvider: SportProvider {
    let sportType: SportType = .basketball
    private let logger = Logger(subsystem: "com.dynanotch.app", category: "BasketballProvider")

    private(set) var games: [BasketballGame] = []
    private(set) var standings: [BasketballStanding] = []

    func refresh() async throws {
        async let gamesTask: () = refreshGames()
        async let standingsTask: () = refreshStandings()
        _ = try await (gamesTask, standingsTask)
    }

    func liveEvents() -> [SportEvent] {
        games.filter(\.isLive).map { game in
            SportEvent(
                id: "bb-\(game.id)",
                type: .basketball,
                isLive: true,
                collapsedText: game.collapsedText,
                startDate: game.startDate
            )
        }
    }

    func nextFixture() -> BasketballGame? {
        let fav = Defaults[.sportsFavoriteBasketballTeam]
        guard !fav.isEmpty else { return games.first { $0.status == .scheduled } }
        return games.first { ($0.homeAbbrev == fav || $0.awayAbbrev == fav) && $0.status == .scheduled }
            ?? games.first { $0.status == .scheduled }
    }

    func standingsWindow() -> (rows: [BasketballStanding], favoriteIndex: Int?) {
        guard !standings.isEmpty else { return ([], nil) }
        let fav = Defaults[.sportsFavoriteBasketballTeam]
        guard !fav.isEmpty,
              let favIdx = standings.firstIndex(where: { $0.teamAbbrev == fav })
        else {
            return (Array(standings.prefix(5)), nil)
        }
        let start = max(0, min(favIdx - 2, standings.count - 5))
        let end = min(start + 5, standings.count)
        return (Array(standings[start..<end]), favIdx - start)
    }

    // MARK: - Picker Data

    var hasStandingsData: Bool { !standings.isEmpty }

    /// All teams from NBA standings, deduplicated by abbreviation, sorted by name.
    /// Format: "Los Angeles Lakers (LAL)"
    func allTeams() -> [(abbrev: String, displayName: String)] {
        var seen = Set<String>()
        var result: [(abbrev: String, displayName: String)] = []

        for team in standings {
            guard !team.teamAbbrev.isEmpty, !seen.contains(team.teamAbbrev) else { continue }
            seen.insert(team.teamAbbrev)
            result.append((
                abbrev: team.teamAbbrev,
                displayName: "\(team.teamName) (\(team.teamAbbrev))"
            ))
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - ESPN API

    private func refreshGames() async {
        do {
            // Fetch 7-day window so nextFixture() can find the favorite team's game
            let df = DateFormatter()
            df.dateFormat = "yyyyMMdd"
            let from = df.string(from: Date())
            let to = df.string(from: Date().addingTimeInterval(7 * 86400))
            let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard?dates=\(from)-\(to)")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let events = json["events"] as? [[String: Any]] ?? []
            logger.debug("Basketball scoreboard: \(events.count) events in \(from)-\(to)")
            games = events.compactMap(parseGame).sorted { $0.startDate < $1.startDate }
        } catch {
            logger.error("Basketball scoreboard error: \(error.localizedDescription)")
        }
    }

    private func refreshStandings() async {
        do {
            // NOTE: Standings use /apis/v2/ (not /apis/site/v2/ which returns only fullViewLink)
            let url = URL(string: "https://site.api.espn.com/apis/v2/sports/basketball/nba/standings")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let children = json["children"] as? [[String: Any]] ?? []
            if children.isEmpty {
                logger.warning("Basketball standings: no children in response (keys: \(Array(json.keys)))")
            }
            var all: [BasketballStanding] = []
            for conf in children {
                let confName = (conf["name"] as? String) ?? ""
                let standingsObj = conf["standings"] as? [String: Any] ?? [:]
                let entries = standingsObj["entries"] as? [[String: Any]] ?? []
                for (idx, entry) in entries.enumerated() {
                    if let s = parseStanding(entry, position: idx + 1, conference: confName) {
                        all.append(s)
                    }
                }
            }
            standings = all
            logger.info("Basketball standings: parsed \(all.count) teams from \(children.count) conferences")
        } catch {
            logger.error("Basketball standings error: \(error.localizedDescription)")
        }
    }

    private func parseGame(_ event: [String: Any]) -> BasketballGame? {
        guard let id = event["id"] as? String,
              let competitions = event["competitions"] as? [[String: Any]],
              let comp = competitions.first,
              let competitors = comp["competitors"] as? [[String: Any]],
              competitors.count >= 2
        else { return nil }

        let home = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
        let away = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]
        let homeTeam = home["team"] as? [String: Any] ?? [:]
        let awayTeam = away["team"] as? [String: Any] ?? [:]

        let statusInfo = comp["status"] as? [String: Any] ?? [:]
        let statusType = statusInfo["type"] as? [String: Any] ?? [:]
        let state = statusType["state"] as? String ?? "pre"
        let detail = statusType["shortDetail"] as? String

        let gameStatus: GameStatus
        switch state {
        case "in": gameStatus = .live
        case "post": gameStatus = .finished
        default: gameStatus = .scheduled
        }

        let dateStr = event["date"] as? String ?? ""
        let startDate = ESPNDateParser.parse(dateStr) ?? Date()

        var period: String?
        if gameStatus == .live, let d = detail {
            // detail is like "Q3 5:42" or "Half"
            period = d.components(separatedBy: " ").first
        }

        return BasketballGame(
            id: id,
            homeTeam: homeTeam["displayName"] as? String ?? "Home",
            awayTeam: awayTeam["displayName"] as? String ?? "Away",
            homeAbbrev: homeTeam["abbreviation"] as? String ?? "HOM",
            awayAbbrev: awayTeam["abbreviation"] as? String ?? "AWY",
            homeScore: Int(home["score"] as? String ?? ""),
            awayScore: Int(away["score"] as? String ?? ""),
            status: gameStatus,
            period: period,
            startDate: startDate
        )
    }

    private func parseStanding(_ entry: [String: Any], position: Int, conference: String) -> BasketballStanding? {
        let team = entry["team"] as? [String: Any] ?? [:]
        let stats = entry["stats"] as? [[String: Any]] ?? []

        func stat(_ name: String) -> Double {
            stats.first(where: { ($0["name"] as? String) == name })?["value"] as? Double ?? 0
        }

        return BasketballStanding(
            id: team["id"] as? String ?? "\(position)",
            position: position,
            teamName: team["displayName"] as? String ?? "",
            teamAbbrev: team["abbreviation"] as? String ?? "",
            wins: Int(stat("wins")),
            losses: Int(stat("losses")),
            winPct: stat("winPercent"),
            conference: conference
        )
    }
}

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

/// Fetches basketball data from ESPN (NBA) and EuroLeague v1 XML API.
final class BasketballProvider: SportProvider {
    let sportType: SportType = .basketball
    private let logger = Logger(subsystem: "com.dynanotch.app", category: "BasketballProvider")

    // NBA data
    private(set) var nbaGames: [BasketballGame] = []
    private(set) var nbaStandings: [BasketballStanding] = []

    // EuroLeague sub-provider
    private let euroLeagueProvider = EuroLeagueProvider()

    /// Merged games from all enabled sources, sorted by date.
    var games: [BasketballGame] {
        var all = Defaults[.enableBasketball] ? nbaGames : []
        if Defaults[.enableEuroLeague] {
            all.append(contentsOf: euroLeagueProvider.games)
        }
        return all.sorted { $0.startDate < $1.startDate }
    }

    /// NBA standings only.
    var standings: [BasketballStanding] { nbaStandings }

    /// EuroLeague standings.
    var euroLeagueStandings: [BasketballStanding] { euroLeagueProvider.standings }

    func refresh() async throws {
        await withTaskGroup(of: Void.self) { group in
            if Defaults[.enableBasketball] {
                group.addTask {
                    await self.refreshNBA()
                }
            }
            if Defaults[.enableEuroLeague] {
                group.addTask {
                    await self.euroLeagueProvider.refresh()
                }
            }
        }
    }

    func liveEvents() -> [SportEvent] {
        var events: [SportEvent] = []
        if Defaults[.enableBasketball] {
            events.append(contentsOf: nbaGames.filter(\.isLive).map { game in
                SportEvent(
                    id: "bb-\(game.id)",
                    type: .basketball,
                    isLive: true,
                    collapsedText: game.collapsedText,
                    startDate: game.startDate
                )
            })
        }
        if Defaults[.enableEuroLeague] {
            events.append(contentsOf: euroLeagueProvider.liveEvents())
        }
        return events
    }

    /// All favorite abbreviations across both leagues (for highlight matching in views).
    var favoriteAbbrevs: Set<String> {
        var set = Set<String>()
        let nba = Defaults[.sportsFavoriteBasketballTeam]
        let el = Defaults[.sportsFavoriteEuroLeagueTeam]
        if !nba.isEmpty { set.insert(nba) }
        if !el.isEmpty { set.insert(el) }
        return set
    }

    func nextFixture() -> BasketballGame? {
        let favs = favoriteAbbrevs
        let allGames = games
        guard !favs.isEmpty else { return allGames.first { $0.status == .scheduled } }
        return allGames.first { (favs.contains($0.homeAbbrev) || favs.contains($0.awayAbbrev)) && $0.status == .scheduled }
            ?? allGames.first { $0.status == .scheduled }
    }

    func standingsWindow() -> (rows: [BasketballStanding], favoriteIndex: Int?) {
        let nbaFav = Defaults[.sportsFavoriteBasketballTeam]
        let elFav = Defaults[.sportsFavoriteEuroLeagueTeam]

        // Determine which league's standings to show based on favorite teams
        let activeStandings: [BasketballStanding]
        let activeFav: String

        if !elFav.isEmpty && euroLeagueStandings.contains(where: { $0.teamAbbrev == elFav }) {
            // EuroLeague favorite exists and has data → show EuroLeague
            activeStandings = euroLeagueStandings
            activeFav = elFav
        } else if !nbaFav.isEmpty && !nbaStandings.isEmpty {
            // NBA favorite exists and has data → show NBA
            activeStandings = nbaStandings
            activeFav = nbaFav
        } else if !nbaStandings.isEmpty {
            activeStandings = nbaStandings
            activeFav = nbaFav
        } else {
            activeStandings = euroLeagueStandings
            activeFav = elFav
        }

        guard !activeStandings.isEmpty else { return ([], nil) }
        guard !activeFav.isEmpty,
              let favIdx = activeStandings.firstIndex(where: { $0.teamAbbrev == activeFav })
        else {
            return (Array(activeStandings.prefix(5)), nil)
        }
        let start = max(0, min(favIdx - 2, activeStandings.count - 5))
        let end = min(start + 5, activeStandings.count)
        return (Array(activeStandings[start..<end]), favIdx - start)
    }

    // MARK: - Picker Data

    var hasStandingsData: Bool { !nbaStandings.isEmpty || euroLeagueProvider.hasStandingsData }
    var hasNBAStandingsData: Bool { !nbaStandings.isEmpty }
    var hasEuroLeagueStandingsData: Bool { euroLeagueProvider.hasStandingsData }

    /// NBA teams only, for the NBA favorite picker.
    func allNBATeams() -> [(abbrev: String, displayName: String)] {
        var seen = Set<String>()
        var result: [(abbrev: String, displayName: String)] = []
        for team in nbaStandings {
            guard !team.teamAbbrev.isEmpty, !seen.contains(team.teamAbbrev) else { continue }
            seen.insert(team.teamAbbrev)
            result.append((
                abbrev: team.teamAbbrev,
                displayName: "\(team.teamName) (\(team.teamAbbrev))"
            ))
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    /// EuroLeague teams only, for the EuroLeague favorite picker.
    func allEuroLeagueTeams() -> [(abbrev: String, displayName: String)] {
        euroLeagueProvider.allTeams()
    }

    /// All teams combined (NBA + EuroLeague), used for logging / general queries.
    func allTeams() -> [(abbrev: String, displayName: String)] {
        var result = allNBATeams()
        result.append(contentsOf: allEuroLeagueTeams())
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - NBA (ESPN API)

    private func refreshNBA() async {
        async let gamesTask: () = refreshNBAGames()
        async let standingsTask: () = refreshNBAStandings()
        _ = await (gamesTask, standingsTask)
    }

    private func refreshNBAGames() async {
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
            nbaGames = events.compactMap(parseGame).sorted { $0.startDate < $1.startDate }
        } catch {
            logger.error("Basketball scoreboard error: \(error.localizedDescription)")
        }
    }

    private func refreshNBAStandings() async {
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
            nbaStandings = all
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

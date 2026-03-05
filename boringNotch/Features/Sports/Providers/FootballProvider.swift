//
//  FootballProvider.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import Foundation
import os

/// Fetches football data from ESPN hidden API.
/// Endpoints:
///   Scoreboard: site.api.espn.com/apis/site/v2/sports/soccer/{league}/scoreboard
///   Standings:  site.api.espn.com/apis/site/v2/sports/soccer/{league}/standings
final class FootballProvider: SportProvider {
    let sportType: SportType = .football
    private let logger = Logger(subsystem: "com.dynanotch.app", category: "FootballProvider")

    private(set) var matches: [FootballMatch] = []
    private(set) var standings: [String: [FootballStanding]] = [:]

    private enum FetchResult {
        case scoreboard([FootballMatch])
        case standings(String, [FootballStanding])
    }

    func refresh() async throws {
        let leagues = Defaults[.sportsFootballLeagues]
        guard !leagues.isEmpty else {
            logger.info("Football refresh skipped: no leagues selected")
            return
        }

        var allMatches: [FootballMatch] = []
        var allStandings: [String: [FootballStanding]] = [:]

        // Collect results via for-await (sequential consumption) to avoid data race
        await withTaskGroup(of: FetchResult.self) { group in
            for league in leagues {
                group.addTask { [weak self] in
                    guard let self else { return .scoreboard([]) }
                    do {
                        let m = try await self.fetchScoreboard(league: league.id)
                        return .scoreboard(m)
                    } catch {
                        self.logger.error("Football scoreboard error (\(league.id)): \(error.localizedDescription)")
                        return .scoreboard([])
                    }
                }
                group.addTask { [weak self] in
                    guard let self else { return .standings(league.id, []) }
                    do {
                        let s = try await self.fetchStandings(league: league.id)
                        return .standings(league.id, s)
                    } catch {
                        self.logger.error("Football standings error (\(league.id)): \(error.localizedDescription)")
                        return .standings(league.id, [])
                    }
                }
            }
            for await result in group {
                switch result {
                case .scoreboard(let m):
                    allMatches.append(contentsOf: m)
                case .standings(let leagueId, let s):
                    if !s.isEmpty { allStandings[leagueId] = s }
                }
            }
        }

        matches = allMatches.sorted { $0.startDate < $1.startDate }
        standings = allStandings
        logger.info("Football refresh: \(allMatches.count) matches, standings for \(allStandings.count) leagues (\(allStandings.values.map(\.count).reduce(0, +)) teams)")
    }

    func liveEvents() -> [SportEvent] {
        matches.filter(\.isLive).map { match in
            SportEvent(
                id: "fb-\(match.id)",
                type: .football,
                isLive: true,
                collapsedText: match.collapsedText,
                startDate: match.startDate
            )
        }
    }

    /// Next upcoming match for the favorite team.
    func nextFixture() -> FootballMatch? {
        let fav = Defaults[.sportsFavoriteFootballTeam]
        guard !fav.isEmpty else { return matches.first { $0.status == .scheduled } }
        return matches.first { ($0.homeAbbrev == fav || $0.awayAbbrev == fav) && $0.status == .scheduled }
            ?? matches.first { $0.status == .scheduled }
    }

    /// Standings for a league, 5-row window centered on favorite team.
    func standingsWindow(league: String) -> (rows: [FootballStanding], favoriteIndex: Int?) {
        guard let all = standings[league], !all.isEmpty else { return ([], nil) }
        let fav = Defaults[.sportsFavoriteFootballTeam]
        guard !fav.isEmpty,
              let favIdx = all.firstIndex(where: { $0.teamAbbrev == fav })
        else {
            return (Array(all.prefix(5)), nil)
        }
        let start = max(0, min(favIdx - 2, all.count - 5))
        let end = min(start + 5, all.count)
        let window = Array(all[start..<end])
        let relIdx = favIdx - start
        return (window, relIdx)
    }

    // MARK: - Picker Data

    var hasStandingsData: Bool { !standings.isEmpty }

    /// Checks if standings data exists for ALL given leagues.
    func hasStandingsForAll(leagues: [FootballLeague]) -> Bool {
        guard !leagues.isEmpty else { return true }
        return leagues.allSatisfy { standings[$0.id] != nil }
    }

    /// All teams from active leagues, deduplicated by abbreviation, sorted by name.
    /// Format: "Liverpool FC (LIV) - Premier League"
    func allTeams() -> [(abbrev: String, displayName: String)] {
        let leagueNameMap = Dictionary(
            uniqueKeysWithValues: FootballLeague.allLeagues.map { ($0.id, $0.name) }
        )
        var seen = Set<String>()
        var result: [(abbrev: String, displayName: String)] = []

        for (leagueId, leagueStandings) in standings {
            let leagueName = leagueNameMap[leagueId] ?? leagueId
            for team in leagueStandings {
                guard !team.teamAbbrev.isEmpty, !seen.contains(team.teamAbbrev) else { continue }
                seen.insert(team.teamAbbrev)
                result.append((
                    abbrev: team.teamAbbrev,
                    displayName: "\(team.teamName) (\(team.teamAbbrev)) - \(leagueName)"
                ))
            }
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    // MARK: - ESPN API

    private func fetchScoreboard(league: String) async throws -> [FootballMatch] {
        // Fetch 14-day window so nextFixture() can find the favorite team's match
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let from = df.string(from: Date())
        let to = df.string(from: Date().addingTimeInterval(14 * 86400))
        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/soccer/\(league)/scoreboard?dates=\(from)-\(to)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let events = json["events"] as? [[String: Any]] ?? []
        logger.debug("Football scoreboard (\(league)): \(events.count) events in \(from)-\(to)")
        return events.compactMap { parseMatch($0, league: league) }
    }

    private func fetchStandings(league: String) async throws -> [FootballStanding] {
        // NOTE: Standings use /apis/v2/ (not /apis/site/v2/ which returns empty JSON)
        let url = URL(string: "https://site.api.espn.com/apis/v2/sports/soccer/\(league)/standings")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        let children = json["children"] as? [[String: Any]] ?? []
        guard let first = children.first else {
            logger.warning("Football standings (\(league)): no children in response (keys: \(Array(json.keys)))")
            return []
        }
        let standingsArr = first["standings"] as? [String: Any] ?? [:]
        let entries = standingsArr["entries"] as? [[String: Any]] ?? []
        let result = entries.enumerated().compactMap { idx, entry in
            parseStanding(entry, position: idx + 1)
        }
        logger.debug("Football standings (\(league)): parsed \(result.count) teams from \(entries.count) entries")
        return result
    }

    private func parseMatch(_ event: [String: Any], league: String) -> FootballMatch? {
        guard let id = event["id"] as? String,
              let competitions = event["competitions"] as? [[String: Any]],
              let comp = competitions.first,
              let competitors = comp["competitors"] as? [[String: Any]],
              competitors.count >= 2
        else { return nil }

        let home = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
        let away = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]

        let homeTeamInfo = home["team"] as? [String: Any] ?? [:]
        let awayTeamInfo = away["team"] as? [String: Any] ?? [:]

        let statusInfo = comp["status"] as? [String: Any] ?? [:]
        let statusType = statusInfo["type"] as? [String: Any] ?? [:]
        let state = statusType["state"] as? String ?? "pre"
        let clock = statusType["detail"] as? String

        let matchStatus: MatchStatus
        switch state {
        case "in": matchStatus = .live
        case "post": matchStatus = .finished
        default: matchStatus = .scheduled
        }

        let dateStr = event["date"] as? String ?? ""
        let startDate = ESPNDateParser.parse(dateStr) ?? Date()

        var minute: Int?
        if matchStatus == .live, let clockStr = clock {
            let digits = clockStr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            minute = Int(digits)
        }

        return FootballMatch(
            id: id,
            league: league,
            homeTeam: homeTeamInfo["displayName"] as? String ?? "Home",
            awayTeam: awayTeamInfo["displayName"] as? String ?? "Away",
            homeAbbrev: homeTeamInfo["abbreviation"] as? String ?? "HOM",
            awayAbbrev: awayTeamInfo["abbreviation"] as? String ?? "AWY",
            homeScore: Int(home["score"] as? String ?? ""),
            awayScore: Int(away["score"] as? String ?? ""),
            status: matchStatus,
            minute: minute,
            startDate: startDate
        )
    }

    private func parseStanding(_ entry: [String: Any], position: Int) -> FootballStanding? {
        let teamInfo = entry["team"] as? [String: Any] ?? [:]
        let stats = entry["stats"] as? [[String: Any]] ?? []

        func stat(_ name: String) -> Int {
            if let s = stats.first(where: { ($0["name"] as? String) == name }) {
                return Int(s["value"] as? Double ?? 0)
            }
            return 0
        }

        return FootballStanding(
            id: teamInfo["id"] as? String ?? "\(position)",
            position: position,
            teamName: teamInfo["displayName"] as? String ?? "",
            teamAbbrev: teamInfo["abbreviation"] as? String ?? "",
            played: stat("gamesPlayed"),
            won: stat("wins"),
            drawn: stat("ties"),
            lost: stat("losses"),
            points: stat("points"),
            goalDifference: stat("pointDifferential")
        )
    }
}

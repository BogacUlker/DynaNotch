//
//  F1Provider.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import Foundation
import os

/// Fetches F1 data from OpenF1 (live) and Jolpica/Ergast (standings, calendar).
final class F1Provider: SportProvider {
    let sportType: SportType = .f1
    private let logger = Logger(subsystem: "com.dynanotch.app", category: "F1Provider")

    private(set) var currentSession: F1Session?
    private(set) var livePositions: [F1LivePosition] = []
    private(set) var races: [F1Race] = []
    private(set) var driverStandings: [F1DriverStanding] = []
    private(set) var constructorStandings: [F1ConstructorStanding] = []

    func refresh() async throws {
        async let liveTask: () = refreshLiveSession()
        async let calTask: () = refreshCalendar()
        async let wdcTask: () = refreshDriverStandings()
        async let wccTask: () = refreshConstructorStandings()
        _ = try await (liveTask, calTask, wdcTask, wccTask)
    }

    func liveEvents() -> [SportEvent] {
        guard let session = currentSession, session.isLive,
              let leader = livePositions.first
        else { return [] }

        let lapStr: String
        if let cur = session.currentLap, let tot = session.totalLaps {
            lapStr = " L\(cur)/\(tot)"
        } else {
            lapStr = ""
        }
        let text = "\(leader.driverCode) P1\(lapStr)"

        return [SportEvent(
            id: "f1-live",
            type: .f1,
            isLive: true,
            collapsedText: text,
            startDate: session.startDate
        )]
    }

    /// Next upcoming session (race, qualifying, etc.)
    func nextSession() -> (race: F1Race, session: F1RaceSession)? {
        let now = Date()
        for race in races {
            for sess in race.sessions where sess.date > now {
                return (race, sess)
            }
        }
        return nil
    }

    /// Driver standings: top 5 + favorite if outside top 5.
    func driverStandingsWindow() -> (rows: [F1DriverStanding], favoriteIndex: Int?) {
        guard !driverStandings.isEmpty else { return ([], nil) }
        let fav = Defaults[.sportsFavoriteF1Driver]
        var result = Array(driverStandings.prefix(5))
        var favIdx: Int?

        if !fav.isEmpty, let idx = driverStandings.firstIndex(where: { $0.driverCode == fav }) {
            if idx < 5 {
                favIdx = idx
            } else {
                result.append(driverStandings[idx])
                favIdx = result.count - 1
            }
        }
        return (result, favIdx)
    }

    /// Constructor standings: top 5 + favorite if outside top 5.
    func constructorStandingsWindow() -> (rows: [F1ConstructorStanding], favoriteIndex: Int?) {
        guard !constructorStandings.isEmpty else { return ([], nil) }
        let fav = Defaults[.sportsFavoriteF1Driver]
        // Find constructor of favorite driver
        let favTeam = driverStandings.first(where: { $0.driverCode == fav })?.team ?? ""
        var result = Array(constructorStandings.prefix(5))
        var favIdx: Int?

        if !favTeam.isEmpty, let idx = constructorStandings.firstIndex(where: { $0.teamName == favTeam }) {
            if idx < 5 {
                favIdx = idx
            } else {
                result.append(constructorStandings[idx])
                favIdx = result.count - 1
            }
        }
        return (result, favIdx)
    }

    // MARK: - Picker Data

    var hasDriverData: Bool { !driverStandings.isEmpty }

    /// All drivers from WDC standings, in championship order.
    /// Format: "Max Verstappen - Red Bull (VER)"
    func allDrivers() -> [(code: String, displayName: String)] {
        driverStandings.compactMap { driver in
            guard !driver.driverCode.isEmpty else { return nil }
            return (
                code: driver.driverCode,
                displayName: "\(driver.driverName) - \(driver.team) (\(driver.driverCode))"
            )
        }
    }

    // MARK: - OpenF1 API (Live)

    private func refreshLiveSession() async {
        do {
            // Check latest session
            let sessURL = URL(string: "https://api.openf1.org/v1/sessions?session_key=latest")!
            let (sessData, _) = try await URLSession.shared.data(from: sessURL)
            let sessArr = try JSONSerialization.jsonObject(with: sessData) as? [[String: Any]] ?? []
            guard let sessInfo = sessArr.first else {
                currentSession = nil
                livePositions = []
                return
            }

            let sessionKey = sessInfo["session_key"] as? Int ?? 0
            let dateStr = sessInfo["date_start"] as? String ?? ""
            let dateEnd = sessInfo["date_end"] as? String

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startDate = formatter.date(from: dateStr) ?? Date()
            let endDate = dateEnd.flatMap { formatter.date(from: $0) }

            let isLive: Bool
            if let end = endDate {
                isLive = Date() < end
            } else {
                isLive = false
            }

            currentSession = F1Session(
                id: "\(sessionKey)",
                sessionName: sessInfo["session_name"] as? String ?? "Session",
                raceName: sessInfo["meeting_name"] as? String ?? "",
                isLive: isLive,
                startDate: startDate
            )

            if isLive {
                let posURL = URL(string: "https://api.openf1.org/v1/position?session_key=\(sessionKey)&position<=20")!
                let (posData, _) = try await URLSession.shared.data(from: posURL)
                let posArr = try JSONSerialization.jsonObject(with: posData) as? [[String: Any]] ?? []
                // Get latest position for each driver
                var latest: [Int: [String: Any]] = [:] // driver_number -> latest entry
                for entry in posArr {
                    if let num = entry["driver_number"] as? Int {
                        latest[num] = entry
                    }
                }
                livePositions = latest.values.compactMap(parsePosition).sorted { $0.position < $1.position }
            } else {
                livePositions = []
            }
        } catch {
            logger.error("F1 live session error: \(error.localizedDescription)")
        }
    }

    private func parsePosition(_ entry: [String: Any]) -> F1LivePosition? {
        guard let pos = entry["position"] as? Int,
              let num = entry["driver_number"] as? Int
        else { return nil }
        // Driver code mapping is limited from OpenF1; we use number as fallback
        let code = driverCodeFromNumber(num)
        return F1LivePosition(
            position: pos,
            driverCode: code,
            driverName: code,
            team: "",
            gap: nil
        )
    }

    private func driverCodeFromNumber(_ num: Int) -> String {
        // Common F1 driver numbers → codes
        let map: [Int: String] = [
            1: "VER", 11: "PER", 44: "HAM", 63: "RUS",
            16: "LEC", 55: "SAI", 4: "NOR", 81: "PIA",
            14: "ALO", 18: "STR", 10: "GAS", 31: "OCO",
            23: "ALB", 2: "SAR", 27: "HUL", 20: "MAG",
            22: "TSU", 3: "RIC", 77: "BOT", 24: "ZHO",
        ]
        return map[num] ?? "\(num)"
    }

    // MARK: - Jolpica API (Calendar, Standings)

    private func refreshCalendar() async {
        do {
            let url = URL(string: "https://api.jolpi.ca/ergast/f1/current.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let mrData = json["MRData"] as? [String: Any] ?? [:]
            let raceTable = mrData["RaceTable"] as? [String: Any] ?? [:]
            let season = raceTable["season"] as? String ?? "unknown"
            let racesArr = raceTable["Races"] as? [[String: Any]] ?? []

            races = racesArr.compactMap(parseRace).sorted { $0.date < $1.date }
            let totalSessions = races.reduce(0) { $0 + $1.sessions.count }
            logger.info("F1 calendar (\(season)): \(self.races.count) races, \(totalSessions) sessions")
        } catch {
            logger.error("F1 calendar error: \(error.localizedDescription)")
        }
    }

    private func refreshDriverStandings() async {
        do {
            let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/driverStandings.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let mrData = json["MRData"] as? [String: Any] ?? [:]
            let table = mrData["StandingsTable"] as? [String: Any] ?? [:]
            let season = table["season"] as? String ?? "unknown"
            let lists = table["StandingsLists"] as? [[String: Any]] ?? []

            if let first = lists.first {
                let standings = first["DriverStandings"] as? [[String: Any]] ?? []
                self.driverStandings = standings.compactMap(self.parseDriverStanding)
                logger.info("F1 WDC (\(season)): parsed \(self.driverStandings.count) drivers")
            } else {
                self.driverStandings = []
                logger.info("F1 WDC (\(season)): no standings yet (season not started)")
            }
        } catch {
            logger.error("F1 WDC error: \(error.localizedDescription)")
        }
    }

    private func refreshConstructorStandings() async {
        do {
            let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/constructorStandings.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            let mrData = json["MRData"] as? [String: Any] ?? [:]
            let table = mrData["StandingsTable"] as? [String: Any] ?? [:]
            let season = table["season"] as? String ?? "unknown"
            let lists = table["StandingsLists"] as? [[String: Any]] ?? []

            if let first = lists.first {
                let standings = first["ConstructorStandings"] as? [[String: Any]] ?? []
                self.constructorStandings = standings.compactMap(self.parseConstructorStanding)
                logger.info("F1 WCC (\(season)): parsed \(self.constructorStandings.count) constructors")
            } else {
                self.constructorStandings = []
                logger.info("F1 WCC (\(season)): no standings yet (season not started)")
            }
        } catch {
            logger.error("F1 WCC error: \(error.localizedDescription)")
        }
    }

    private func parseRace(_ data: [String: Any]) -> F1Race? {
        guard let round = Int(data["round"] as? String ?? ""),
              let raceName = data["raceName"] as? String,
              let circuit = data["Circuit"] as? [String: Any],
              let dateStr = data["date"] as? String
        else { return nil }

        let formatter = ISO8601DateFormatter()

        let timeStr = data["time"] as? String ?? "14:00:00Z"
        let raceDate = formatter.date(from: "\(dateStr)T\(timeStr)") ?? Date.distantFuture

        // Parse all weekend sessions from API
        let sessionKeys: [(key: String, name: String)] = [
            ("FirstPractice", "FP1"),
            ("SecondPractice", "FP2"),
            ("ThirdPractice", "FP3"),
            ("Qualifying", "Qualifying"),
            ("Sprint", "Sprint"),
            ("SprintQualifying", "Sprint Qualifying"),
            ("SprintShootout", "Sprint Shootout"),
        ]

        var sessions: [F1RaceSession] = []
        for (key, name) in sessionKeys {
            if let obj = data[key] as? [String: Any],
               let d = obj["date"] as? String,
               let t = obj["time"] as? String,
               let date = formatter.date(from: "\(d)T\(t)")
            {
                sessions.append(F1RaceSession(type: name, date: date))
            }
        }
        sessions.append(F1RaceSession(type: "Race", date: raceDate))
        sessions.sort { $0.date < $1.date }

        let location = circuit["Location"] as? [String: Any] ?? [:]
        return F1Race(
            id: "\(round)",
            round: round,
            raceName: raceName,
            circuitName: circuit["circuitName"] as? String ?? "",
            country: location["country"] as? String ?? "",
            date: raceDate,
            sessions: sessions
        )
    }

    private func parseDriverStanding(_ data: [String: Any]) -> F1DriverStanding? {
        guard let pos = Int(data["position"] as? String ?? ""),
              let pts = Double(data["points"] as? String ?? ""),
              let driver = data["Driver"] as? [String: Any],
              let constructors = data["Constructors"] as? [[String: Any]]
        else { return nil }

        let code = driver["code"] as? String ?? ""
        let given = driver["givenName"] as? String ?? ""
        let family = driver["familyName"] as? String ?? ""
        let team = constructors.first?["name"] as? String ?? ""

        return F1DriverStanding(
            position: pos,
            driverCode: code,
            driverName: "\(given) \(family)",
            team: team,
            points: pts
        )
    }

    private func parseConstructorStanding(_ data: [String: Any]) -> F1ConstructorStanding? {
        guard let pos = Int(data["position"] as? String ?? ""),
              let pts = Double(data["points"] as? String ?? ""),
              let constructor = data["Constructor"] as? [String: Any]
        else { return nil }

        return F1ConstructorStanding(
            position: pos,
            teamName: constructor["name"] as? String ?? "",
            points: pts
        )
    }
}

//
//  FootballModels.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation

enum MatchStatus: String, Codable {
    case scheduled
    case live
    case halftime
    case finished
}

struct FootballMatch: Identifiable {
    let id: String
    let league: String
    let homeTeam: String
    let awayTeam: String
    let homeAbbrev: String
    let awayAbbrev: String
    var homeScore: Int?
    var awayScore: Int?
    var status: MatchStatus
    var minute: Int?
    let startDate: Date

    var isLive: Bool { status == .live || status == .halftime }

    /// e.g. "FB 2-1 GS 67'"
    var collapsedText: String {
        let h = homeScore.map(String.init) ?? "-"
        let a = awayScore.map(String.init) ?? "-"
        let time = minute.map { "\($0)'" } ?? ""
        return "\(homeAbbrev) \(h)-\(a) \(awayAbbrev) \(time)".trimmingCharacters(in: .whitespaces)
    }
}

struct FootballStanding: Identifiable {
    let id: String
    let position: Int
    let teamName: String
    let teamAbbrev: String
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let points: Int
    let goalDifference: Int
}

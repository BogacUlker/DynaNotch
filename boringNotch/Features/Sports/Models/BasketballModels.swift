//
//  BasketballModels.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation

enum GameStatus: String, Codable {
    case scheduled
    case live
    case halftime
    case finished
}

struct BasketballGame: Identifiable {
    let id: String
    let homeTeam: String
    let awayTeam: String
    let homeAbbrev: String
    let awayAbbrev: String
    var homeScore: Int?
    var awayScore: Int?
    var status: GameStatus
    var period: String? // "Q1", "Q2", "Q3", "Q4", "OT"
    let startDate: Date

    var isLive: Bool { status == .live || status == .halftime }

    /// e.g. "LAL 98-102 BOS Q4"
    var collapsedText: String {
        let h = homeScore.map(String.init) ?? "-"
        let a = awayScore.map(String.init) ?? "-"
        let q = period ?? ""
        return "\(homeAbbrev) \(h)-\(a) \(awayAbbrev) \(q)".trimmingCharacters(in: .whitespaces)
    }
}

struct BasketballStanding: Identifiable {
    let id: String
    let position: Int
    let teamName: String
    let teamAbbrev: String
    let wins: Int
    let losses: Int
    let winPct: Double
    let conference: String
}

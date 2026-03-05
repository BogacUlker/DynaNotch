//
//  F1Models.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation

struct F1Session: Identifiable {
    let id: String
    let sessionName: String // "Race", "Qualifying", "Sprint", etc.
    let raceName: String
    let isLive: Bool
    let startDate: Date
    var currentLap: Int?
    var totalLaps: Int?
}

struct F1LivePosition: Identifiable {
    var id: String { "\(driverCode)-\(position)" }
    let position: Int
    let driverCode: String // "VER", "HAM"
    let driverName: String
    let team: String
    var gap: String? // "+3.2s"
    var currentLap: Int?
}

struct F1Race: Identifiable {
    let id: String
    let round: Int
    let raceName: String
    let circuitName: String
    let date: Date
    var sessions: [F1RaceSession] = []
}

struct F1RaceSession: Identifiable {
    var id: String { "\(type)-\(date)" }
    let type: String // "FP1", "Qualifying", "Race", etc.
    let date: Date
}

struct F1DriverStanding: Identifiable {
    var id: String { driverCode }
    let position: Int
    let driverCode: String
    let driverName: String
    let team: String
    let points: Double
}

struct F1ConstructorStanding: Identifiable {
    var id: String { teamName }
    let position: Int
    let teamName: String
    let points: Double
}

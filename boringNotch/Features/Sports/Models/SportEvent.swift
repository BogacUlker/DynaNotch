//
//  SportEvent.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import Foundation

enum SportType: String, Codable, CaseIterable, Identifiable, Defaults.Serializable {
    case football
    case basketball
    case f1

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .football: return "⚽"
        case .basketball: return "🏀"
        case .f1: return "🏎️"
        }
    }

    var displayName: String {
        switch self {
        case .football: return "Football"
        case .basketball: return "Basketball"
        case .f1: return "Formula 1"
        }
    }
}

struct SportEvent: Identifiable {
    let id: String
    let type: SportType
    let isLive: Bool
    /// Short collapsed text, e.g. "FB 2-1 GS 67'"
    let collapsedText: String
    let startDate: Date
}

/// Widget types that can be assigned to the 3 expanded-view slots.
enum SportsWidgetKind: String, CaseIterable, Identifiable, Codable, Defaults.Serializable {
    // Football
    case footballLive = "football_live"
    case footballFixture = "football_fixture"
    case footballStandings = "football_standings"
    // Basketball
    case basketballLive = "basketball_live"
    case basketballFixture = "basketball_fixture"
    case basketballStandings = "basketball_standings"
    // F1
    case f1LiveTiming = "f1_live_timing"
    case f1Calendar = "f1_calendar"
    case f1WDC = "f1_wdc"
    case f1WCC = "f1_wcc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .footballLive: return "⚽ Live Score"
        case .footballFixture: return "⚽ Next Match"
        case .footballStandings: return "⚽ Standings"
        case .basketballLive: return "🏀 Live Score"
        case .basketballFixture: return "🏀 Next Game"
        case .basketballStandings: return "🏀 Standings"
        case .f1LiveTiming: return "🏎️ Live Timing"
        case .f1Calendar: return "🏎️ Race Calendar"
        case .f1WDC: return "🏎️ WDC Standings"
        case .f1WCC: return "🏎️ WCC Standings"
        }
    }

    var sportType: SportType {
        switch self {
        case .footballLive, .footballFixture, .footballStandings: return .football
        case .basketballLive, .basketballFixture, .basketballStandings: return .basketball
        case .f1LiveTiming, .f1Calendar, .f1WDC, .f1WCC: return .f1
        }
    }
}

// MARK: - Date Parsing

/// Parses ISO 8601 dates from ESPN API.
/// ESPN sometimes omits seconds ("2026-03-07T13:00Z") which the default
/// ISO8601DateFormatter cannot parse. This helper normalizes the string first.
enum ESPNDateParser {
    static func parse(_ dateStr: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateStr) { return date }
        // Insert missing seconds: "T13:00Z" → "T13:00:00Z"
        let normalized = dateStr.replacingOccurrences(
            of: #"T(\d{2}:\d{2})Z"#,
            with: "T$1:00Z",
            options: .regularExpression
        )
        return formatter.date(from: normalized)
    }
}

/// Identifies a football league in the ESPN API.
struct FootballLeague: Identifiable, Hashable, Codable, Defaults.Serializable {
    let id: String   // ESPN slug, e.g. "eng.1"
    let name: String // Display name

    static let allLeagues: [FootballLeague] = [
        .init(id: "eng.1", name: "Premier League"),
        .init(id: "esp.1", name: "La Liga"),
        .init(id: "ger.1", name: "Bundesliga"),
        .init(id: "ita.1", name: "Serie A"),
        .init(id: "fra.1", name: "Ligue 1"),
        .init(id: "tur.1", name: "Süper Lig"),
        .init(id: "por.1", name: "Primeira Liga"),
        .init(id: "ned.1", name: "Eredivisie"),
        .init(id: "eng.2", name: "Championship"),
        .init(id: "uefa.champions", name: "Champions League"),
    ]
}

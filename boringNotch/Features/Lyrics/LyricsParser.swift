//
//  LyricsParser.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation

/// A single timestamped lyric line from an LRC file.
struct LyricLine: Equatable, Codable {
    let time: TimeInterval
    let text: String
}

/// Parsed lyrics result containing both synced and plain lyrics.
struct ParsedLyrics: Codable {
    let syncedLines: [LyricLine]
    let plainText: String

    var hasSyncedLyrics: Bool { !syncedLines.isEmpty }
    var isEmpty: Bool { syncedLines.isEmpty && plainText.isEmpty }
}

enum LyricsParser {

    // MARK: - LRC Parsing

    /// Parses an LRC formatted string into an array of `LyricLine`, sorted by time.
    /// Supports `[mm:ss.xx]`, `[mm:ss]`, and `[m:ss.xxx]` formats.
    static func parseLRC(_ lrc: String) -> [LyricLine] {
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return []
        }

        let nsString = lrc as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var results: [LyricLine] = []

        regex.enumerateMatches(in: lrc, range: fullRange) { match, _, _ in
            guard let match = match else { return }

            let minStr = nsString.substring(with: match.range(at: 1))
            let secStr = nsString.substring(with: match.range(at: 2))
            let fracRange = match.range(at: 3)
            let fracStr = fracRange.location != NSNotFound ? nsString.substring(with: fracRange) : "0"

            let minutes = Double(minStr) ?? 0
            let seconds = Double(secStr) ?? 0

            // Handle variable fraction length: .xx = centiseconds, .xxx = milliseconds
            let fracValue = Double(fracStr) ?? 0
            let fraction: Double
            if fracStr.count <= 2 {
                fraction = fracValue / 100.0
            } else {
                fraction = fracValue / 1000.0
            }

            let time = minutes * 60.0 + seconds + fraction
            let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

            if !text.isEmpty {
                results.append(LyricLine(time: time, text: text))
            }
        }

        return results.sorted { $0.time < $1.time }
    }

    // MARK: - Current Line Lookup

    /// Binary search to find the lyric line index at a given elapsed time.
    /// Returns the index of the last line whose time <= elapsed, or nil if no lines match.
    static func lineIndex(in lines: [LyricLine], at elapsed: TimeInterval) -> Int? {
        guard !lines.isEmpty else { return nil }
        // If elapsed is before the first line, return nil
        if elapsed < lines[0].time { return nil }

        var low = 0
        var high = lines.count - 1
        var result = 0

        while low <= high {
            let mid = (low + high) / 2
            if lines[mid].time <= elapsed {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    /// Returns the lyric text at the given elapsed time.
    static func lineText(in lines: [LyricLine], at elapsed: TimeInterval) -> String {
        guard let idx = lineIndex(in: lines, at: elapsed) else {
            return lines.first?.text ?? ""
        }
        return lines[idx].text
    }
}

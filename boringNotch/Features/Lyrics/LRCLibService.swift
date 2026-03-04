//
//  LRCLibService.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation
import os

/// Response model for the LRCLIB search API.
struct LRCLibResult: Decodable {
    let id: Int
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?
}

/// LRCLIB API client for fetching lyrics.
enum LRCLibService {

    private static let logger = Logger(subsystem: "com.dynanotch", category: "LRCLib")
    private static let baseURL = "https://lrclib.net/api"

    /// Search for lyrics by track name and artist.
    /// Returns the best match, preferring results with synced lyrics.
    static func search(title: String, artist: String, album: String? = nil, duration: TimeInterval? = nil) async throws -> LRCLibResult? {
        let cleanTitle = normalizeQuery(title)
        let cleanArtist = normalizeQuery(artist)

        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        var urlString = "\(baseURL)/search?track_name=\(encodedTitle)&artist_name=\(encodedArtist)"

        if let album = album,
           let encodedAlbum = normalizeQuery(album).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "&album_name=\(encodedAlbum)"
        }

        guard let url = URL(string: urlString) else {
            logger.warning("Invalid URL: \(urlString)")
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("DynaNotch/2.0.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            logger.warning("Non-HTTP response from LRCLIB")
            return nil
        }

        guard http.statusCode == 200 else {
            logger.warning("LRCLIB returned status \(http.statusCode)")
            return nil
        }

        let results = try JSONDecoder().decode([LRCLibResult].self, from: data)

        guard !results.isEmpty else {
            return nil
        }

        // Prefer results with synced lyrics, then filter by duration match if available
        let sortedResults = results.sorted { a, b in
            let aHasSynced = a.syncedLyrics?.isEmpty == false
            let bHasSynced = b.syncedLyrics?.isEmpty == false
            if aHasSynced != bHasSynced { return aHasSynced }

            // If both have synced lyrics, prefer closer duration match
            if let dur = duration, let aDur = a.duration, let bDur = b.duration {
                return abs(aDur - dur) < abs(bDur - dur)
            }
            return false
        }

        return sortedResults.first
    }

    /// Fetch lyrics using the "get" endpoint (exact match).
    static func get(title: String, artist: String, album: String, duration: TimeInterval) async throws -> LRCLibResult? {
        let cleanTitle = normalizeQuery(title)
        let cleanArtist = normalizeQuery(artist)
        let cleanAlbum = normalizeQuery(album)

        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedArtist = cleanArtist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedAlbum = cleanAlbum.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }

        let urlString = "\(baseURL)/get?track_name=\(encodedTitle)&artist_name=\(encodedArtist)&album_name=\(encodedAlbum)&duration=\(Int(duration))"

        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("DynaNotch/2.0.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return nil
        }

        return try JSONDecoder().decode(LRCLibResult.self, from: data)
    }

    // MARK: - Helpers

    private static func normalizeQuery(_ string: String) -> String {
        string
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "\u{FFFD}", with: "")
    }
}

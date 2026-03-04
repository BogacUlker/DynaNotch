//
//  LyricsCache.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation
import os

/// Cached lyrics entry stored on disk.
struct CachedLyrics: Codable {
    let title: String
    let artist: String
    let syncedLines: [LyricLine]
    let plainText: String
    let source: String
    let cachedAt: Date

    var isExpired: Bool {
        Date().timeIntervalSince(cachedAt) > 30 * 24 * 3600 // 30 days
    }

    var parsedLyrics: ParsedLyrics {
        ParsedLyrics(syncedLines: syncedLines, plainText: plainText)
    }
}

/// File-based lyrics cache under Application Support.
enum LyricsCache {

    private static let logger = Logger(subsystem: "com.dynanotch", category: "LyricsCache")

    private static var cacheDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("DynaNotch/LyricsCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Public API

    /// Retrieve cached lyrics for a song. Returns nil if not cached or expired.
    static func get(title: String, artist: String) -> CachedLyrics? {
        let file = fileURL(for: title, artist: artist)
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }

        do {
            let data = try Data(contentsOf: file)
            let cached = try JSONDecoder().decode(CachedLyrics.self, from: data)

            if cached.isExpired {
                try? FileManager.default.removeItem(at: file)
                return nil
            }

            return cached
        } catch {
            logger.warning("Failed to read lyrics cache: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: file)
            return nil
        }
    }

    /// Store lyrics in cache.
    static func store(title: String, artist: String, lyrics: ParsedLyrics, source: String) {
        let entry = CachedLyrics(
            title: title,
            artist: artist,
            syncedLines: lyrics.syncedLines,
            plainText: lyrics.plainText,
            source: source,
            cachedAt: Date()
        )

        let file = fileURL(for: title, artist: artist)

        do {
            let data = try JSONEncoder().encode(entry)
            try data.write(to: file, options: .atomic)
        } catch {
            logger.warning("Failed to write lyrics cache: \(error.localizedDescription)")
        }
    }

    /// Remove all cached lyrics.
    static func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private

    private static func fileURL(for title: String, artist: String) -> URL {
        let key = "\(title.lowercased())_\(artist.lowercased())"
        let hash = key.data(using: .utf8).map { data in
            data.map { String(format: "%02x", $0) }.joined()
        } ?? "unknown"
        // Use first 32 chars of hex to avoid overly long filenames
        let filename = String(hash.prefix(32)) + ".json"
        return cacheDirectory.appendingPathComponent(filename)
    }
}

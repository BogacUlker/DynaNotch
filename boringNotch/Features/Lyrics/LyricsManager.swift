//
//  LyricsManager.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import AppKit
import Combine
import Defaults
import Foundation
import os

/// Lyrics display mode.
enum LyricsDisplayMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case compact = "Compact"
    case karaoke = "Karaoke"

    var id: String { rawValue }
}

/// Centralized lyrics manager that handles fetching, caching, and synced line tracking.
class LyricsManager: ObservableObject {

    static let shared = LyricsManager()

    private let logger = Logger(subsystem: "com.dynanotch", category: "Lyrics")

    // MARK: - Published State

    @Published var syncedLines: [LyricLine] = []
    @Published var plainText: String = ""
    @Published var isFetching: Bool = false
    @Published var currentLineIndex: Int? = nil

    /// The current single-line lyric text (for compact mode).
    @Published var currentLineText: String = ""

    // MARK: - Private

    private var fetchTask: Task<Void, Never>?
    private var currentTrackKey: String = ""

    // MARK: - Public API

    var hasSyncedLyrics: Bool { !syncedLines.isEmpty }
    var hasLyrics: Bool { !syncedLines.isEmpty || !plainText.isEmpty }

    /// Called when track changes. Fetches lyrics from cache or network.
    func onTrackChanged(title: String, artist: String, album: String, duration: TimeInterval, bundleIdentifier: String?) {
        guard Defaults[.enableLyrics] else {
            reset()
            return
        }

        let trackKey = "\(title)|\(artist)"
        guard trackKey != currentTrackKey else { return }
        currentTrackKey = trackKey

        // Cancel any in-flight fetch
        fetchTask?.cancel()

        fetchTask = Task { @MainActor in
            self.isFetching = true
            self.syncedLines = []
            self.plainText = ""
            self.currentLineIndex = nil
            self.currentLineText = ""

            // 1. Check cache
            if let cached = LyricsCache.get(title: title, artist: artist) {
                self.applyLyrics(cached.parsedLyrics)
                self.isFetching = false
                return
            }

            // 2. Try Apple Music native lyrics (AppleScript) if applicable
            if let bundleID = bundleIdentifier, bundleID.contains("com.apple.Music") {
                if let appleLyrics = await self.fetchAppleMusicLyrics() {
                    let parsed = ParsedLyrics(syncedLines: [], plainText: appleLyrics)
                    self.applyLyrics(parsed)
                    LyricsCache.store(title: title, artist: artist, lyrics: parsed, source: "AppleMusic")
                    self.isFetching = false
                    return
                }
            }

            // 3. Try LRCLIB
            do {
                // First try exact match with duration
                var result: LRCLibResult?
                if !album.isEmpty && duration > 0 {
                    result = try await LRCLibService.get(title: title, artist: artist, album: album, duration: duration)
                }

                // Fallback to search
                if result == nil {
                    result = try await LRCLibService.search(title: title, artist: artist, album: album.isEmpty ? nil : album, duration: duration > 0 ? duration : nil)
                }

                guard !Task.isCancelled else { return }

                if let result = result {
                    let synced = result.syncedLyrics.flatMap { str -> [LyricLine] in
                        let lines = LyricsParser.parseLRC(str)
                        return lines.isEmpty ? [] : lines
                    } ?? []
                    let plain = result.plainLyrics?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    let parsed = ParsedLyrics(syncedLines: synced, plainText: plain)
                    self.applyLyrics(parsed)
                    LyricsCache.store(title: title, artist: artist, lyrics: parsed, source: "LRCLIB")
                } else {
                    self.plainText = ""
                    self.syncedLines = []
                }
            } catch {
                guard !Task.isCancelled else { return }
                logger.warning("Lyrics fetch failed: \(error.localizedDescription)")
            }

            self.isFetching = false
        }
    }

    /// Update the current line index based on playback position.
    /// Should be called from a TimelineView at ~0.25s intervals.
    func updatePosition(_ elapsed: TimeInterval) {
        guard hasSyncedLyrics else {
            if !plainText.isEmpty {
                let flat = plainText.replacingOccurrences(of: "\n", with: " ")
                if currentLineText != flat {
                    currentLineText = flat
                }
            }
            return
        }

        let newIndex = LyricsParser.lineIndex(in: syncedLines, at: elapsed)

        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
            if let idx = newIndex {
                currentLineText = syncedLines[idx].text
            } else if let first = syncedLines.first {
                currentLineText = first.text
            }
        }
    }

    /// Reset all state (e.g., when lyrics are disabled or player becomes idle).
    func reset() {
        fetchTask?.cancel()
        currentTrackKey = ""
        syncedLines = []
        plainText = ""
        isFetching = false
        currentLineIndex = nil
        currentLineText = ""
    }

    // MARK: - Private

    @MainActor
    private func applyLyrics(_ lyrics: ParsedLyrics) {
        self.syncedLines = lyrics.syncedLines
        self.plainText = lyrics.plainText
        self.isFetching = false
        self.currentLineIndex = nil

        if lyrics.hasSyncedLyrics {
            self.currentLineText = lyrics.syncedLines.first?.text ?? ""
        } else {
            self.currentLineText = lyrics.plainText.replacingOccurrences(of: "\n", with: " ")
        }
    }

    @MainActor
    private func fetchAppleMusicLyrics() async -> String? {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        guard !runningApps.isEmpty else { return nil }

        let script = """
        tell application "Music"
            if it is running then
                if player state is playing or player state is paused then
                    try
                        set l to lyrics of current track
                        if l is missing value then
                            return ""
                        else
                            return l
                        end if
                    on error
                        return ""
                    end try
                else
                    return ""
                end if
            else
                return ""
            end if
        end tell
        """

        guard let result = try? await AppleScriptHelper.execute(script),
              let lyricsString = result.stringValue,
              !lyricsString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return lyricsString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

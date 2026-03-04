//
//  LyricsView.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import os
import SwiftUI

private let lyricsViewLogger = Logger(subsystem: "com.dynanotch", category: "LyricsView")

// MARK: - Compact Lyrics View (Single Line)

/// Compact lyrics view: displays current lyric line as a scrolling marquee.
/// Used in the closed/collapsed notch and in the expanded music controls area.
struct LyricsCompactView: View {
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var musicManager = MusicManager.shared

    let frameWidth: CGFloat

    var body: some View {
        let _ = lyricsViewLogger.info("[LYRICS-VIEW] LyricsCompactView RENDER — hasLyrics=\(lyricsManager.hasLyrics) isFetching=\(lyricsManager.isFetching) currentLine='\(lyricsManager.currentLineText.prefix(40))' isPlaying=\(musicManager.isPlaying)")
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = currentElapsed(at: timeline.date)
            let _ = lyricsManager.updatePosition(elapsed)

            let displayText: String = {
                if lyricsManager.isFetching { return "Loading lyrics\u{2026}" }
                if !lyricsManager.hasLyrics { return "No lyrics found" }
                return lyricsManager.currentLineText.isEmpty ? "No lyrics found" : lyricsManager.currentLineText
            }()

            let isPersian = displayText.unicodeScalars.contains { scalar in
                let v = scalar.value
                return v >= 0x0600 && v <= 0x06FF
            }

            MarqueeText(
                .constant(displayText),
                font: .subheadline,
                nsFont: .subheadline,
                textColor: lyricsManager.isFetching ? .gray.opacity(0.7) : .gray,
                frameWidth: frameWidth
            )
            .font(isPersian ? .custom("Vazirmatn-Regular", size: NSFont.preferredFont(forTextStyle: .subheadline).pointSize) : .subheadline)
            .lineLimit(1)
            .opacity(musicManager.isPlaying ? 1 : 0)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func currentElapsed(at date: Date) -> TimeInterval {
        guard musicManager.isPlaying else { return musicManager.elapsedTime }
        let delta = date.timeIntervalSince(musicManager.timestampDate)
        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
        return min(max(progressed, 0), musicManager.songDuration)
    }
}

// MARK: - Karaoke Lyrics View (Multi-Line)

/// Karaoke lyrics view: displays multiple lines with the active line highlighted.
/// Previous/next lines are shown with reduced opacity.
struct LyricsKaraokeView: View {
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var musicManager = MusicManager.shared

    /// Album art dominant color for text tinting.
    var accentColor: Color

    /// Number of context lines to show above and below the current line.
    private let contextLines = 2

    var body: some View {
        let _ = lyricsViewLogger.info("[LYRICS-VIEW] LyricsKaraokeView RENDER — hasSynced=\(lyricsManager.hasSyncedLyrics) lineCount=\(lyricsManager.syncedLines.count) currentIdx=\(lyricsManager.currentLineIndex.map { String($0) } ?? "nil") isPlaying=\(musicManager.isPlaying)")
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = currentElapsed(at: timeline.date)
            let _ = lyricsManager.updatePosition(elapsed)

            karaokeContent
        }
    }

    @ViewBuilder
    private var karaokeContent: some View {
        if lyricsManager.isFetching {
            Text("Loading lyrics\u{2026}")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
        } else if lyricsManager.hasSyncedLyrics {
            syncedKaraokeView
        } else if !lyricsManager.plainText.isEmpty {
            plainTextView
        } else {
            Text("No lyrics found")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.5))
        }
    }

    private var syncedKaraokeView: some View {
        let lines = lyricsManager.syncedLines
        let activeIdx = lyricsManager.currentLineIndex ?? 0

        return VStack(alignment: .center, spacing: 4) {
            ForEach(visibleRange(activeIndex: activeIdx, total: lines.count), id: \.self) { idx in
                let isActive = idx == activeIdx
                Text(lines[idx].text)
                    .font(.system(size: isActive ? Defaults[.lyricsFontSize] + 1 : Defaults[.lyricsFontSize] - 1, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? accentColor : .gray.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .scaleEffect(isActive ? 1.02 : 0.95)
                    .opacity(isActive ? 1.0 : lineOpacity(index: idx, activeIndex: activeIdx))
                    .animation(.easeInOut(duration: 0.3), value: activeIdx)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.3), value: activeIdx)
    }

    private var plainTextView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(lyricsManager.plainText)
                .font(.system(size: Defaults[.lyricsFontSize]))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: - Helpers

    private func visibleRange(activeIndex: Int, total: Int) -> Range<Int> {
        let start = max(0, activeIndex - contextLines)
        let end = min(total, activeIndex + contextLines + 1)
        return start..<end
    }

    private func lineOpacity(index: Int, activeIndex: Int) -> Double {
        let distance = abs(index - activeIndex)
        switch distance {
        case 0: return 1.0
        case 1: return 0.5
        default: return 0.3
        }
    }

    private func currentElapsed(at date: Date) -> TimeInterval {
        guard musicManager.isPlaying else { return musicManager.elapsedTime }
        let delta = date.timeIntervalSince(musicManager.timestampDate)
        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
        return min(max(progressed, 0), musicManager.songDuration)
    }
}

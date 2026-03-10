//
//  BelowNotchLyricsOverlay.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-10.
//  GPL v3 License
//

import SwiftUI

/// Inline lyrics strip rendered inside the collapsed notch, below the indicators.
/// No separate background — the notch's own AdaptiveNotchShape provides the black fill.
/// Uses a fixed width equal to closedNotchSize.width so it never inflates the parent VStack.
struct BelowNotchLyricsStrip: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var lyricsManager = LyricsManager.shared

    let notchWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = computeElapsed(at: timeline.date)
            let _ = lyricsManager.updatePosition(elapsed)
            let currentLine = lyricsManager.currentLineText.isEmpty ? "♪" : lyricsManager.currentLineText

            Text(currentLine)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: notchWidth, height: 24)
                .frame(maxWidth: .infinity)
                .animation(.easeInOut(duration: 0.35), value: currentLine)
        }
    }

    private func computeElapsed(at date: Date) -> TimeInterval {
        guard musicManager.isPlaying else { return musicManager.elapsedTime }
        let delta = date.timeIntervalSince(musicManager.timestampDate)
        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
        return min(max(progressed, 0), musicManager.songDuration)
    }
}

//
//  BelowNotchLyricsOverlay.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-10.
//  GPL v3 License
//

import SwiftUI

/// Below-notch lyrics overlay — renders as a seamless black extension hanging below
/// the notch shape. Uses the parent's full width so it matches the notch exactly.
/// Offset by lyricsHeight - 1 to create a 1px overlap, eliminating any visible seam.
struct BelowNotchLyricsOverlay: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var lyricsManager = LyricsManager.shared

    private let lyricsHeight: CGFloat = 24

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = computeElapsed(at: timeline.date)
            let _ = lyricsManager.updatePosition(elapsed)
            let currentLine = lyricsManager.currentLineText.isEmpty ? "♪" : lyricsManager.currentLineText

            Text(currentLine)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: lyricsHeight)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 12,
                        bottomTrailingRadius: 12,
                        topTrailingRadius: 0
                    )
                    .fill(.black)
                )
                .offset(y: lyricsHeight - 1)
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

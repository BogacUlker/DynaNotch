//
//  BelowNotchLyricsWindow.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-06.
//  GPL v3 License
//

import AppKit
import Combine
import Defaults
import os
import SwiftUI

// MARK: - BelowNotchLyricsPanel

/// Transparent, non-interactive NSPanel that floats just below the notch window.
final class BelowNotchLyricsPanel: NSPanel {

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isReleasedWhenClosed = false
        level = .mainMenu + 2

        collectionBehavior = [
            .stationary,
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

// MARK: - BelowNotchLyricsController

/// Singleton that owns the lyrics panel and reacts to playback / settings changes.
@MainActor
final class BelowNotchLyricsController {

    static let shared = BelowNotchLyricsController()

    private let logger = Logger(subsystem: "com.dynanotch", category: "BelowNotchLyrics")
    private var panel: BelowNotchLyricsPanel?
    private var cancellables = Set<AnyCancellable>()
    private var currentScreenUUID: String?

    private let lyricsWidth: CGFloat = 220
    private let lyricsHeight: CGFloat = 24

    private init() {
        setupObservers()
    }

    // MARK: - Public API

    /// Show the lyrics panel below the notch on the given screen, if conditions are met.
    func showIfNeeded(screenUUID: String?) {
        guard shouldShow else {
            hide()
            return
        }

        currentScreenUUID = screenUUID

        if panel == nil {
            createPanel()
        }

        updatePosition(screenUUID: screenUUID)
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel?.animator().alphaValue = 1
        }
    }

    /// Immediately hide the lyrics panel (no animation — used when notch opens).
    func hide() {
        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    /// Update panel position if it is currently visible.
    func updatePositionIfVisible() {
        guard let panel, panel.isVisible, panel.alphaValue > 0 else { return }
        updatePosition(screenUUID: currentScreenUUID)
    }

    // MARK: - Private

    private var shouldShow: Bool {
        Defaults[.enableLyrics]
            && Defaults[.lyricsDisplayMode] == .belowNotch
            && MusicManager.shared.isPlaying
            && LyricsManager.shared.hasLyrics
            && !LyricsManager.shared.isFetching
    }

    private func createPanel() {
        let rect = NSRect(x: 0, y: 0, width: lyricsWidth, height: lyricsHeight)
        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .utilityWindow]
        let p = BelowNotchLyricsPanel(contentRect: rect, styleMask: style, backing: .buffered, defer: false)

        p.contentView = NSHostingView(rootView: BelowNotchLyricsContent())
        panel = p
    }

    private func updatePosition(screenUUID: String?) {
        guard let panel else { return }

        let screen: NSScreen?
        if let uuid = screenUUID {
            screen = NSScreen.screen(withUUID: uuid)
        } else {
            screen = NSScreen.main
        }

        guard let screen else { return }

        let screenFrame = screen.frame
        let closedHeight = getClosedNotchSize(screenUUID: screenUUID).height
        let closedWidth = getClosedNotchSize(screenUUID: screenUUID).width

        // Size the panel to match the notch width
        let panelWidth = max(closedWidth, lyricsWidth)
        panel.setContentSize(NSSize(width: panelWidth, height: lyricsHeight))

        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - closedHeight - lyricsHeight - 2

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func setupObservers() {
        // React to playback changes
        MusicManager.shared.$isPlaying
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)

        LyricsManager.shared.$syncedLines
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)

        LyricsManager.shared.$plainText
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)

        LyricsManager.shared.$isFetching
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)

        // React to settings changes
        Defaults.publisher(.enableLyrics)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)

        Defaults.publisher(.lyricsDisplayMode)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reevaluateVisibility() }
            .store(in: &cancellables)
    }

    private func reevaluateVisibility() {
        if shouldShow {
            // Only show if panel is not already visible
            if panel == nil || panel?.alphaValue == 0 {
                showIfNeeded(screenUUID: currentScreenUUID)
            }
        } else {
            hide()
        }
    }
}

// MARK: - BelowNotchLyricsContent

/// SwiftUI content displayed inside the lyrics panel.
struct BelowNotchLyricsContent: View {
    @ObservedObject private var musicManager = MusicManager.shared
    @ObservedObject private var lyricsManager = LyricsManager.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.25)) { timeline in
            let elapsed = computeElapsed(at: timeline.date)
            let _ = lyricsManager.updatePosition(elapsed)

            let text = lyricsManager.currentLineText.isEmpty ? "♪" : lyricsManager.currentLineText
            let glowColor = Defaults[.playerColorTinting]
                ? Color(nsColor: musicManager.avgColor).opacity(0.5)
                : Color.white.opacity(0.3)

            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .shadow(color: glowColor, radius: 4)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.7))
                )
        }
    }

    private func computeElapsed(at date: Date) -> TimeInterval {
        guard musicManager.isPlaying else { return musicManager.elapsedTime }
        let delta = date.timeIntervalSince(musicManager.timestampDate)
        let progressed = musicManager.elapsedTime + (delta * musicManager.playbackRate)
        return min(max(progressed, 0), musicManager.songDuration)
    }
}

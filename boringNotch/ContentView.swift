//
//  ContentView.swift
//  boringNotchApp
//
//  Created by Harsh Vardhan Goswami  on 02/08/24
//  Modified by Richard Kunkli on 24/08/2024.
//

import AVFoundation
import Combine
import Defaults
import KeyboardShortcuts
import SwiftUI
import SwiftUIIntrospect

// MARK: - Collapsed Indicator Types

enum CollapsedIndicatorKind: Equatable {
    case music
    case pomodoro
    case systemMonitor
    case quickNotes
    case weather
    case sports
}

@MainActor
struct ContentView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject var webcamManager = WebcamManager.shared

    @ObservedObject var coordinator = BoringViewCoordinator.shared
    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var batteryModel = BatteryStatusViewModel.shared
    @ObservedObject var brightnessManager = BrightnessManager.shared
    @ObservedObject var volumeManager = VolumeManager.shared
    @ObservedObject var pomodoroManager = PomodoroManager.shared
    @ObservedObject var systemMonitorManager = SystemMonitorManager.shared
    @ObservedObject var quickNotesManager = QuickNotesManager.shared
    @ObservedObject var weatherManager = WeatherManager.shared
    @ObservedObject var sportsManager = SportsManager.shared
    @ObservedObject var lyricsManager = LyricsManager.shared
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovering: Bool = false
    @State private var anyDropDebounceTask: Task<Void, Never>?

    @State private var gestureProgress: CGFloat = .zero

    @State private var haptics: Bool = false
    @State private var carouselIndex: Int = 0

    @Namespace var albumArtNamespace

    @Default(.useMusicVisualizer) var useMusicVisualizer

    @Default(.showNotHumanFace) var showNotHumanFace

    // Shared animation for movement/resizing — reads user's style preference
    private var animationSpring: Animation { BoringAnimations.notchAnimation }

    private let extendedHoverPadding: CGFloat = 30
    private let zeroHeightHoverPadding: CGFloat = 10

    private var topCornerRadius: CGFloat {
       ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.top
                : cornerRadiusInsets.closed.top
    }

    private var currentNotchShape: NotchShape {
        NotchShape(
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    private var currentClipShape: AdaptiveNotchShape {
        AdaptiveNotchShape(
            isFloatingTab: vm.isFloatingTab,
            isExpanded: vm.notchState == .open,
            topCornerRadius: topCornerRadius,
            bottomCornerRadius: ((vm.notchState == .open) && Defaults[.cornerRadiusScaling])
                ? cornerRadiusInsets.opened.bottom
                : cornerRadiusInsets.closed.bottom
        )
    }

    /// All currently active collapsed indicators, max 3, ordered by priority.
    private var activeCollapsedIndicators: [CollapsedIndicatorKind] {
        guard vm.notchState == .closed && !vm.hideOnClosed else { return [] }

        var indicators: [CollapsedIndicatorKind] = []
        let canShowNonMusic = !coordinator.expandingView.show
        let canShowMusic = canShowNonMusic || coordinator.expandingView.type == .music

        if canShowMusic && (musicManager.isPlaying || !musicManager.isPlayerIdle)
            && coordinator.musicLiveActivityEnabled
        {
            indicators.append(.music)
        }
        if canShowNonMusic && pomodoroManager.timerState != .idle {
            indicators.append(.pomodoro)
        }
        if canShowNonMusic && systemMonitorManager.isActive {
            indicators.append(.systemMonitor)
        }
        if canShowNonMusic && quickNotesManager.isActive && !quickNotesManager.notes.isEmpty
            && Defaults[.quickNotesShowCollapsedPreview]
        {
            indicators.append(.quickNotes)
        }
        if canShowNonMusic && weatherManager.isActive && weatherManager.temperature != nil {
            indicators.append(.weather)
        }
        if canShowNonMusic && Defaults[.enableSports] && sportsManager.hasLiveEvent {
            indicators.append(.sports)
        }

        return Array(indicators.prefix(3))
    }

    private var computedChinWidth: CGFloat {
        var chinWidth: CGFloat = vm.closedNotchSize.width
        let singleExt = 2 * max(0, vm.collapsedIndicatorHeight - 12) + 20

        if coordinator.expandingView.type == .battery && coordinator.expandingView.show
            && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
        {
            chinWidth = 640
        } else if !activeCollapsedIndicators.isEmpty {
            chinWidth += singleExt
        } else if !coordinator.expandingView.show && vm.notchState == .closed
            && (!musicManager.isPlaying && musicManager.isPlayerIdle)
            && Defaults[.showNotHumanFace] && !vm.hideOnClosed
        {
            chinWidth += singleExt
        }

        return chinWidth
    }

    var body: some View {
        // Calculate scale based on gesture progress only
        let gestureScale: CGFloat = {
            guard gestureProgress != 0 else { return 1.0 }
            let scaleFactor = 1.0 + gestureProgress * 0.01
            return max(0.6, scaleFactor)
        }()
        
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                let mainLayout = NotchLayout()
                    .frame(alignment: .top)
                    .padding(
                        .horizontal,
                        vm.notchState == .open
                        ? Defaults[.cornerRadiusScaling]
                        ? (cornerRadiusInsets.opened.top) : (cornerRadiusInsets.opened.bottom)
                        : cornerRadiusInsets.closed.bottom
                    )
                    .padding([.horizontal, .bottom], vm.notchState == .open ? 12 : 0)
                    .background(.black)
                    .clipShape(currentClipShape)
                    .overlay {
                        if vm.isFloatingTab && vm.notchState == .closed {
                            currentClipShape
                                .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                        }
                    }
                    .overlay(alignment: .top) {
                        if !vm.isFloatingTab {
                            Rectangle()
                                .fill(.black)
                                .frame(height: 1)
                                .padding(.horizontal, topCornerRadius)
                        }
                    }
                    .shadow(
                        color: ((vm.notchState == .open || isHovering) && Defaults[.enableShadow])
                            ? .black.opacity(0.7) : .clear, radius: Defaults[.cornerRadiusScaling] ? 6 : 4
                    )
                    .padding(
                        .bottom,
                        vm.collapsedIndicatorHeight == 0 ? 10 : 0
                    )
                
                mainLayout
                    .frame(height: vm.notchState == .open ? vm.notchSize.height : nil)
                    .conditionalModifier(true) { view in
                        return view
                            .animation(vm.notchState == .open ? BoringAnimations.notchOpenAnimation : BoringAnimations.notchCloseAnimation, value: vm.notchState)
                            .animation(.smooth, value: gestureProgress)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        handleHover(hovering)
                    }
                    .onTapGesture {
                        doOpen()
                    }
                    .conditionalModifier(Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .down) { translation, phase in
                                handleDownGesture(translation: translation, phase: phase)
                            }
                    }
                    .conditionalModifier(Defaults[.closeGestureEnabled] && Defaults[.enableGestures]) { view in
                        view
                            .panGesture(direction: .up) { translation, phase in
                                handleUpGesture(translation: translation, phase: phase)
                            }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .sharingDidFinish)) { _ in
                        if vm.notchState == .open && !isHovering && !vm.isBatteryPopoverActive {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if self.vm.notchState == .open && !self.isHovering && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: vm.notchState) { _, newState in
                        if newState == .closed && isHovering {
                            withAnimation {
                                isHovering = false
                            }
                        }
                        updateWindowKeyFocus()
                    }
                    .onChange(of: coordinator.currentView) { _, _ in
                        updateWindowKeyFocus()
                    }
                    .onChange(of: vm.isBatteryPopoverActive) {
                        if !vm.isBatteryPopoverActive && !isHovering && vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                            hoverTask?.cancel()
                            hoverTask = Task {
                                try? await Task.sleep(for: .milliseconds(100))
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    if !self.vm.isBatteryPopoverActive && !self.isHovering && self.vm.notchState == .open && !SharingStateManager.shared.preventNotchClose {
                                        self.vm.close()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: coordinator.sneakPeek.show) { _, show in
                        if show && vm.isFloatingTab && vm.notchState == .closed {
                            // Auto-expand floating tab for HUD events (volume, brightness)
                            if coordinator.sneakPeek.type != .music {
                                doOpen()
                            }
                        }
                    }
                    .onChange(of: coordinator.expandingView.show) { _, show in
                        if show && vm.isFloatingTab && vm.notchState == .closed {
                            // Auto-expand floating tab for battery/expanding view events
                            doOpen()
                        }
                    }
                    .sensoryFeedback(.alignment, trigger: haptics)
                    .task {
                        // Carousel timer: rotate right-side indicators every 4 seconds
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .seconds(4))
                            guard !Task.isCancelled else { break }
                            withAnimation(.easeInOut(duration: 0.5)) {
                                carouselIndex += 1
                            }
                        }
                    }
                    .onChange(of: activeCollapsedIndicators) { _, _ in
                        carouselIndex = 0
                    }
                    .contextMenu {
                        Button("Settings") {
                            SettingsWindowController.shared.showWindow()
                        }
                        .keyboardShortcut(KeyEquivalent(","), modifiers: .command)
                        //                    Button("Edit") { // Doesnt work....
                        //                        let dn = DynamicNotch(content: EditPanelView())
                        //                        dn.toggle()
                        //                    }
                        //                    .keyboardShortcut("E", modifiers: .command)
                    }
                if vm.chinHeight > 0 {
                    Rectangle()
                        .fill(Color.black.opacity(0.01))
                        .frame(width: computedChinWidth, height: vm.chinHeight)
                }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: windowSize.width, maxHeight: windowSize.height, alignment: .top)
        .compositingGroup()
        .scaleEffect(
            x: gestureScale,
            y: gestureScale,
            anchor: .top
        )
        .animation(.smooth, value: gestureProgress)
        .background(dragDetector)
        .preferredColorScheme(.dark)
        .environmentObject(vm)
        .onChange(of: vm.anyDropZoneTargeting) { _, isTargeted in
            anyDropDebounceTask?.cancel()

            if isTargeted {
                if vm.notchState == .closed {
                    coordinator.currentView = .shelf
                    doOpen()
                }
                return
            }

            anyDropDebounceTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }

                if vm.dropEvent {
                    vm.dropEvent = false
                    return
                }

                vm.dropEvent = false
                if !SharingStateManager.shared.preventNotchClose {
                    vm.close()
                }
            }
        }
    }

    @ViewBuilder
    func NotchLayout() -> some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                if coordinator.helloAnimationRunning {
                    Spacer()
                    HelloAnimation(onFinish: {
                        vm.closeHello()
                    }).frame(
                        width: getClosedNotchSize().width,
                        height: 80
                    )
                    .padding(.top, 40)
                    Spacer()
                } else {
                    if coordinator.expandingView.type == .battery && coordinator.expandingView.show
                        && vm.notchState == .closed && Defaults[.showPowerStatusNotifications]
                    {
                        HStack(spacing: 0) {
                            HStack {
                                Text(batteryModel.statusText)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                            }

                            Rectangle()
                                .fill(.black)
                                .frame(width: vm.closedNotchSize.width + 10)

                            HStack {
                                BoringBatteryView(
                                    batteryWidth: 30,
                                    isCharging: batteryModel.isCharging,
                                    isInLowPowerMode: batteryModel.isInLowPowerMode,
                                    isPluggedIn: batteryModel.isPluggedIn,
                                    levelBattery: batteryModel.levelBattery,
                                    isForNotification: true
                                )
                            }
                            .frame(width: 76, alignment: .trailing)
                        }
                        .frame(height: vm.collapsedIndicatorHeight, alignment: .center)
                      } else if coordinator.sneakPeek.show && Defaults[.inlineHUD] && (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && vm.notchState == .closed {
                          InlineHUD(type: $coordinator.sneakPeek.type, value: $coordinator.sneakPeek.value, icon: $coordinator.sneakPeek.icon, hoverAnimation: $isHovering, gestureProgress: $gestureProgress)
                              .transition(.opacity)
                      } else {
                          let indicators = activeCollapsedIndicators
                          let musicActive = indicators.contains(.music)
                          let otherIndicators = indicators.filter { $0 != .music }

                          if musicActive && !otherIndicators.isEmpty {
                              // Music fixed left + carousel of others on right
                              MusicPlusCarouselView(rightIndicators: otherIndicators)
                          } else if musicActive {
                              // Music only
                              MusicLiveActivity().frame(alignment: .center)
                          } else if otherIndicators.count == 1 {
                              // Single non-music indicator: full live activity
                              singleIndicatorView(for: otherIndicators[0])
                          } else if otherIndicators.count > 1 {
                              // Multiple non-music: carousel through full views
                              carouselFullView(indicators: otherIndicators)
                          } else if !coordinator.expandingView.show && vm.notchState == .closed
                              && (!musicManager.isPlaying && musicManager.isPlayerIdle)
                              && Defaults[.showNotHumanFace] && !vm.hideOnClosed
                          {
                              BoringFaceAnimation()
                          } else if vm.notchState == .open {
                              BoringHeader()
                                  .frame(height: max(24, vm.collapsedIndicatorHeight))
                                  .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
                          } else {
                              Rectangle().fill(.clear).frame(width: vm.closedNotchSize.width - 20, height: vm.collapsedIndicatorHeight)
                          }

                      }

                      if coordinator.sneakPeek.show {
                          if (coordinator.sneakPeek.type != .music) && (coordinator.sneakPeek.type != .battery) && !Defaults[.inlineHUD] && vm.notchState == .closed {
                              SystemEventIndicatorModifier(
                                  eventType: $coordinator.sneakPeek.type,
                                  value: $coordinator.sneakPeek.value,
                                  icon: $coordinator.sneakPeek.icon,
                                  sendEventBack: { newVal in
                                      switch coordinator.sneakPeek.type {
                                      case .volume:
                                          VolumeManager.shared.setAbsolute(Float32(newVal))
                                      case .brightness:
                                          BrightnessManager.shared.setAbsolute(value: Float32(newVal))
                                      default:
                                          break
                                      }
                                  }
                              )
                              .padding(.bottom, 10)
                              .padding(.leading, 4)
                              .padding(.trailing, 8)
                          }
                          // Old sneak peek music
                          else if coordinator.sneakPeek.type == .music {
                              if vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard {
                                  HStack(alignment: .center) {
                                      Image(systemName: "music.note")
                                      GeometryReader { geo in
                                          MarqueeText(.constant(musicManager.songTitle + " - " + musicManager.artistName),  textColor: Defaults[.playerColorTinting] ? Color(nsColor: musicManager.avgColor).ensureMinimumBrightness(factor: 0.6) : .gray, minDuration: 1, frameWidth: geo.size.width)
                                      }
                                  }
                                  .foregroundStyle(.gray)
                                  .padding(.bottom, 10)
                              }
                          }
                      }
                  }
              }
              .conditionalModifier((coordinator.sneakPeek.show && (coordinator.sneakPeek.type == .music) && vm.notchState == .closed && !vm.hideOnClosed && Defaults[.sneakPeekStyles] == .standard) || (coordinator.sneakPeek.show && (coordinator.sneakPeek.type != .music) && (vm.notchState == .closed))) { view in
                  view
                      .fixedSize()
              }
              .zIndex(2)
            if vm.notchState == .open {
                VStack {
                    switch coordinator.currentView {
                    case .home:
                        NotchHomeView(albumArtNamespace: albumArtNamespace)
                    case .shelf:
                        ShelfView()
                    case .pomodoro:
                        PomodoroView()
                    case .systemMonitor:
                        SystemMonitorView()
                    case .quickNotes:
                        QuickNotesView()
                    case .sports:
                        SportsView()
                    }
                }
                .transition(
                    .scale(scale: 0.8, anchor: .top)
                    .combined(with: .opacity)
                    .animation(.smooth(duration: 0.35))
                )
                .zIndex(1)
                .allowsHitTesting(vm.notchState == .open)
                .opacity(gestureProgress != 0 ? 1.0 - min(abs(gestureProgress) * 0.1, 0.3) : 1.0)
            }
        }
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], delegate: GeneralDropTargetDelegate(isTargeted: $vm.generalDropTargeting))
    }

    @ViewBuilder
    func BoringFaceAnimation() -> some View {
        HStack {
            HStack {
                Rectangle()
                    .fill(.clear)
                    .frame(
                        width: max(0, vm.collapsedIndicatorHeight - 12),
                        height: max(0, vm.collapsedIndicatorHeight - 12)
                    )
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width - 20)
                MinimalFaceFeatures()
            }
        }.frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func MusicLiveActivity() -> some View {
        HStack {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipped()
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: MusicPlayerImageSizes.cornerRadiusInset.closed)
                )
                .matchedGeometryEffect(id: "albumArt", in: albumArtNamespace)
                .frame(
                    width: max(0, vm.collapsedIndicatorHeight - 12),
                    height: max(0, vm.collapsedIndicatorHeight - 12)
                )

            Rectangle()
                .fill(.black)
                .overlay(
                    HStack(alignment: .top) {
                        if coordinator.expandingView.show
                            && coordinator.expandingView.type == .music
                        {
                            MarqueeText(
                                .constant(musicManager.songTitle),
                                textColor: Defaults[.coloredSpectrogram]
                                    ? Color(nsColor: musicManager.avgColor) : Color.gray,
                                minDuration: 0.4,
                                frameWidth: 100
                            )
                            .opacity(
                                (coordinator.expandingView.show
                                    && Defaults[.sneakPeekStyles] == .inline)
                                    ? 1 : 0
                            )
                            Spacer(minLength: vm.closedNotchSize.width)
                            // Song Artist
                            Text(musicManager.artistName)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .foregroundStyle(
                                    Defaults[.coloredSpectrogram]
                                        ? Color(nsColor: musicManager.avgColor)
                                        : Color.gray
                                )
                                .opacity(
                                    (coordinator.expandingView.show
                                        && coordinator.expandingView.type == .music
                                        && Defaults[.sneakPeekStyles] == .inline)
                                        ? 1 : 0
                                )
                        }
                    }
                )
                .frame(
                    width: (coordinator.expandingView.show
                        && coordinator.expandingView.type == .music
                        && Defaults[.sneakPeekStyles] == .inline)
                        ? 380
                        : vm.closedNotchSize.width
                            + -cornerRadiusInsets.closed.top
                )

            HStack {
                if useMusicVisualizer {
                    Rectangle()
                        .fill(
                            Defaults[.coloredSpectrogram]
                                ? Color(nsColor: musicManager.avgColor).gradient
                                : Color.gray.gradient
                        )
                        .frame(width: 50, alignment: .center)
                        .matchedGeometryEffect(id: "spectrum", in: albumArtNamespace)
                        .mask {
                            AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                                .frame(width: 16, height: 12)
                        }
                } else {
                    LottieAnimationContainer()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(
                width: max(
                    0,
                    vm.collapsedIndicatorHeight - 12
                        + gestureProgress / 2
                ),
                height: max(
                    0,
                    vm.collapsedIndicatorHeight - 12
                ),
                alignment: .center
            )
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func PomodoroLiveActivity() -> some View {
        let phaseColor: Color = {
            switch pomodoroManager.phase {
            case .work: return .red
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }()
        let mins = Int(pomodoroManager.remainingSeconds) / 60
        let secs = Int(pomodoroManager.remainingSeconds) % 60
        let timeText = String(format: "%d:%02d", mins, secs)

        HStack {
            // Left: mini circular progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: pomodoroManager.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: pomodoroManager.progress)
            }
            .frame(
                width: max(0, vm.collapsedIndicatorHeight - 12),
                height: max(0, vm.collapsedIndicatorHeight - 12)
            )

            // Center: notch gap
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right: countdown text
            Text(timeText)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(pomodoroManager.timerState == .paused ? phaseColor.opacity(0.5) : phaseColor)
                .fixedSize()
                .padding(.trailing, 4)
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func SystemMonitorLiveActivity() -> some View {
        let cpuPercent = systemMonitorManager.cpuUsage
        let ramPercent = systemMonitorManager.ramUsagePercent
        let cpuColor: Color = cpuPercent < 50 ? .green : cpuPercent < 80 ? .orange : .red
        let ramColor: Color = ramPercent < 60 ? .cyan : ramPercent < 85 ? .orange : .red
        let ringSize = max(0, vm.collapsedIndicatorHeight - 12)

        HStack(spacing: 0) {
            // Left: CPU mini ring + percentage
            HStack(spacing: 3) {
                ZStack {
                    Circle()
                        .stroke(cpuColor.opacity(0.2), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: min(cpuPercent / 100.0, 1.0))
                        .stroke(cpuColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: cpuPercent)
                }
                .frame(width: ringSize, height: ringSize)

                Text("\(Int(cpuPercent))")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(cpuColor)
                    .fixedSize()
            }

            // Center: notch gap
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right: RAM mini ring + percentage
            HStack(spacing: 3) {
                Text("\(Int(ramPercent))")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(ramColor)
                    .fixedSize()

                ZStack {
                    Circle()
                        .stroke(ramColor.opacity(0.2), lineWidth: 1.5)
                    Circle()
                        .trim(from: 0, to: min(ramPercent / 100.0, 1.0))
                        .stroke(ramColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: ramPercent)
                }
                .frame(width: ringSize, height: ringSize)
            }
            .padding(.trailing, 2)
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func QuickNotesLiveActivity() -> some View {
        HStack {
            // Left: note icon
            Image(systemName: "note.text")
                .font(.system(size: max(0, vm.collapsedIndicatorHeight - 18)))
                .foregroundColor(.yellow)
                .frame(
                    width: max(0, vm.collapsedIndicatorHeight - 12),
                    height: max(0, vm.collapsedIndicatorHeight - 12)
                )

            // Center: notch gap
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right: preview text
            Text(quickNotesManager.mostRecentPreview)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 4)
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func WeatherLiveActivity() -> some View {
        HStack {
            // Left: weather emoji
            Text(weatherManager.weatherEmoji)
                .font(.system(size: max(0, vm.collapsedIndicatorHeight - 18)))
                .frame(
                    width: max(0, vm.collapsedIndicatorHeight - 12),
                    height: max(0, vm.collapsedIndicatorHeight - 12)
                )

            // Center: notch gap
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right: temperature
            Text(weatherManager.temperatureDisplay)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.cyan)
                .fixedSize()
                .padding(.trailing, 4)
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    @ViewBuilder
    func SportsLiveActivity() -> some View {
        HStack {
            // Left: live dot
            Circle()
                .fill(Color.red)
                .frame(
                    width: max(4, vm.collapsedIndicatorHeight - 22),
                    height: max(4, vm.collapsedIndicatorHeight - 22)
                )

            // Center: notch gap
            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width + 10)

            // Right: collapsed text
            if let text = sportsManager.currentCollapsedText {
                Text(text)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.trailing, 4)
            }
        }
        .frame(
            height: vm.collapsedIndicatorHeight,
            alignment: .center
        )
    }

    // MARK: - Carousel Collapsed Views

    @ViewBuilder
    func singleIndicatorView(for kind: CollapsedIndicatorKind) -> some View {
        switch kind {
        case .music: MusicLiveActivity().frame(alignment: .center)
        case .pomodoro: PomodoroLiveActivity().frame(alignment: .center)
        case .systemMonitor: SystemMonitorLiveActivity().frame(alignment: .center)
        case .quickNotes: QuickNotesLiveActivity().frame(alignment: .center)
        case .weather: WeatherLiveActivity().frame(alignment: .center)
        case .sports: SportsLiveActivity().frame(alignment: .center)
        }
    }

    @ViewBuilder
    func carouselFullView(indicators: [CollapsedIndicatorKind]) -> some View {
        let current = indicators[carouselIndex % indicators.count]
        ZStack {
            singleIndicatorView(for: current)
                .id(current)
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.5), value: carouselIndex)
    }

    @ViewBuilder
    func MusicPlusCarouselView(rightIndicators: [CollapsedIndicatorKind]) -> some View {
        let currentRight = rightIndicators[carouselIndex % rightIndicators.count]

        HStack(spacing: 0) {
            // Left: Music (album art + visualizer) — always visible
            CompactMusicChip()

            if vm.isFloatingTab {
                // Floating tab: thin divider instead of notch gap
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 1, height: vm.collapsedIndicatorHeight - 10)
                    .padding(.horizontal, 4)
            } else {
                // Physical notch: black notch gap
                Rectangle()
                    .fill(.black)
                    .frame(width: vm.closedNotchSize.width + 10)
            }

            // Right: Carousel of other indicators with fade transition
            ZStack {
                CarouselRightContent(indicator: currentRight)
                    .id(currentRight)
                    .transition(.opacity)
            }
            .animation(.easeInOut(duration: 0.5), value: carouselIndex)
        }
        .frame(height: vm.collapsedIndicatorHeight, alignment: .center)
    }

    @ViewBuilder
    func CarouselRightContent(indicator: CollapsedIndicatorKind) -> some View {
        switch indicator {
        case .pomodoro: CompactPomodoroChip()
        case .systemMonitor: CompactSystemMonitorChip()
        case .quickNotes: CompactQuickNotesChip()
        case .weather: CompactWeatherChip()
        case .sports: CompactSportsChip()
        case .music: EmptyView()
        }
    }

    @ViewBuilder
    func CompactMusicChip() -> some View {
        HStack(spacing: 3) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .frame(
                    width: max(0, vm.collapsedIndicatorHeight - 14),
                    height: max(0, vm.collapsedIndicatorHeight - 14)
                )
            if useMusicVisualizer {
                Rectangle()
                    .fill(
                        Defaults[.coloredSpectrogram]
                            ? Color(nsColor: musicManager.avgColor).gradient
                            : Color.gray.gradient
                    )
                    .frame(width: 12, height: 10)
                    .mask {
                        AudioSpectrumView(isPlaying: $musicManager.isPlaying)
                            .frame(width: 12, height: 10)
                    }
            }
        }
    }

    @ViewBuilder
    func CompactPomodoroChip() -> some View {
        let phaseColor: Color = {
            switch pomodoroManager.phase {
            case .work: return .red
            case .shortBreak: return .green
            case .longBreak: return .blue
            }
        }()
        let mins = Int(pomodoroManager.remainingSeconds) / 60
        let secs = Int(pomodoroManager.remainingSeconds) % 60

        HStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: pomodoroManager.progress)
                    .stroke(phaseColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(
                width: max(0, vm.collapsedIndicatorHeight - 16),
                height: max(0, vm.collapsedIndicatorHeight - 16)
            )

            Text(String(format: "%d:%02d", mins, secs))
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(pomodoroManager.timerState == .paused ? phaseColor.opacity(0.5) : phaseColor)
                .fixedSize()
        }
    }

    @ViewBuilder
    func CompactSystemMonitorChip() -> some View {
        let cpuColor: Color = systemMonitorManager.cpuUsage < 50 ? .green : systemMonitorManager.cpuUsage < 80 ? .orange : .red

        HStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(cpuColor.opacity(0.2), lineWidth: 1.5)
                Circle()
                    .trim(from: 0, to: min(systemMonitorManager.cpuUsage / 100.0, 1.0))
                    .stroke(cpuColor, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(
                width: max(0, vm.collapsedIndicatorHeight - 16),
                height: max(0, vm.collapsedIndicatorHeight - 16)
            )

            Text("\(Int(systemMonitorManager.cpuUsage))%")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(cpuColor)
                .fixedSize()
        }
    }

    @ViewBuilder
    func CompactQuickNotesChip() -> some View {
        Image(systemName: "note.text")
            .font(.system(size: max(8, vm.collapsedIndicatorHeight - 18)))
            .foregroundColor(.yellow)
    }

    @ViewBuilder
    func CompactWeatherChip() -> some View {
        HStack(spacing: 1) {
            Text(weatherManager.weatherEmoji)
                .font(.system(size: max(8, vm.collapsedIndicatorHeight - 20)))
            Text(weatherManager.temperatureDisplay)
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(.cyan)
                .fixedSize()
        }
    }

    @ViewBuilder
    func CompactSportsChip() -> some View {
        SportsCollapsedChip()
    }

    @ViewBuilder
    var dragDetector: some View {
        if Defaults[.boringShelf] && vm.notchState == .closed {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .url, .utf8PlainText, .plainText, .data], isTargeted: $vm.dragDetectorTargeting) { providers in
            vm.dropEvent = true
            ShelfStateViewModel.shared.load(providers)
            return true
        }
        } else {
            EmptyView()
        }
    }

    private func updateWindowKeyFocus() {
        let needs = vm.notchState == .open && (coordinator.currentView == .quickNotes || coordinator.currentView == .pomodoro)
        if let window = NSApp.windows.first(where: { $0 is BoringNotchSkyLightWindow }) as? BoringNotchSkyLightWindow {
            window.needsKeyFocus = needs
            if needs {
                window.makeKey()
            } else if window.isKeyWindow {
                window.resignKey()
            }
        }
    }

    private func doOpen() {
        withAnimation(animationSpring) {
            vm.open()
        }
    }

    // MARK: - Hover Management

    private func handleHover(_ hovering: Bool) {
        if coordinator.firstLaunch { return }
        hoverTask?.cancel()
        
        if hovering {
            withAnimation(animationSpring) {
                isHovering = true
            }
            
            if vm.notchState == .closed && Defaults[.enableHaptics] {
                haptics.toggle()
            }
            
            guard vm.notchState == .closed,
                  !coordinator.sneakPeek.show,
                  Defaults[.openNotchOnHover] else { return }
            
            hoverTask = Task {
                try? await Task.sleep(for: .seconds(Defaults[.minimumHoverDuration]))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    guard self.vm.notchState == .closed,
                          self.isHovering,
                          !self.coordinator.sneakPeek.show else { return }
                    
                    self.doOpen()
                }
            }
        } else {
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    withAnimation(animationSpring) {
                        self.isHovering = false
                    }
                    
                    if self.vm.notchState == .open && !self.vm.isBatteryPopoverActive && !SharingStateManager.shared.preventNotchClose {
                        self.vm.close()
                    }
                }
            }
        }
    }

    // MARK: - Gesture Handling

    private func handleDownGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .closed else { return }

        if phase == .ended {
            withAnimation(animationSpring) { gestureProgress = .zero }
            return
        }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * 20
        }

        if translation > Defaults[.gestureSensitivity] {
            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
            doOpen()
        }
    }

    private func handleUpGesture(translation: CGFloat, phase: NSEvent.Phase) {
        guard vm.notchState == .open && !vm.isHoveringCalendar else { return }

        withAnimation(animationSpring) {
            gestureProgress = (translation / Defaults[.gestureSensitivity]) * -20
        }

        if phase == .ended {
            withAnimation(animationSpring) {
                gestureProgress = .zero
            }
        }

        if translation > Defaults[.gestureSensitivity] {
            withAnimation(animationSpring) {
                isHovering = false
            }
            if !SharingStateManager.shared.preventNotchClose { 
                gestureProgress = .zero
                vm.close()
            }

            if Defaults[.enableHaptics] {
                haptics.toggle()
            }
        }
    }
}

struct FullScreenDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: () -> Void

    func dropEntered(info _: DropInfo) {
        isTargeted = true
    }

    func dropExited(info _: DropInfo) {
        isTargeted = false
    }

    func performDrop(info _: DropInfo) -> Bool {
        isTargeted = false
        onDrop()
        return true
    }

}

struct GeneralDropTargetDelegate: DropDelegate {
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        return false
    }
}

#Preview {
    let vm = BoringViewModel()
    vm.open()
    return ContentView()
        .environmentObject(vm)
        .frame(width: vm.notchSize.width, height: vm.notchSize.height)
}

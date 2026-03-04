//
//  drop.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on  04/08/24.
//

import Defaults
import Foundation
import SwiftUI


public class BoringAnimations {
    @Published var notchStyle: Style = .notch

    init() {
        self.notchStyle = .notch
    }

    var animation: Animation {
        if #available(macOS 14.0, *), notchStyle == .notch {
            Animation.spring(.bouncy(duration: 0.4))
        } else {
            Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.7)
        }
    }

    // MARK: - Configurable Animation Styles

    /// Interactive animation used for open/close, hover, and gesture actions.
    static var notchAnimation: Animation {
        switch Defaults[.notchAnimationStyle] {
        case .classic:
            return .easeInOut(duration: 0.35)
        case .spring:
            return .interactiveSpring(response: 0.38, dampingFraction: 0.8, blendDuration: 0)
        case .snappy:
            return .interactiveSpring(response: 0.25, dampingFraction: 0.9, blendDuration: 0)
        }
    }

    /// Frame-level open animation applied to the notch layout.
    static var notchOpenAnimation: Animation {
        switch Defaults[.notchAnimationStyle] {
        case .classic:
            return .easeInOut(duration: 0.35)
        case .spring:
            return .spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
        case .snappy:
            return .spring(response: 0.28, dampingFraction: 0.92, blendDuration: 0)
        }
    }

    /// Frame-level close animation applied to the notch layout.
    static var notchCloseAnimation: Animation {
        switch Defaults[.notchAnimationStyle] {
        case .classic:
            return .easeInOut(duration: 0.30)
        case .spring:
            return .spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
        case .snappy:
            return .spring(response: 0.22, dampingFraction: 1.0, blendDuration: 0)
        }
    }

    /// Tab-switching animation.
    static var tabSwitchAnimation: Animation {
        switch Defaults[.notchAnimationStyle] {
        case .classic:
            return .easeInOut(duration: 0.25)
        case .spring:
            return .smooth
        case .snappy:
            return .interactiveSpring(response: 0.2, dampingFraction: 0.9, blendDuration: 0)
        }
    }
}

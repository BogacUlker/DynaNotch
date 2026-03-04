//
//  NotchDisplayMode.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

/// Represents how the notch UI is rendered on a given screen.
enum NotchDisplayMode {
    /// MacBook built-in screen with a physical notch cutout.
    case physicalNotch
    /// External monitor or notch-less Mac — renders a thin floating pill.
    case floatingTab
}

/// User override for display mode detection.
enum DisplayModeOverride: String, CaseIterable, Identifiable, Defaults.Serializable {
    case automatic
    case forceNotch
    case forceFloatingTab

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .forceNotch: return "Always Notch"
        case .forceFloatingTab: return "Always Floating Tab"
        }
    }
}

/// Detects the appropriate display mode for a given screen.
enum DisplayModeDetector {
    /// Detect the display mode for a specific screen.
    static func detect(for screen: NSScreen) -> NotchDisplayMode {
        let override = Defaults[.displayModeOverride]

        switch override {
        case .forceNotch:
            return .physicalNotch
        case .forceFloatingTab:
            return .floatingTab
        case .automatic:
            if screen.auxiliaryTopLeftArea != nil {
                return .physicalNotch
            } else {
                return .floatingTab
            }
        }
    }

    /// Convenience wrapper that looks up a screen by UUID.
    @MainActor static func detect(forScreenUUID uuid: String?) -> NotchDisplayMode {
        guard let uuid = uuid,
              let screen = NSScreen.screen(withUUID: uuid) else {
            return .floatingTab
        }
        return detect(for: screen)
    }
}

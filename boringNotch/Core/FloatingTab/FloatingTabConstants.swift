//
//  FloatingTabConstants.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import SwiftUI

/// Constants for the floating tab (pill) appearance on non-notch screens.
enum FloatingTabConstants {
    /// Size of the collapsed floating tab pill.
    static let collapsedSize = CGSize(width: 220, height: 26)
    /// Corner radius when the floating tab is expanded.
    static let expandedCornerRadius: CGFloat = 16.0
    /// Corner radius when the floating tab is collapsed.
    static let collapsedCornerRadius: CGFloat = 13.0
}

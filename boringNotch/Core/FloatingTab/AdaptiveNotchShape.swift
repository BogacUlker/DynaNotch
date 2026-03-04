//
//  AdaptiveNotchShape.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import SwiftUI

/// A shape that adapts between the classic notch path and a rounded pill,
/// depending on whether the screen has a physical notch or uses a floating tab.
struct AdaptiveNotchShape: Shape {
    /// When true, renders a rounded rectangle (pill); when false, renders the notch shape.
    var isFloatingTab: Bool
    /// Whether the notch/pill is currently expanded.
    var isExpanded: Bool
    /// Top corner radius for the notch shape (physical notch mode).
    var topCornerRadius: CGFloat
    /// Bottom corner radius for the notch shape (physical notch mode).
    var bottomCornerRadius: CGFloat

    /// Blend factor: 0 = notch shape, 1 = pill shape. Animated for smooth transitions.
    private var blendFactor: CGFloat

    init(
        isFloatingTab: Bool,
        isExpanded: Bool,
        topCornerRadius: CGFloat = 6,
        bottomCornerRadius: CGFloat = 14
    ) {
        self.isFloatingTab = isFloatingTab
        self.isExpanded = isExpanded
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
        self.blendFactor = isFloatingTab ? 1.0 : 0.0
    }

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get {
            .init(.init(topCornerRadius, bottomCornerRadius), blendFactor)
        }
        set {
            topCornerRadius = newValue.first.first
            bottomCornerRadius = newValue.first.second
            blendFactor = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        if blendFactor >= 0.99 {
            // Pure pill / rounded rectangle
            return pillPath(in: rect)
        } else if blendFactor <= 0.01 {
            // Pure notch shape
            return notchPath(in: rect)
        } else {
            // Blend — for transition scenarios, just pick the closer shape
            return blendFactor > 0.5 ? pillPath(in: rect) : notchPath(in: rect)
        }
    }

    /// Pill-shaped path (for floating tab mode).
    private func pillPath(in rect: CGRect) -> Path {
        let cornerRadius = isExpanded
            ? FloatingTabConstants.expandedCornerRadius
            : FloatingTabConstants.collapsedCornerRadius
        return Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
    }

    /// Classic notch-shaped path — identical to the existing NotchShape logic.
    private func notchPath(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        path.addLine(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius)
        )

        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        path.addLine(
            to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY)
        )

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        path.addLine(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius)
        )

        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}

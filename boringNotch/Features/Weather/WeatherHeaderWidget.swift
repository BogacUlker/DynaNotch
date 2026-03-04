//
//  WeatherHeaderWidget.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Defaults
import SwiftUI

/// Compact weather display shown in the BoringHeader.
struct WeatherHeaderWidget: View {
    @ObservedObject var weatherManager = WeatherManager.shared

    var body: some View {
        HStack(spacing: 3) {
            Text(weatherManager.weatherEmoji)
                .font(.system(size: 9))

            Text(weatherManager.temperatureDisplay)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
    }
}

//
//  SportProvider.swift
//  boringNotch
//
//  Created by DynaNotch on 2026-03-04.
//  GPL v3 License
//

import Foundation

/// Common protocol for all sport data providers.
protocol SportProvider {
    var sportType: SportType { get }
    /// Fetch fresh data from the network. Called on a background actor.
    func refresh() async throws
    /// Currently live events (for collapsed indicator).
    func liveEvents() -> [SportEvent]
}

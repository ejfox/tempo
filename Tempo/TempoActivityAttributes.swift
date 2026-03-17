//
//  TempoActivityAttributes.swift
//  Tempo
//
//  Shared Live Activity attributes — must be identical in both
//  the app target and the widget extension.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

struct TempoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var currentStreak: Int
        var todayCount: Int
        var isInBreak: Bool
    }

    var sessionType: String
    var totalDuration: TimeInterval
}
#endif

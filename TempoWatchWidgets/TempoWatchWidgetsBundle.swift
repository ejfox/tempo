//
//  TempoWatchWidgetsBundle.swift
//  TempoWatchWidgets
//
//  Widget bundle exposing all 4 Tempo complications.
//

import SwiftUI
import WidgetKit

@main
struct TempoWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentWidget()
        DayWidget()
        StreakWidget()
        AutoWidget()
    }
}

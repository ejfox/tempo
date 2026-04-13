//
//  TempoWidgetsBundle.swift
//  TempoWidgets
//

import WidgetKit
import SwiftUI

@main
struct TempoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TempoStatusWidget()
        TempoWidgetsControl()
        TempoWidgetsLiveActivity()
    }
}

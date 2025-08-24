//
//  TempoWidgetsBundle.swift
//  TempoWidgets
//
//  Created by EJ Fox on 8/19/25.
//

import WidgetKit
import SwiftUI

@main
struct TempoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TempoWidgets()
        TempoWidgetsControl()
        TempoWidgetsLiveActivity()
    }
}

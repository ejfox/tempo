//
//  TempoWidgetsControl.swift
//  TempoWidgets
//
//  Control widget for starting/checking a Pomodoro session.
//

import AppIntents
import SwiftUI
import WidgetKit

struct TempoWidgetsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "com.fox.Tempo.TempoWidgets",
            provider: Provider()
        ) { value in
            ControlWidgetToggle(
                "Focus",
                isOn: value,
                action: ToggleFocusIntent()
            ) { isRunning in
                Label(isRunning ? "Focusing" : "Start", systemImage: isRunning ? "timer" : "play.fill")
            }
        }
        .displayName("Tempo")
        .description("Start or check your focus session.")
    }
}

extension TempoWidgetsControl {
    struct Provider: ControlValueProvider {
        var previewValue: Bool { false }

        func currentValue() async throws -> Bool {
            let defaults = UserDefaults(suiteName: "group.com.fox.Tempo")
            guard let data = defaults?.data(forKey: "widget.session"),
                  let info = try? JSONDecoder().decode(WidgetSessionInfo.self, from: data) else {
                return false
            }
            return info.isActive
        }
    }
}

struct ToggleFocusIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Toggle Focus Session"

    @Parameter(title: "Session active")
    var value: Bool

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Opens the app — SessionManager handles start/stop
        return .result()
    }
}

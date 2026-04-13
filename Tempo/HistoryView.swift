//
//  HistoryView.swift
//  Tempo
//
//  Session history: 28-day contribution grid, stats, today's sessions.
//

import SwiftUI
import CoreData

struct HistoryTab: View {
    @Environment(\.managedObjectContext) private var viewContext
    private let persistence = PersistenceController.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Stats header
                    statsSection

                    // Contribution grid
                    contributionGrid

                    // Today's sessions
                    todaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color.black)
            .navigationTitle("history")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        let stats = persistence.getOrCreateUserStats()
        return HStack(spacing: 24) {
            StatBox(value: "\(stats.currentStreak)", label: "streak", icon: "flame")
            StatBox(value: "\(stats.longestStreak)", label: "best", icon: "trophy")
            StatBox(value: "\(stats.totalSessions)", label: "total", icon: "checkmark.circle")
            StatBox(value: "\(stats.todayCount)", label: "today", icon: "sun.min")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Contribution Grid

    private var contributionGrid: some View {
        let days = persistence.dailySessionCounts(days: 28)

        return VStack(alignment: .leading, spacing: 8) {
            Text("last 28 days")
                .font(.system(size: 12, weight: .light, design: .monospaced))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(days, id: \.date) { day in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(opacityForCount(day.count)))
                        .frame(height: 24)
                        .accessibilityLabel("\(day.count) sessions on \(day.date.formatted(.dateTime.month().day()))")
                }
            }
        }
    }

    private func opacityForCount(_ count: Int) -> Double {
        switch count {
        case 0:     return 0.04
        case 1:     return 0.15
        case 2:     return 0.3
        case 3:     return 0.5
        default:    return 0.7
        }
    }

    // MARK: - Today's Sessions

    private var todaySection: some View {
        let sessions = todaySessions()

        return VStack(alignment: .leading, spacing: 8) {
            Text("today")
                .font(.system(size: 12, weight: .light, design: .monospaced))
                .foregroundStyle(.secondary)

            if sessions.isEmpty {
                Text("no sessions yet")
                    .font(.system(size: 14, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.vertical, 20)
            } else {
                ForEach(sessions, id: \.id) { session in
                    HStack {
                        Image(systemName: session.isCompleted ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundStyle(session.isCompleted ? .white.opacity(0.6) : .red.opacity(0.5))
                            .font(.system(size: 14))

                        Text(session.sessionType ?? "short")
                            .font(.system(size: 13, weight: .light, design: .monospaced))

                        Spacer()

                        if let start = session.startTime {
                            Text(start.formatted(.dateTime.hour().minute()))
                                .font(.system(size: 13, weight: .ultraLight, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Text("\(Int(session.workDuration / 60))m")
                            .font(.system(size: 13, weight: .light, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func todaySessions() -> [TempoSession] {
        let request: NSFetchRequest<TempoSession> = TempoSession.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "startTime >= %@", startOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        return (try? viewContext.fetch(request)) ?? []
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 20, weight: .light, design: .monospaced))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

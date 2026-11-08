import Charts
import SwiftUI

/// A shooting percentage as a ring (prototype player page: FG, 2PT, 3PT, FT).
struct StatRing: View {
    let title: LocalizedStringKey
    /// 0…100, or nil when nothing was attempted.
    let percentage: Double?
    let detail: String
    var color: RGB = .violet

    /// Grows with the percentage inside it.
    @ScaledMetric(relativeTo: .footnote) private var ringSize: CGFloat = 62

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(Theme.surface3, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: (percentage ?? 0) / 100)
                    .stroke(color.lifted().color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(verbatim: Format.percentage(percentage))
                    .font(.footnote.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(width: ringSize, height: ringSize)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
            Text(verbatim: detail)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text(verbatim: "\(Format.percentage(percentage)), \(detail)"))
    }
}

/// Points (or any value) per game, with an optional average line; the last game is emphasised.
struct Sparkline: View {
    let values: [Double]
    var labels: [String] = []
    var average: Double?
    var color: RGB = .violet

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var height: CGFloat = 120

    var body: some View {
        let line = color.lifted().color
        let large = dynamicTypeSize.isAccessibilitySize
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                AreaMark(x: .value("Game", index), y: .value("Value", value))
                    .foregroundStyle(line.opacity(0.16))
                LineMark(x: .value("Game", index), y: .value("Value", value))
                    .foregroundStyle(line)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Game", index), y: .value("Value", value))
                    .foregroundStyle(index == values.count - 1 ? Theme.textPrimary : line)
                    .symbolSize(index == values.count - 1 ? 60 : 24)
            }
            if let average {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(Theme.lime.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text(verbatim: "avg \(Format.average(average))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Theme.lime)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(preset: .aligned, values: Array(values.indices)) { mark in
                AxisValueLabel(collisionResolution: .disabled) {
                    // At accessibility sizes the opponents' codes would overlap; VoiceOver reads the values instead.
                    if !large, let index = mark.as(Int.self), labels.indices.contains(index) {
                        Text(verbatim: labels[index]).font(.caption2).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: large ? 2 : 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.surface3)
                AxisValueLabel().foregroundStyle(Theme.textTertiary)
            }
        }
        // Room at both ends so the first and last points and their labels aren't clipped.
        .chartXScale(range: .plotDimension(padding: 20))
        .frame(height: min(height, 240))
        .accessibilityElement()
        .accessibilityLabel("Points per game")
        .accessibilityValue(Text(verbatim: values.map { Format.count($0) }.joined(separator: ", ")))
    }
}

/// A team's box score: a pinned player column and horizontally scrolling stats (prototype `.bx`).
struct BoxScoreTable: View {
    let box: TeamBoxScore
    var onSelect: ((PlayerBoxLine) -> Void)?

    struct Column: Identifiable, Sendable {
        let id: String
        let title: String
        let width: CGFloat
        let highlighted: Bool
        let value: @Sendable (StatLine) -> String
    }

    nonisolated static func columns(showPlusMinus: Bool) -> [Column] {
        var columns: [Column] = [
            Column(id: "min", title: "MIN", width: 38, highlighted: false) { Format.count($0.minutes) },
            Column(id: "pts", title: "PTS", width: 38, highlighted: true) { Format.count($0.points) },
            Column(id: "reb", title: "REB", width: 38, highlighted: false) { Format.count($0.rebounds) },
            Column(id: "ast", title: "AST", width: 38, highlighted: false) { Format.count($0.assists) },
            Column(id: "stl", title: "STL", width: 36, highlighted: false) { Format.count($0.steals) },
            Column(id: "blk", title: "BLK", width: 36, highlighted: false) { Format.count($0.blocks) },
            Column(id: "fg", title: "FG", width: 50, highlighted: false) { Format.madeAttempted($0.fieldGoalsMade, $0.fieldGoalsAttempted) },
            Column(id: "3p", title: "3P", width: 46, highlighted: false) { Format.madeAttempted($0.threePointersMade, $0.threePointersAttempted) },
            Column(id: "ft", title: "FT", width: 46, highlighted: false) { Format.madeAttempted($0.freeThrowsMade, $0.freeThrowsAttempted) },
            Column(id: "oreb", title: "OR", width: 32, highlighted: false) { Format.count($0.offensiveRebounds) },
            Column(id: "tov", title: "TO", width: 32, highlighted: false) { Format.count($0.turnovers) },
            Column(id: "pf", title: "PF", width: 32, highlighted: false) { Format.count($0.fouls) }
        ]
        if showPlusMinus {
            columns.append(Column(id: "pm", title: "+/-", width: 40, highlighted: false) { Format.plusMinus($0.plusMinus ?? 0) })
        }
        columns.append(Column(id: "val", title: "VAL", width: 38, highlighted: true) { Format.count($0.efficiency) })
        return columns
    }

    /// Starters first, then by minutes played.
    nonisolated static func orderedLines(_ box: TeamBoxScore) -> [PlayerBoxLine] {
        box.players.sorted { ($0.isStarter ? 1 : 0, $0.stats.minutes) > ($1.isStarter ? 1 : 0, $1.stats.minutes) }
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Column widths and row heights grow with the text, so numbers never wrap; the stats scroll sideways (§4).
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1
    private var rowHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 40 * scale * 1.6 : 40 * scale }
    /// The pinned column stops growing so the stats keep some room; names wrap instead.
    private var nameWidth: CGFloat { min(132 * scale, 230) }

    var body: some View {
        let lines = Self.orderedLines(box)
        let columns = Self.columns(showPlusMinus: box.players.contains { ($0.stats.plusMinus ?? 0) != 0 })
        HStack(spacing: 0) {
            // Pinned player column
            VStack(alignment: .leading, spacing: 0) {
                header("PLAYER", width: nameWidth, alignment: .leading)
                ForEach(lines) { line in
                    Button { onSelect?(line) } label: {
                        HStack(spacing: 6) {
                            // At accessibility sizes the number would take a third of the pinned column.
                            if !dynamicTypeSize.isAccessibilitySize {
                                Text(verbatim: line.jersey ?? "")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.textTertiary)
                                    .frame(width: 20, alignment: .trailing)
                            }
                            Text(verbatim: line.player.shortName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)
                            if line.isStarter {
                                Circle().fill(Theme.violetHigh).frame(width: 5, height: 5).accessibilityLabel("Starter")
                            }
                        }
                        .frame(width: nameWidth, height: rowHeight, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelect == nil)
                }
                Text("Team")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: nameWidth, height: rowHeight, alignment: .leading)
                    .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : 26)
            }
            .padding(.leading, 12)
            .background(Theme.surface)
            .zIndex(1)
            .shadow(color: .black.opacity(0.5), radius: 4, x: 4)

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) { ForEach(columns) { header($0.title, width: $0.width * scale, alignment: .trailing) } }
                    ForEach(lines) { line in
                        HStack(spacing: 0) {
                            ForEach(columns) { column in cell(column.value(line.stats), column: column, bold: false) }
                        }
                        .frame(height: rowHeight)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: line.player.fullName))
                        .accessibilityValue(Text(verbatim: columns.map { "\($0.title) \($0.value(line.stats))" }.joined(separator: ", ")))
                    }
                    HStack(spacing: 0) {
                        ForEach(columns) { column in cell(column.id == "min" ? "" : column.value(box.totals), column: column, bold: true) }
                    }
                    .frame(height: rowHeight)
                }
                .padding(.trailing, 12)
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func header(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(verbatim: title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            .frame(width: width, height: 32 * scale, alignment: alignment)
    }

    private func cell(_ text: String, column: Column, bold: Bool) -> some View {
        Text(verbatim: text)
            .font(.subheadline.weight(bold || column.highlighted ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(bold || column.highlighted ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: column.width * scale, alignment: .trailing)
    }
}

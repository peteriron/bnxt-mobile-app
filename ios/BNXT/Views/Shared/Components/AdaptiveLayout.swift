import SwiftUI

/// Side by side at regular text sizes, stacked at accessibility sizes (REQUIREMENTS §4, playbook 02 "Accessibility").
struct AdaptiveStack<Content: View>: View {
    var horizontalAlignment: HorizontalAlignment = .leading
    var verticalAlignment: VerticalAlignment = .top
    var spacing: CGFloat?
    @ViewBuilder var content: Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: horizontalAlignment, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: verticalAlignment, spacing: spacing))
        layout { content }
    }
}

/// Equal tiles, `perRow` to a row (fewer at accessibility sizes); a short last row keeps the tile width.
struct TileRows<Tile: View>: View {
    let count: Int
    let perRow: Int
    var spacing: CGFloat = 8
    @ViewBuilder let tile: (Int) -> Tile

    var body: some View {
        Grid(horizontalSpacing: spacing, verticalSpacing: spacing) {
            ForEach(Array(stride(from: 0, to: count, by: max(perRow, 1))), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + perRow, count), id: \.self) { tile($0) }
                    if start + perRow > count {
                        ForEach(0..<(start + perRow - count), id: \.self) { _ in Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                    }
                }
            }
        }
    }
}

extension View {
    /// One line at regular text sizes, wrapping at accessibility sizes instead of truncating.
    func oneLineUnlessAccessibilitySize() -> some View {
        modifier(OneLineUnlessAccessibilitySize())
    }
}

private struct OneLineUnlessAccessibilitySize: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
    }
}

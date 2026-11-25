import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 8 · 炎 · Draw the streak flame                   (Path, Shape)
//
// Every icon in the app is a few strokes on a 24×24 grid (App/Glyphs.swift).
// One is missing: the flame beside your streak on Today. Right now it is a
// plain diamond. Draw a flame.
//
// Rules
//   • Strokes only, no fills — the icon is stroked by GlyphIcon, not by you.
//   • Stay inside the grid: x and y from about 3 to 21.
//   • `g(x, y)` gives you a point on the grid. Top-left is g(0, 0).
//
// Steps
//   1. Read three finished glyphs in Glyphs.swift: `.mountain` (straight lines),
//      `.heart` (addCurve) and `.moon` (addArc).
//   2. Sketch your flame on squared paper first, 24 squares each way. Mark the
//      tip, the widest points and the base.
//   3. Outer flame: start at the base, curve up one side to the tip, curve down
//      the other. `addQuadCurve` has one control point, `addCurve` has two.
//   4. Inner flame: a smaller teardrop inside it.
//
// You will practise: Path, move/addLine/addQuadCurve/addCurve, thinking in
// coordinates, and using a #Preview to iterate.
//
// How to check: open the canvas (⌥⌘↩) on this file. The preview shows your
// flame at three sizes. It should still read as a flame at 14 pt.
// ─────────────────────────────────────────────────────────────────────────────

enum FlameGlyph {
    static func path(on g: DrawingGrid) -> Path {
        var p = Path()
        // TODO(you): replace this diamond with a flame.
        p.polyline(g(12, 4), g(18, 12), g(12, 20), g(6, 12), g(12, 4))
        return p
    }
}

#Preview {
    HStack(spacing: 30) {
        GlyphIcon(.flame, size: 14, tint: Ink.shu)
        GlyphIcon(.flame, size: 28, tint: Ink.shu)
        GlyphIcon(.flame, size: 120, tint: Ink.shu)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Ink.sumi)
}

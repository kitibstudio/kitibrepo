import SwiftUI

/// Makes a macOS sheet resizable, and remembers the size it was left at.
///
/// Spec `table-grid-editor.md` criterion 4 asks for "a resizable sheet window"
/// on macOS. A SwiftUI sheet takes its size from its content and gives the user
/// no edge to drag, so a sheet whose content declared `minWidth: 480` opened at
/// 480 points and stayed there however long the table was — the columns were
/// cramped because the window could not be widened, not because the grid was
/// laid out badly.
///
/// This adds the missing affordance: an explicit grabber in the bottom-trailing
/// corner that drives the content's own frame, which the sheet window then
/// follows. The size is stored in `UserDefaults` under `storageKey`, so a writer
/// who works with wide tables sets the size once.
///
/// macOS only, deliberately. iOS sheets are sized by detents, and `TableGridEditor`
/// itself stays free of platform conditionals (criterion 4).
struct ResizableSheet: ViewModifier {
    let storageKey: String
    let minWidth: CGFloat
    let minHeight: CGFloat
    let defaultWidth: CGFloat
    let defaultHeight: CGFloat

    @State private var width: CGFloat = 0
    @State private var height: CGFloat = 0
    /// Size at the moment the drag began; the gesture reports a cumulative
    /// translation, so without this the window grows by the whole translation
    /// on every event and runs away from the pointer.
    @State private var dragOrigin: CGSize?

    func body(content: Content) -> some View {
        content
            .frame(width: width == 0 ? defaultWidth : width,
                   height: height == 0 ? defaultHeight : height)
            .overlay(alignment: .bottomTrailing) { grabber }
            .onAppear {
                let defaults = UserDefaults.standard
                let storedWidth = defaults.double(forKey: storageKey + ".width")
                let storedHeight = defaults.double(forKey: storageKey + ".height")
                width = storedWidth > 0 ? max(CGFloat(storedWidth), minWidth) : defaultWidth
                height = storedHeight > 0 ? max(CGFloat(storedHeight), minHeight) : defaultHeight
            }
    }

    private var grabber: some View {
        ResizeGrip()
            .frame(width: 16, height: 16)
            .padding(4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let origin = dragOrigin ?? CGSize(width: width, height: height)
                        if dragOrigin == nil { dragOrigin = origin }
                        width = max(minWidth, origin.width + value.translation.width)
                        height = max(minHeight, origin.height + value.translation.height)
                    }
                    .onEnded { _ in
                        dragOrigin = nil
                        UserDefaults.standard.set(Double(width), forKey: storageKey + ".width")
                        UserDefaults.standard.set(Double(height), forKey: storageKey + ".height")
                    }
            )
            .help("Drag to resize")
    }
}

/// The three diagonal strokes macOS uses for a resize corner.
private struct ResizeGrip: View {
    var body: some View {
        Canvas { context, size in
            let stroke = GraphicsContext.Shading.color(.primary.opacity(0.35))
            for inset in stride(from: CGFloat(3), through: 11, by: 4) {
                var path = Path()
                path.move(to: CGPoint(x: size.width - inset, y: size.height))
                path.addLine(to: CGPoint(x: size.width, y: size.height - inset))
                context.stroke(path, with: stroke, lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// See `ResizableSheet`.
    func resizableSheet(
        storageKey: String,
        minWidth: CGFloat,
        minHeight: CGFloat,
        defaultWidth: CGFloat,
        defaultHeight: CGFloat
    ) -> some View {
        modifier(ResizableSheet(
            storageKey: storageKey,
            minWidth: minWidth,
            minHeight: minHeight,
            defaultWidth: defaultWidth,
            defaultHeight: defaultHeight
        ))
    }
}

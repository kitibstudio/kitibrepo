import AppKit
import QuartzCore

/// Word-goal celebration.
///
/// The editor is an AppKit `NSTextView`, and AppKit content paints over sibling
/// SwiftUI layers — so a SwiftUI burst gets hidden behind the text. Instead this
/// renders in a separate, transparent, click-through panel floating *above* the
/// main window (a higher window always composites over the one below), using
/// `CAEmitterLayer` for proper particle effects.
///
/// Each shell launches a glowing rocket from the goal target that rises, trails
/// sparks, and bursts into a soft radial spray with comet tails and gravity —
/// rather than a flat ring of solid dots.
final class FireworksController {
    static let shared = FireworksController()

    private var panel: NSPanel?
    private weak var host: NSWindow?

    /// Launch a short firework display from the bottom-right of the frontmost
    /// document window (over the word-goal target in the status bar).
    func celebrate() {
        guard let main = documentWindow() else { return }
        let p = panel(for: main)
        p.setFrame(main.frame, display: false)
        p.contentView?.frame = NSRect(origin: .zero, size: main.frame.size)
        if p.parent == nil { main.addChildWindow(p, ordered: .above) }
        p.orderFront(nil)
        guard let view = p.contentView else { return }

        let size = view.bounds.size
        let launchPad = CGPoint(x: size.width - 58, y: 22)   // the target icon

        // A few staggered shells bursting at varied heights for a finale feel.
        let shells: [(apex: CGPoint, color: NSColor, delay: Double)] = [
            (CGPoint(x: size.width - 95,  y: size.height * 0.56), .systemPink,   0.00),
            (CGPoint(x: size.width - 185, y: size.height * 0.68), .systemTeal,   0.24),
            (CGPoint(x: size.width - 46,  y: size.height * 0.74), .systemYellow, 0.46),
        ]
        for shell in shells {
            DispatchQueue.main.asyncAfter(deadline: .now() + shell.delay) { [weak self] in
                self?.launch(in: view, from: launchPad, to: shell.apex, color: shell.color)
            }
        }
    }

    // MARK: - Panel

    private func documentWindow() -> NSWindow? {
        if let main = NSApp.mainWindow, !(main is NSPanel) { return main }
        return NSApp.windows.first { $0.isVisible && $0 !== panel && !($0 is NSPanel) }
    }

    private func panel(for window: NSWindow) -> NSPanel {
        if let panel, host === window { return panel }
        let p = NSPanel(contentRect: window.frame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.level = .floating
        p.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]

        let v = NSView(frame: NSRect(origin: .zero, size: window.frame.size))
        v.wantsLayer = true
        p.contentView = v

        panel = p
        host = window
        return p
    }

    // MARK: - Rocket → burst

    /// A glowing rocket that rises from `from` to `apex` leaving a trail, then
    /// explodes. The trail works by animating the emitter's position while it
    /// emits: each spark is left behind in world space as the source moves.
    private func launch(in view: NSView, from: CGPoint, to apex: CGPoint, color: NSColor) {
        guard let host = view.layer else { return }
        let rise = 0.55

        let rocket = CAEmitterLayer()
        rocket.emitterPosition = from
        rocket.emitterSize = CGSize(width: 2, height: 2)
        rocket.emitterShape = .point
        rocket.emitterMode = .outline
        // Normal compositing (not additive): additive sums to white over a
        // light editor background, washing out the colour. The glow comes from
        // the radial-gradient spark image instead.
        rocket.renderMode = .unordered

        let trail = CAEmitterCell()
        trail.birthRate = 230
        trail.lifetime = 0.35
        trail.lifetimeRange = 0.1
        trail.velocity = 16
        trail.velocityRange = 12
        trail.emissionRange = .pi * 2
        trail.scale = 0.14
        trail.scaleSpeed = -0.22
        trail.alphaSpeed = -2.6
        trail.contents = spark(.systemOrange)

        let head = CAEmitterCell()
        head.birthRate = 120
        head.lifetime = 0.06
        head.velocity = 0
        head.scale = 0.32
        head.contents = spark(.white)

        rocket.emitterCells = [trail, head]
        host.addSublayer(rocket)

        let move = CABasicAnimation(keyPath: "emitterPosition")
        move.fromValue = NSValue(point: from)
        move.toValue = NSValue(point: apex)
        move.duration = rise
        move.timingFunction = CAMediaTimingFunction(name: .easeOut)
        rocket.emitterPosition = apex
        rocket.add(move, forKey: "rise")

        DispatchQueue.main.asyncAfter(deadline: .now() + rise) { [weak self] in
            rocket.removeFromSuperlayer()
            self?.explode(in: view, at: apex, color: color)
        }
    }

    /// The burst: a bright flash plus a soft radial spray of glowing sparks,
    /// each leaving a short comet tail, drifting down under gravity.
    private func explode(in view: NSView, at point: CGPoint, color: NSColor) {
        guard let host = view.layer else { return }

        // Flash core.
        let flash = CALayer()
        flash.contents = spark(.white)
        flash.frame = CGRect(x: point.x - 22, y: point.y - 22, width: 44, height: 44)
        host.addSublayer(flash)
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.3; grow.toValue = 2.4
        let dim = CABasicAnimation(keyPath: "opacity")
        dim.fromValue = 0.95; dim.toValue = 0.0
        let group = CAAnimationGroup()
        group.animations = [grow, dim]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        flash.add(group, forKey: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { flash.removeFromSuperlayer() }

        // Spark spray.
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterSize = CGSize(width: 4, height: 4)
        emitter.emitterShape = .point
        emitter.emitterMode = .outline
        emitter.renderMode = .unordered

        let comet = CAEmitterCell()
        comet.birthRate = 16
        comet.lifetime = 0.5
        comet.velocity = 0
        comet.scale = 0.12
        comet.scaleSpeed = -0.22
        comet.alphaSpeed = -2.0
        comet.contents = spark(color)

        let sparkCell = CAEmitterCell()
        sparkCell.birthRate = 700
        sparkCell.lifetime = 1.6
        sparkCell.lifetimeRange = 0.4
        sparkCell.velocity = 150
        sparkCell.velocityRange = 28      // narrow spread → a clean shell
        sparkCell.emissionRange = .pi * 2
        sparkCell.yAcceleration = -120     // droop downward over time
        sparkCell.scale = 0.42
        sparkCell.scaleRange = 0.1
        sparkCell.scaleSpeed = -0.18
        sparkCell.alphaSpeed = -0.55
        sparkCell.spin = 1.5
        sparkCell.spinRange = 2.5
        sparkCell.contents = spark(color)
        sparkCell.emitterCells = [comet]

        emitter.emitterCells = [sparkCell]
        host.addSublayer(emitter)

        emitter.birthRate = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { emitter.removeFromSuperlayer() }
    }

    // MARK: - Particle image

    /// A glowing spark: bright white core easing out to `color` and then to
    /// transparent. Reads as a luminous particle on light or dark backgrounds.
    private func spark(_ color: NSColor) -> CGImage? {
        let d = 24
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: d, height: d,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }

        let c = color.usingColorSpace(.deviceRGB) ?? .white
        let colors = [
            CGColor(red: 1, green: 1, blue: 1, alpha: 1.0),
            CGColor(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: 1.0),
            CGColor(red: c.redComponent, green: c.greenComponent, blue: c.blueComponent, alpha: 0.0),
        ] as CFArray
        guard let gradient = CGGradient(colorsSpace: cs, colors: colors,
                                        locations: [0.0, 0.35, 1.0]) else { return nil }

        let center = CGPoint(x: d / 2, y: d / 2)
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                               endCenter: center, endRadius: CGFloat(d) / 2, options: [])
        return ctx.makeImage()
    }
}

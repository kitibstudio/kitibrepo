import SwiftUI
import UIKit

/// A transparent, non-interactive overlay that bursts a short firework when
/// `trigger` increments. On iPad a plain CAEmitterLayer over the SwiftUI tree
/// is enough — no floating window needed (that workaround is macOS-only).
struct FireworksOverlay: UIViewRepresentable {
    var trigger: Int

    func makeUIView(context: Context) -> FireworksUIView {
        let v = FireworksUIView()
        v.isUserInteractionEnabled = false
        v.backgroundColor = .clear
        context.coordinator.lastTrigger = trigger
        return v
    }

    func updateUIView(_ uiView: FireworksUIView, context: Context) {
        if trigger != context.coordinator.lastTrigger {
            context.coordinator.lastTrigger = trigger
            if trigger > 0 { uiView.celebrate() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastTrigger = 0 }
}

final class FireworksUIView: UIView {
    private let colors: [UIColor] = [.systemPink, .systemTeal, .systemYellow, .systemPurple, .systemGreen]

    func celebrate() {
        let shells: [(CGFloat, CGFloat, Double)] = [
            (0.78, 0.42, 0.0), (0.55, 0.30, 0.22), (0.30, 0.46, 0.44),
        ]
        for (i, shell) in shells.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + shell.2) { [weak self] in
                guard let self else { return }
                let apex = CGPoint(x: self.bounds.width * shell.0, y: self.bounds.height * shell.1)
                self.burst(at: apex, color: self.colors[i % self.colors.count])
            }
        }
    }

    private func burst(at point: CGPoint, color: UIColor) {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = point
        emitter.emitterShape = .point
        emitter.emitterMode = .outline
        emitter.renderMode = .additive

        let cell = CAEmitterCell()
        cell.birthRate = 1400
        cell.lifetime = 1.6
        cell.velocity = 180
        cell.velocityRange = 60
        cell.emissionRange = .pi * 2
        cell.yAcceleration = 120
        cell.scale = 0.05
        cell.scaleRange = 0.03
        cell.alphaSpeed = -0.7
        cell.color = color.cgColor
        cell.contents = Self.sparkImage.cgImage
        emitter.emitterCells = [cell]

        layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { emitter.removeFromSuperlayer() }
    }

    private static let sparkImage: UIImage = {
        let size = CGSize(width: 12, height: 12)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size))
        }
    }()
}

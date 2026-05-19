//
//  MotionSphereView.swift
//  Essential_Watch Watch App
//
//  EXPERIMENTAL / PROTOTYPE — likely to be removed in a future phase.
//
//  Cheap "fake-3D" visualization of the live accelerometer vector. We draw a
//  semi-transparent wireframe sphere with SwiftUI's `Canvas` and place a dot at
//  the projected (x, y, z) tip of the acceleration vector. Depth (z) is encoded
//  via dot size + opacity rather than a real 3D pipeline, so this stays light
//  on the watch's GPU/battery compared with a SceneKit scene.
//
//  When the project moves to a proper 3D renderer (SceneKit/RealityKit/Metal),
//  delete this file and its TabView entry in `ContentView`.
//

import SwiftUI

/// Page showing a translucent sphere with a moving dot that tracks the
/// accelerometer's instantaneous direction.
///
/// Reads `MotionManager.latestSample` and applies a simple exponential moving
/// average so the dot glides instead of jittering at 50 Hz.
struct MotionSphereView: View {
    @EnvironmentObject private var motion: MotionManager

    // Smoothed acceleration components, in g's. Held in @State so the EMA
    // survives across body re-evaluations without needing a view model — this
    // view is intentionally throwaway.
    @State private var sx: Double = 0
    @State private var sy: Double = 0
    @State private var sz: Double = 0

    // Low-pass smoothing factor. Higher = snappier but noisier.
    // 0.15 feels smooth at the 50 Hz sample rate configured in MotionManager.
    private let smoothing: Double = 0.15

    var body: some View {
        GeometryReader { geo in
            // Sphere is inscribed in the smaller of the two view dimensions,
            // with a margin so the dot doesn't clip the screen edge.
            let side = min(geo.size.width, geo.size.height)
            let radius = side * 0.42
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            Canvas { ctx, _ in
                drawSphere(in: ctx, center: center, radius: radius)
                drawAxes(in: ctx, center: center, radius: radius)
                drawDot(in: ctx, center: center, radius: radius)
            }
            .background(Color.black)
        }
        .ignoresSafeArea()
        // Pull updates from the published latestSample. We don't subscribe via
        // Combine to avoid spinning up a publisher chain on the watch; the
        // @EnvironmentObject already triggers body re-renders on each sample.
        .onChange(of: motion.latestSample?.timestamp) { _, _ in
            guard let s = motion.latestSample else { return }
            sx += (s.x - sx) * smoothing
            sy += (s.y - sy) * smoothing
            sz += (s.z - sz) * smoothing
        }
    }

    // MARK: - Drawing helpers

    /// Renders the sphere's silhouette plus a few "meridian/parallel" arcs so
    /// the eye reads it as a 3D ball rather than a flat circle. The arcs are
    /// just squashed ellipses — cheap to draw and good enough at watch scale.
    private func drawSphere(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let outline = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        ctx.fill(outline, with: .color(.white.opacity(0.06)))
        ctx.stroke(outline, with: .color(.white.opacity(0.35)), lineWidth: 1)

        // Three "parallels" (horizontal ellipses) at varying heights.
        for k in [-0.6, 0.0, 0.6] {
            let yOffset = radius * k
            let h = radius * sqrt(1 - k * k) * 0.35   // perspective squash
            let w = radius * sqrt(1 - k * k)
            let ell = Path(ellipseIn: CGRect(
                x: center.x - w, y: center.y + yOffset - h,
                width: w * 2, height: h * 2
            ))
            ctx.stroke(ell, with: .color(.white.opacity(0.18)), lineWidth: 0.6)
        }

        // Two "meridians" (vertical ellipses) rotated for depth.
        for k in [-0.5, 0.5] {
            let w = radius * abs(k)
            let ell = Path(ellipseIn: CGRect(
                x: center.x - w, y: center.y - radius,
                width: w * 2, height: radius * 2
            ))
            ctx.stroke(ell, with: .color(.white.opacity(0.18)), lineWidth: 0.6)
        }
    }

    /// Faint X/Y axis crosshair through the sphere center. Helps the eye
    /// register direction when the dot is near zero g.
    private func drawAxes(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        var x = Path()
        x.move(to: CGPoint(x: center.x - radius, y: center.y))
        x.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        ctx.stroke(x, with: .color(.white.opacity(0.12)), lineWidth: 0.5)

        var y = Path()
        y.move(to: CGPoint(x: center.x, y: center.y - radius))
        y.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        ctx.stroke(y, with: .color(.white.opacity(0.12)), lineWidth: 0.5)
    }

    /// Projects the smoothed accelerometer vector onto the 2D canvas and
    /// draws a glowing dot. Clamping caps acceleration at ~2g so violent
    /// shakes don't fling the dot off-screen.
    private func drawDot(in ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let clamp: (Double) -> Double = { max(-1.0, min(1.0, $0 / 2.0)) }
        let nx = clamp(sx)
        let ny = clamp(sy)
        let nz = clamp(sz)

        // Watch X axis maps to screen X (right positive).
        // Watch Y axis maps to screen Y inverted (up positive).
        let px = center.x + CGFloat(nx) * radius
        let py = center.y - CGFloat(ny) * radius

        // Z encodes depth: positive z (face-down) → smaller + dimmer dot;
        // negative z (face-up) → larger + brighter. This is the cheap
        // substitute for an actual perspective transform.
        let depthScale = 1.0 - nz * 0.5            // 0.5...1.5
        let dotRadius = max(3.0, 6.0 * depthScale)
        let opacity = 0.5 + (1.0 - (nz + 1) / 2) * 0.5  // 0.5...1.0

        let dotRect = CGRect(
            x: px - dotRadius, y: py - dotRadius,
            width: dotRadius * 2, height: dotRadius * 2
        )

        // Soft halo for a bit of glow without resorting to a blur filter,
        // which is expensive on watchOS.
        let halo = CGRect(
            x: px - dotRadius * 2.2, y: py - dotRadius * 2.2,
            width: dotRadius * 4.4, height: dotRadius * 4.4
        )
        ctx.fill(Path(ellipseIn: halo), with: .color(.cyan.opacity(0.15 * opacity)))
        ctx.fill(Path(ellipseIn: dotRect), with: .color(.cyan.opacity(opacity)))
    }
}

#Preview {
    let motion = MotionManager()
    return MotionSphereView()
        .environmentObject(motion)
}

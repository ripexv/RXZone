//
//  PanelMetrics.swift
//  RXZone
//

import SwiftUI

/// One scale for the whole menu bar panel.
///
/// The panel was assembled piece by piece and each piece had picked its own
/// numbers: content started 12, 14, 16 or 18 points from the left, and text
/// came in four unrelated sizes, which is what made it look uneven. Every view
/// in the panel now reads its sizes from here.
enum PanelMetrics {
    static let width: CGFloat = 330

    /// The single left and right edge every piece of content lines up on.
    static let edge: CGFloat = 16
    /// How far the clock list itself is inset; each row pads the rest of the
    /// way to `edge`, so a hovered row's card stops just short of the panel.
    static let listInset: CGFloat = 6

    static let headerTime: CGFloat = 34
    static let title: CGFloat = 15
    static let body: CGFloat = 12
    static let note: CGFloat = 11

    static let avatar: CGFloat = 40
}

/// Whether it is day or night where a zone is, drawn as the disc's backdrop.
enum SkyScene: Equatable {
    case day, night

    /// `nil` when there are no coordinates to reason from; the disc then
    /// stays plain rather than guess.
    init?(isDaylight: Bool?) {
        guard let isDaylight else { return nil }
        self = isDaylight ? .day : .night
    }
}

/// An emoji on a disc. Shared by the clock rows and the search results,
/// so a zone looks the same before and after it is added.
struct EmojiDisc: View {
    let symbol: String
    let size: CGFloat
    /// The sky behind the emoji: clouds and a sun by day, a crescent moon and
    /// stars by night. The circle itself carries the answer, so there is no
    /// badge sitting awkwardly on its edge.
    var sky: SkyScene?

    var body: some View {
        // A two-emoji symbol has to shrink to stay inside the circle.
        let isPair = symbol.count > 1
        Text(symbol)
            .font(.system(size: size * (isPair ? 0.36 : 0.55)))
            .frame(width: size, height: size)
            .background {
                ZStack {
                    // Solid, not translucent: over the panel's blurred material
                    // a faint wash read as a hole.
                    Circle().fill(.background)
                    SkyBackdrop(scene: .day).opacity(sky == .day ? 1 : 0)
                    SkyBackdrop(scene: .night).opacity(sky == .night ? 1 : 0)
                }
                .clipShape(Circle())
                .compositingGroup()
                .shadow(color: .black.opacity(0.14), radius: 2.5, y: 1)
            }
            .overlay(Circle().strokeBorder(Color.primary.opacity(sky == nil ? 0.06 : 0.08), lineWidth: 0.5))
            .animation(.easeInOut(duration: 0.4), value: sky)
            .accessibilityHidden(true)
    }
}

/// A tiny sky, drawn rather than made of emoji so it stays behind the zone's
/// own symbol. Everything is kept to the rim: the middle belongs to the emoji.
private struct SkyBackdrop: View {
    let scene: SkyScene

    var body: some View {
        Canvas { context, size in
            let w = size.width
            switch scene {
            case .day: Self.drawDay(in: &context, w: w)
            case .night: Self.drawNight(in: &context, w: w)
            }
        }
    }

    // MARK: Day

    private static func drawDay(in context: inout GraphicsContext, w: CGFloat) {
        fillSky(in: &context, w: w,
                top: Color(hue: 0.575, saturation: 0.55, brightness: 0.96),
                bottom: Color(hue: 0.55, saturation: 0.18, brightness: 1.0))

        // Sun in the upper right, with a soft glow.
        let sun = CGPoint(x: w * 0.78, y: w * 0.22)
        context.fill(
            circle(at: sun, radius: w * 0.24),
            with: .radialGradient(
                Gradient(colors: [Color(hue: 0.14, saturation: 0.6, brightness: 1).opacity(0.75), .clear]),
                center: sun, startRadius: 0, endRadius: w * 0.24))
        context.fill(circle(at: sun, radius: w * 0.10),
                     with: .color(Color(hue: 0.13, saturation: 0.72, brightness: 1)))

        // Clouds drifting along the bottom.
        context.fill(cloud(center: CGPoint(x: w * 0.26, y: w * 0.82), width: w * 0.46),
                     with: .color(.white.opacity(0.95)))
        context.fill(cloud(center: CGPoint(x: w * 0.80, y: w * 0.86), width: w * 0.34),
                     with: .color(.white.opacity(0.9)))
        context.fill(cloud(center: CGPoint(x: w * 0.20, y: w * 0.30), width: w * 0.22),
                     with: .color(.white.opacity(0.75)))
    }

    /// Two puffs on a flat base, filled as one path so the overlaps don't show.
    private static func cloud(center c: CGPoint, width wd: CGFloat) -> Path {
        let h = wd * 0.5
        var path = Path(roundedRect: CGRect(x: c.x - wd / 2, y: c.y - h * 0.1, width: wd, height: h * 0.5),
                        cornerRadius: h * 0.25)
        path.addPath(circle(at: CGPoint(x: c.x - wd * 0.16, y: c.y + h * 0.02), radius: wd * 0.2))
        path.addPath(circle(at: CGPoint(x: c.x + wd * 0.1, y: c.y - h * 0.08), radius: wd * 0.26))
        return path
    }

    // MARK: Night

    /// Positions and sizes as fractions of the disc, kept clear of the middle.
    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat, alpha: Double)] = [
        (0.22, 0.28, 0.022, 0.95), (0.38, 0.12, 0.015, 0.7), (0.55, 0.09, 0.018, 0.85),
        (0.12, 0.52, 0.015, 0.6), (0.88, 0.52, 0.018, 0.8), (0.82, 0.74, 0.014, 0.6),
        (0.26, 0.84, 0.015, 0.55), (0.60, 0.90, 0.013, 0.5), (0.45, 0.80, 0.011, 0.4),
    ]

    private static func drawNight(in context: inout GraphicsContext, w: CGFloat) {
        fillSky(in: &context, w: w,
                top: Color(hue: 0.665, saturation: 0.78, brightness: 0.20),
                bottom: Color(hue: 0.69, saturation: 0.58, brightness: 0.44))

        for star in stars {
            context.fill(circle(at: CGPoint(x: star.x * w, y: star.y * w), radius: star.r * w),
                         with: .color(.white.opacity(star.alpha)))
        }

        // A crescent moon in the upper right, with a faint halo.
        let moon = CGPoint(x: w * 0.76, y: w * 0.25)
        let radius = w * 0.12
        context.fill(
            circle(at: moon, radius: radius * 2.2),
            with: .radialGradient(
                Gradient(colors: [Color(hue: 0.14, saturation: 0.2, brightness: 1).opacity(0.28), .clear]),
                center: moon, startRadius: radius * 0.5, endRadius: radius * 2.2))
        let crescent = circle(at: moon, radius: radius)
            .subtracting(circle(at: CGPoint(x: moon.x - radius * 0.55, y: moon.y - radius * 0.35),
                                radius: radius * 0.9))
        context.fill(crescent, with: .color(Color(hue: 0.14, saturation: 0.22, brightness: 1)))
    }

    // MARK: Helpers

    private static func fillSky(in context: inout GraphicsContext, w: CGFloat, top: Color, bottom: Color) {
        context.fill(Path(CGRect(x: 0, y: 0, width: w, height: w)),
                     with: .linearGradient(Gradient(colors: [top, bottom]),
                                           startPoint: CGPoint(x: w / 2, y: 0),
                                           endPoint: CGPoint(x: w / 2, y: w)))
    }

    private static func circle(at c: CGPoint, radius r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}

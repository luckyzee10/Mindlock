import SwiftUI

// MARK: - Design System inspired by a focused, educational dark aesthetic
struct DesignSystem {
    
    // MARK: - Colors (Dark learning theme)
    struct Colors {
        // Dark backgrounds
        static let background = Color.black
        static let surface = Color(red: 0.08, green: 0.10, blue: 0.14)
        static let surfaceSecondary = Color(red: 0.12, green: 0.15, blue: 0.20)
        
        // Accent colors
        static let primary = Color(red: 0.22, green: 0.58, blue: 0.95)
        static let accent = Color(red: 0.58, green: 0.44, blue: 0.96)
        static let success = Color(red: 0.18, green: 0.78, blue: 0.62)
        static let warning = Color(red: 0.95, green: 0.68, blue: 0.24)
        static let error = Color(red: 0.95, green: 0.28, blue: 0.32)
        
        // Text colors (for dark theme)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.70, green: 0.70, blue: 0.73) // Light gray
        static let textTertiary = Color(red: 0.50, green: 0.50, blue: 0.53) // Medium gray
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let impactGradient = LinearGradient(
            colors: [primary, success],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [accent, Color(red: 0.40, green: 0.33, blue: 0.82)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [
                Color.black,
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography (Modern, clean)
    struct Typography {
        static let largeTitle = Font.system(size: 32, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .bold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        static let headline = Font.system(size: 17, weight: .semibold, design: .default)
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius (Subtle, not bubbly)
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows (Subtle for dark theme)
    struct Shadows {
        static let small = Shadow(
            color: Color.black.opacity(0.3),
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let medium = Shadow(
            color: Color.black.opacity(0.4),
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let large = Shadow(
            color: Color.black.opacity(0.5),
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    // MARK: - App Background
    struct AppBackground: View {
        var body: some View {
            ParticleBackground()
                .ignoresSafeArea()
        }
    }

    struct ParticleBackground: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        private let particleCount = 86

        var body: some View {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size)
                    context.fill(Path(rect), with: .color(Colors.background))

                    let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate

                    for index in 0..<particleCount {
                        drawParticle(index: index, time: time, size: size, context: &context)
                    }
                }
            }
            .background(Colors.background)
        }

        private func drawParticle(
            index: Int,
            time: TimeInterval,
            size: CGSize,
            context: inout GraphicsContext
        ) {
            let baseX = seededValue(index, salt: 1)
            let baseY = seededValue(index, salt: 2)
            let sizeSeed = seededValue(index, salt: 3)
            let speedSeed = seededValue(index, salt: 4)
            let phase = seededValue(index, salt: 5) * .pi * 2

            let drift = sin(time * (0.08 + speedSeed * 0.08) + phase) * (8 + speedSeed * 16)
            let speed = 2.5 + speedSeed * 7
            let yRange = Double(size.height + 48)
            let y = (baseY * yRange + time * speed).truncatingRemainder(dividingBy: yRange) - 24
            let x = baseX * Double(size.width) + drift

            let radius = 0.35 + sizeSeed * 0.55
            let primaryFlicker = (sin(time * (0.8 + speedSeed * 1.6) + phase) + 1) / 2
            let secondaryFlicker = (sin(time * (1.7 + speedSeed * 2.4) + phase * 1.7) + 1) / 2
            let sparkle = pow((primaryFlicker * 0.75) + (secondaryFlicker * 0.25), 2.2)
            let opacity = 0.10 + sparkle * (0.50 + sizeSeed * 0.26)
            let whiteness = 0.62 + sparkle * 0.38

            let particleRect = CGRect(
                x: x - radius,
                y: y - radius,
                width: radius * 2,
                height: radius * 2
            )

            let glowRadius = radius * 2.2
            let glowRect = CGRect(
                x: x - glowRadius,
                y: y - glowRadius,
                width: glowRadius * 2,
                height: glowRadius * 2
            )

            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(Color.white.opacity(opacity * 0.035))
            )
            context.fill(
                Path(ellipseIn: particleRect),
                with: .color(Color.white.opacity(opacity * whiteness))
            )
        }

        private func seededValue(_ index: Int, salt: Double) -> Double {
            let raw = sin(Double(index + 1) * 12.9898 + salt * 78.233) * 43758.5453
            return raw - floor(raw)
        }
    }

    // MARK: - Liquid Glass
    struct GlossySurface: View {
        let base: Color
        let cornerRadius: CGFloat
        let opacity: Double

        init(
            base: Color = Colors.surface,
            cornerRadius: CGFloat = CornerRadius.md,
            opacity: Double = 0.92
        ) {
            self.base = base
            self.cornerRadius = cornerRadius
            self.opacity = opacity
        }

        var body: some View {
            if #available(iOS 26.0, *) {
                nativeLiquidGlass
            } else {
                fallbackGlass
            }
        }

        @available(iOS 26.0, *)
        private var nativeLiquidGlass: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(base.opacity(0.18))
                .glassEffect(
                    .regular.tint(base.opacity(opacity)).interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 14, x: 0, y: 8)
        }

        private var fallbackGlass: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(base.opacity(opacity))
                .overlay(glossOverlay)
                .overlay(borderOverlay)
                .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        }

        private var glossOverlay: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.07),
                            Color.black.opacity(0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }

        private var borderOverlay: some View {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.white.opacity(0.07),
                            Color.black.opacity(0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    struct GlossyButtonBackground: View {
        let style: MindLockButtonStyle
        let pressed: Bool
        let cornerRadius: CGFloat

        init(
            style: MindLockButtonStyle,
            pressed: Bool = false,
            cornerRadius: CGFloat = CornerRadius.md
        ) {
            self.style = style
            self.pressed = pressed
            self.cornerRadius = cornerRadius
        }

        var body: some View {
            if #available(iOS 26.0, *) {
                nativeLiquidGlass
            } else {
                fallbackGlass
            }
        }

        @available(iOS 26.0, *)
        private var nativeLiquidGlass: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            return shape
                .fill(Color.white.opacity(style == .ghost ? 0 : 0.035))
                .glassEffect(
                    glassMaterial,
                    in: shape
                )
                .overlay(
                    shape.stroke(borderColor, lineWidth: style == .ghost ? 0 : 1)
                )
                .brightness(pressed ? -0.05 : 0)
        }

        private var fallbackGlass: some View {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            return ZStack {
                shape
                    .fill(Color.white.opacity(style == .ghost ? 0 : 0.075))
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(style == .ghost ? 0 : 0.12),
                                Color.white.opacity(style == .ghost ? 0 : 0.035),
                                tintColor.opacity(style == .ghost ? 0 : 0.08),
                                Color.black.opacity(style == .ghost ? 0 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                shape.stroke(borderColor, lineWidth: style == .ghost ? 0 : 1)
            }
            .brightness(pressed ? -0.05 : 0)
        }

        @available(iOS 26.0, *)
        private var glassMaterial: Glass {
            .regular.tint(glassTintColor).interactive()
        }

        private var tintColor: Color {
            switch style {
            case .primary:
                return Colors.primary
            case .impact:
                return Colors.success
            case .secondary:
                return Color.white
            case .destructive:
                return Colors.accent
            case .ghost:
                return Color.clear
            }
        }

        private var glassTintColor: Color {
            switch style {
            case .ghost:
                return Color.clear
            case .secondary:
                return Color.black.opacity(0.28)
            default:
                return Color.black.opacity(0.24)
            }
        }

        private var borderColor: Color {
            switch style {
            case .primary:
                return Colors.primary.opacity(0.26)
            case .impact:
                return Colors.success.opacity(0.28)
            case .secondary:
                return Color.white.opacity(0.13)
            case .destructive:
                return Colors.accent.opacity(0.30)
            case .ghost:
                return Color.clear
            }
        }
    }
    
    // MARK: - Animation (Smooth and subtle)
    struct Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let gentle = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.8)
    }
}

// MARK: - View Extensions for Dark Opal-style Design
extension View {
    
    func mindLockCard() -> some View {
        self
            .glossySurface()
            .shadow(
                color: DesignSystem.Shadows.medium.color,
                radius: DesignSystem.Shadows.medium.radius,
                x: DesignSystem.Shadows.medium.x,
                y: DesignSystem.Shadows.medium.y
            )
    }
    
    func mindLockButton(style: MindLockButtonStyle = .primary) -> some View {
        self
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle())
            .background(DesignSystem.GlossyButtonBackground(style: style))
            .foregroundColor(style.foregroundColor)
            .shadow(
                color: style.shadowColor,
                radius: 4,
                x: 0,
                y: 2
            )
    }
}

// MARK: - ButtonStyle ensuring full-width hit testing
extension DesignSystem {
    struct FullWidthButtonStyle: ButtonStyle {
        let style: MindLockButtonStyle
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .contentShape(Rectangle())
                .background(DesignSystem.GlossyButtonBackground(style: style, pressed: configuration.isPressed))
                .foregroundColor(style.foregroundColor)
                .shadow(color: style.shadowColor, radius: 4, x: 0, y: 2)
        }
    }
}

// Prefer this overload when called on Button so the hit area is the full styled region
extension Button {
    func mindLockButton(style: MindLockButtonStyle = .primary) -> some View {
        self.buttonStyle(DesignSystem.FullWidthButtonStyle(style: style))
    }
}

enum MindLockButtonStyle: Equatable {
    case primary
    case secondary
    case destructive
    case ghost
    case impact
    
    var backgroundColor: some View {
        AnyView(DesignSystem.GlossyButtonBackground(style: self))
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive, .impact:
            return .white
        case .secondary:
            return DesignSystem.Colors.textPrimary
        case .ghost:
            return DesignSystem.Colors.primary
        }
    }
    
    var shadowColor: Color {
        switch self {
        case .primary:
            return DesignSystem.Colors.primary.opacity(0.3)
        case .impact:
            return DesignSystem.Colors.primary.opacity(0.35)
        case .destructive:
            return DesignSystem.Colors.accent.opacity(0.3)
        case .secondary, .ghost:
            return Color.clear
        }
    }
} 

extension View {
    func glossySurface(
        base: Color = DesignSystem.Colors.surface,
        cornerRadius: CGFloat = DesignSystem.CornerRadius.md,
        opacity: Double = 0.92
    ) -> some View {
        self.background(
            DesignSystem.GlossySurface(
                base: base,
                cornerRadius: cornerRadius,
                opacity: opacity
            )
        )
    }
}

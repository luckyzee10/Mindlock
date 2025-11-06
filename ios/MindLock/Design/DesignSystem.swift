import SwiftUI

// MARK: - Design System inspired by Opal's dark, sleek aesthetic
struct DesignSystem {
    
    // MARK: - Colors (Dark theme like Opal)
    struct Colors {
        // Dark backgrounds
        static let background = Color(red: 0.06, green: 0.06, blue: 0.08) // Very dark blue-black
        static let surface = Color(red: 0.11, green: 0.11, blue: 0.13) // Dark card background
        static let surfaceSecondary = Color(red: 0.15, green: 0.15, blue: 0.17) // Slightly lighter
        
        // Accent colors
        static let primary = Color(red: 0.45, green: 0.55, blue: 1.0) // Bright blue
        static let accent = Color(red: 1.0, green: 0.27, blue: 0.23) // Red for warnings/blocks
        static let success = Color(red: 0.20, green: 0.78, blue: 0.35) // Green
        static let warning = Color(red: 1.0, green: 0.58, blue: 0.0) // Orange
        static let error = Color(red: 1.0, green: 0.27, blue: 0.23) // Red
        
        // Text colors (for dark theme)
        static let textPrimary = Color.white
        static let textSecondary = Color(red: 0.70, green: 0.70, blue: 0.73) // Light gray
        static let textTertiary = Color(red: 0.50, green: 0.50, blue: 0.53) // Medium gray
        
        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, Color(red: 0.35, green: 0.45, blue: 0.90)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let accentGradient = LinearGradient(
            colors: [accent, Color(red: 0.90, green: 0.20, blue: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let backgroundGradient = LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.06, blue: 0.08),
                Color(red: 0.08, green: 0.08, blue: 0.10)
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
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.CornerRadius.md)
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
            .background(style.backgroundColor)
            .foregroundColor(style.foregroundColor)
            .cornerRadius(DesignSystem.CornerRadius.md)
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
                .background(background(for: configuration.isPressed))
                .foregroundColor(style.foregroundColor)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .shadow(color: style.shadowColor, radius: 4, x: 0, y: 2)
        }

        @ViewBuilder
        private func background(for pressed: Bool) -> some View {
            switch style {
            case .primary:
                DesignSystem.Colors.primaryGradient
                    .brightness(pressed ? -0.05 : 0)
            case .secondary:
                DesignSystem.Colors.surface
                    .opacity(pressed ? 0.9 : 1.0)
            case .destructive:
                DesignSystem.Colors.accentGradient
                    .brightness(pressed ? -0.05 : 0)
            case .ghost:
                Color.clear
            }
        }
    }
}

// Prefer this overload when called on Button so the hit area is the full styled region
extension Button {
    func mindLockButton(style: MindLockButtonStyle = .primary) -> some View {
        self.buttonStyle(DesignSystem.FullWidthButtonStyle(style: style))
    }
}

enum MindLockButtonStyle {
    case primary
    case secondary
    case destructive
    case ghost
    
    var backgroundColor: some View {
        switch self {
        case .primary:
            return AnyView(DesignSystem.Colors.primaryGradient)
        case .secondary:
            return AnyView(DesignSystem.Colors.surface)
        case .destructive:
            return AnyView(DesignSystem.Colors.accentGradient)
        case .ghost:
            return AnyView(Color.clear)
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive:
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
        case .destructive:
            return DesignSystem.Colors.accent.opacity(0.3)
        case .secondary, .ghost:
            return Color.clear
        }
    }
} 

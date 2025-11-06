import Foundation
import SwiftUI

enum AnalyticsTimeframe: CaseIterable, Identifiable {
    case today
    case week
    case month
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}

struct AnalyticsSnapshot: Identifiable {
    let id = UUID()
    let timeframe: AnalyticsTimeframe
    let totalScreenTime: TimeInterval
    let timeOffScreen: TimeInterval
    let dailyGoal: TimeInterval
    let totalDonated: Double
    let blocks: Int
    let goalProgress: Double
    let appUsage: [AppUsageData]
    let hourlyBreakdown: [UsagePoint]
    let productivityScore: Double
    let charityBreakdown: [CharityShare]
}

struct UsagePoint: Identifiable {
    let id = UUID()
    let hourLabel: String
    let usage: TimeInterval
}

struct CharityShare: Identifiable {
    let id = UUID()
    let charityName: String
    let amount: Double
    /// Value between 0 and 1 representing the percent of total donations.
    let percentage: Double
}

struct AppUsageData: Identifiable {
    let id = UUID()
    let appName: String
    let usage: TimeInterval
    let category: AppCategory
    let iconName: String
    let trend: UsageTrend
}

enum UsageTrend {
    case up(Double)
    case down(Double)
    case flat
}

enum AppCategory {
    case social
    case entertainment
    case productivity
    case communication
    
    var color: Color {
        switch self {
        case .social: return DesignSystem.Colors.accent
        case .entertainment: return DesignSystem.Colors.warning
        case .productivity: return DesignSystem.Colors.success
        case .communication: return DesignSystem.Colors.primary
        }
    }
}

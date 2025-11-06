import Foundation

struct AnalyticsMockDataProvider {
    func snapshot(for timeframe: AnalyticsTimeframe) -> AnalyticsSnapshot {
        switch timeframe {
        case .today:
            return AnalyticsSnapshot(
                timeframe: .today,
                totalScreenTime: 3.5 * 3600,
                timeOffScreen: 13.5 * 3600,
                dailyGoal: 3 * 3600,
                totalDonated: 10.0,
                blocks: 6,
                goalProgress: 0.78,
                appUsage: AppUsageData.todayMocks,
                hourlyBreakdown: UsagePoint.mockToday,
                productivityScore: 0.68,
                charityBreakdown: CharityShare.mockToday
            )
        case .week:
            return AnalyticsSnapshot(
                timeframe: .week,
                totalScreenTime: 24 * 3600,
                timeOffScreen: 120 * 3600,
                dailyGoal: 3 * 3600,
                totalDonated: 68.0,
                blocks: 38,
                goalProgress: 0.82,
                appUsage: AppUsageData.weekMocks,
                hourlyBreakdown: UsagePoint.mockWeek,
                productivityScore: 0.72,
                charityBreakdown: CharityShare.mockWeek
            )
        case .month:
            return AnalyticsSnapshot(
                timeframe: .month,
                totalScreenTime: 92 * 3600,
                timeOffScreen: 580 * 3600,
                dailyGoal: 3 * 3600,
                totalDonated: 240.0,
                blocks: 142,
                goalProgress: 0.76,
                appUsage: AppUsageData.monthMocks,
                hourlyBreakdown: UsagePoint.mockMonth,
                productivityScore: 0.74,
                charityBreakdown: CharityShare.mockMonth
            )
        }
    }
}

// MARK: - Mock Extensions
private extension AppUsageData {
    static let todayMocks: [AppUsageData] = [
        AppUsageData(appName: "Instagram", usage: 4200, category: .social, iconName: "camera.fill", trend: .down(0.12)),
        AppUsageData(appName: "YouTube", usage: 3200, category: .entertainment, iconName: "play.rectangle.fill", trend: .up(0.18)),
        AppUsageData(appName: "Slack", usage: 2700, category: .productivity, iconName: "bubble.left.and.text.bubble.right.fill", trend: .up(0.05)),
        AppUsageData(appName: "Safari", usage: 2100, category: .productivity, iconName: "safari.fill", trend: .flat),
        AppUsageData(appName: "Messages", usage: 1600, category: .communication, iconName: "message.fill", trend: .down(0.08))
    ]
    
    static let weekMocks: [AppUsageData] = [
        AppUsageData(appName: "Instagram", usage: 6 * 3600, category: .social, iconName: "camera.fill", trend: .down(0.05)),
        AppUsageData(appName: "YouTube", usage: 17 * 3600, category: .entertainment, iconName: "play.rectangle.fill", trend: .up(0.12)),
        AppUsageData(appName: "Slack", usage: 14 * 3600, category: .productivity, iconName: "bubble.left.and.text.bubble.right.fill", trend: .up(0.2)),
        AppUsageData(appName: "Safari", usage: 9 * 3600, category: .productivity, iconName: "safari.fill", trend: .flat),
        AppUsageData(appName: "Messages", usage: 8 * 3600, category: .communication, iconName: "message.fill", trend: .down(0.02))
    ]
    
    static let monthMocks: [AppUsageData] = [
        AppUsageData(appName: "Instagram", usage: 21 * 3600, category: .social, iconName: "camera.fill", trend: .down(0.04)),
        AppUsageData(appName: "YouTube", usage: 64 * 3600, category: .entertainment, iconName: "play.rectangle.fill", trend: .up(0.15)),
        AppUsageData(appName: "Slack", usage: 50 * 3600, category: .productivity, iconName: "bubble.left.and.text.bubble.right.fill", trend: .up(0.09)),
        AppUsageData(appName: "Safari", usage: 35 * 3600, category: .productivity, iconName: "safari.fill", trend: .flat),
        AppUsageData(appName: "Messages", usage: 30 * 3600, category: .communication, iconName: "message.fill", trend: .down(0.01))
    ]
}

private extension UsagePoint {
    static let mockToday: [UsagePoint] = [
        UsagePoint(hourLabel: "06:00", usage: 600),
        UsagePoint(hourLabel: "08:00", usage: 900),
        UsagePoint(hourLabel: "10:00", usage: 1200),
        UsagePoint(hourLabel: "12:00", usage: 1500),
        UsagePoint(hourLabel: "14:00", usage: 1100),
        UsagePoint(hourLabel: "16:00", usage: 900),
        UsagePoint(hourLabel: "18:00", usage: 1300),
        UsagePoint(hourLabel: "20:00", usage: 700)
    ]
    
    static let mockWeek: [UsagePoint] = [
        UsagePoint(hourLabel: "Mon", usage: 3.2 * 3600),
        UsagePoint(hourLabel: "Tue", usage: 3.8 * 3600),
        UsagePoint(hourLabel: "Wed", usage: 3.0 * 3600),
        UsagePoint(hourLabel: "Thu", usage: 4.1 * 3600),
        UsagePoint(hourLabel: "Fri", usage: 4.3 * 3600),
        UsagePoint(hourLabel: "Sat", usage: 5.2 * 3600),
        UsagePoint(hourLabel: "Sun", usage: 3.7 * 3600)
    ]
    
    static let mockMonth: [UsagePoint] = (1...4).map { week in
        UsagePoint(hourLabel: "Week \(week)", usage: Double.random(in: 21...28) * 3600)
    }
}

private extension CharityShare {
    static let mockToday: [CharityShare] = [
        CharityShare(charityName: "World Literacy Fund", amount: 4.5, percentage: 0.45),
        CharityShare(charityName: "Clean Water Now", amount: 3.0, percentage: 0.30),
        CharityShare(charityName: "Global Meals", amount: 2.5, percentage: 0.25)
    ]
    
    static let mockWeek: [CharityShare] = [
        CharityShare(charityName: "World Literacy Fund", amount: 28.0, percentage: 28.0 / 68.0),
        CharityShare(charityName: "Clean Water Now", amount: 22.0, percentage: 22.0 / 68.0),
        CharityShare(charityName: "Global Meals", amount: 18.0, percentage: 18.0 / 68.0)
    ]
    
    static let mockMonth: [CharityShare] = [
        CharityShare(charityName: "World Literacy Fund", amount: 110.0, percentage: 110.0 / 240.0),
        CharityShare(charityName: "Clean Water Now", amount: 80.0, percentage: 80.0 / 240.0),
        CharityShare(charityName: "Global Meals", amount: 50.0, percentage: 50.0 / 240.0)
    ]
}

import Foundation
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var snapshot: AnalyticsSnapshot
    private let provider: AnalyticsProvider

    init(provider: AnalyticsProvider = AnalyticsProvider(), initialTimeframe: AnalyticsTimeframe = .today) {
        self.provider = provider
        self.snapshot = provider.snapshot(for: initialTimeframe)
    }

    func update(timeframe: AnalyticsTimeframe) {
        snapshot = provider.snapshot(for: timeframe)
    }
}

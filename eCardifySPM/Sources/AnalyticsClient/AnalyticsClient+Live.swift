import os
import Dependencies
import AlifAnalytics

extension AnalyticsClient {
    public static let liveValue = AnalyticsClient(
        track: { event in
            let (name, properties) = event.nameAndProperties
            #if DEBUG
            analyticsLogger.debug("\u{1F4CA} track: \(name) \(properties)")
            #endif
            AlifAnalytics.shared.track(name, properties: properties.isEmpty ? nil : properties)
        },
        identify: { userId in
            #if DEBUG
            analyticsLogger.debug("\u{1F4CA} identify: \(userId)")
            #endif
            // AlifAnalytics uses install_id internally; log userId for future use
        }
    )
}

private let analyticsLogger = Logger(subsystem: "cardify.addame.com.eCardify", category: "analytics")

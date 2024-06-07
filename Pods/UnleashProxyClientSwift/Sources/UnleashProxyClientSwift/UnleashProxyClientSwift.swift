import Foundation
import SwiftEventBus

// MARK: - Welcome
struct FeatureResponse: Codable {
    let toggles: [Toggle]
}

// MARK: - Toggle
public struct Toggle: Codable {
    public let name: String
    public let enabled: Bool
    public let variant: Variant
}

// MARK: - Variant
public struct Variant: Codable {
    public let name: String
    public let enabled: Bool
    public let payload: Payload?
}

// MARK: - Payload
public struct Payload: Codable {
    public let type, value: String
}


@available(macOS 10.15, *)
public class UnleashClientBase {
    public var context: Context
    var timer: Timer?
    var poller: Poller
    var metrics: Metrics

    public init(unleashUrl: String, clientKey: String, refreshInterval: Int = 15, metricsInterval: Int = 30, disableMetrics: Bool = false, appName: String = "unleash-swift-client", environment: String? = "default", context: [String: String]? = nil, poller: Poller? = nil, metrics: Metrics? = nil) {
        guard let url = URL(string: unleashUrl), url.scheme != nil else {
            fatalError("Invalid Unleash URL: \(unleashUrl)")
        }

        self.timer = nil
        if let poller = poller {
            self.poller = poller
        } else {
            self.poller = Poller(refreshInterval: refreshInterval, unleashUrl: url, apiKey: clientKey)
        }
        if let metrics = metrics {
            self.metrics = metrics
        } else {
            let urlSessionPoster: Metrics.PosterHandler = { request, completionHandler in
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if let error = error {
                        completionHandler(.failure(error))
                    } else if let data = data, let response = response {
                        completionHandler(.success((data, response)))
                    }
                }
                task.resume()
            }
            self.metrics = Metrics(appName: appName, metricsInterval: Double(metricsInterval), clock: { return Date() }, disableMetrics: disableMetrics, poster: urlSessionPoster, url: url, clientKey: clientKey)
        }
        
        self.context = Context(appName: appName, environment: environment)
        if let providedContext = context {
            self.context = self.calculateContext(context: providedContext)
        }
    }

    public func start(_ printToConsole: Bool = false, completionHandler: ((PollerError?) -> Void)? = nil) -> Void {
        Printer.showPrintStatements = printToConsole
        self.stop()
        poller.start(context: context, completionHandler: completionHandler)
        metrics.start()
    }

    public func stop() -> Void {
        poller.stop()
        metrics.stop()
    }

    public func isEnabled(name: String) -> Bool {
        let enabled = poller.getFeature(name: name)?.enabled ?? false
        metrics.count(name: name, enabled: enabled)
        return enabled
    }

    public func getVariant(name: String) -> Variant {
        let variant = poller.getFeature(name: name)?.variant ?? Variant(name: "disabled", enabled: false, payload: nil)
        metrics.count(name: name, enabled: variant.enabled)
        metrics.countVariant(name: name, variant: variant.name)
        return variant
    }

    public func subscribe(name: String, callback: @escaping () -> Void) {
        SwiftEventBus.onBackgroundThread(self, name: name) { result in
            callback()
        }
    }

    public func unsubscribe(name: String) {
        SwiftEventBus.unregister(self, name: name)
    }
    
    public func updateContext(context: [String: String], properties: [String:String]? = nil) -> Void {
        self.context = self.calculateContext(context: context, properties: properties)
        self.stop()
        self.start()
    }

    func calculateContext(context: [String: String], properties: [String:String]? = nil) -> Context {
        let specialKeys: Set = ["appName", "environment", "userId", "sessionId", "remoteAddress"]
        var newProperties: [String: String] = [:]

        context.forEach { (key, value) in
            if !specialKeys.contains(key) {
                newProperties[key] = value
            }
        }

        properties?.forEach { (key, value) in
            newProperties[key] = value
        }
        
        let newContext = Context(
            appName: self.context.appName,
            environment: self.context.environment,
            userId: context["userId"],
            sessionId: context["sessionId"],
            remoteAddress: context["remoteAddress"],
            properties: newProperties
        )

        return newContext
    }
}

@available(iOS 13, tvOS 13, *)
public class UnleashClient: UnleashClientBase, ObservableObject {
}

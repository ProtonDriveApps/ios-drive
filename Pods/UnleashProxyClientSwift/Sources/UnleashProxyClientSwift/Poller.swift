
import Foundation
import SwiftEventBus

public protocol PollerSession {
    func perform(_ request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
}

public enum PollerError: Error {
    case decoding
    case network
    case url
    case noResponse
    case unhandledStatusCode
}

public protocol StorageProvider {
    func set(value: Toggle?, key: String)
    func value(key: String) -> Toggle?
    func clear()
}

public class DictionaryStorageProvider: StorageProvider {
    private var storage: [String: Toggle] = [:]

    public init() {}

    public func set(value: Toggle?, key: String) {
        storage[key] = value
    }

    public func value(key: String) -> Toggle? {
        return storage[key]
    }
    
    public func clear() {
        storage = [:]
    }
}

public class Poller {
    var refreshInterval: Int?
    var unleashUrl: URL
    var timer: Timer?
    var ready: Bool
    var apiKey: String;
    var etag: String;
    
    private let session: PollerSession
    var storageProvider: StorageProvider

    public init(refreshInterval: Int? = nil, unleashUrl: URL, apiKey: String, session: PollerSession = URLSession.shared, storageProvider: StorageProvider = DictionaryStorageProvider()) {
        self.refreshInterval = refreshInterval
        self.unleashUrl = unleashUrl
        self.apiKey = apiKey
        self.timer = nil
        self.ready = false
        self.etag = ""
        self.session = session
        self.storageProvider = storageProvider
    }

    public func start(context: Context, completionHandler: ((PollerError?) -> Void)? = nil) -> Void {
        self.getFeatures(context: context, completionHandler: completionHandler)

        let timer = Timer.scheduledTimer(withTimeInterval: Double(self.refreshInterval ?? 15), repeats: true) { timer in
            self.getFeatures(context: context)
        }
        self.timer = timer
        RunLoop.current.add(timer, forMode: .default)
    }
    
    public func stop() -> Void {
        self.timer?.invalidate()
    }

    func formatURL(context: Context) -> URL? {
        var components = URLComponents(url: unleashUrl, resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = context.toURIMap().compactMap { key, value in
            if let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved),
               let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved) {
                return [encodedKey, encodedValue].joined(separator: "=")
            }
            return nil
        }.joined(separator: "&")

        return components?.url
    }
    
    private func createFeatureMap(features: FeatureResponse) {
        self.storageProvider.clear()
        features.toggles.forEach { toggle in
            self.storageProvider.set(value: toggle, key: toggle.name)
        }
    }
    
    public func getFeature(name: String) -> Toggle? {
        return self.storageProvider.value(key: name);
    }
    
    func getFeatures(context: Context, completionHandler: ((PollerError?) -> Void)? = nil) -> Void {
        guard let url = formatURL(context: context) else {
            completionHandler?(.url)
            Printer.printMessage("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.apiKey, forHTTPHeaderField: "Authorization")
        request.setValue(self.etag, forHTTPHeaderField: "If-None-Match")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        session.perform(request, completionHandler: { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse else {
                Printer.printMessage("No response")
                completionHandler?(.noResponse)
                return
            }

            if httpResponse.statusCode == 304 {
                completionHandler?(nil)
                Printer.printMessage("No changes in feature toggles.")
                return
            }
            
            if httpResponse.statusCode > 399 && httpResponse.statusCode < 599 {
                completionHandler?(.network)
                Printer.printMessage("Error fetching toggles")
                return
            }
            
            guard let data = data else {
                completionHandler?(nil)
                Printer.printMessage("No response data")
                return
            }

            guard httpResponse.statusCode == 200 else {
                Printer.printMessage("Unhandled status code")
                completionHandler?(.unhandledStatusCode)
                return
            }

            var result: FeatureResponse?
            
            if let etag = httpResponse.allHeaderFields["Etag"] as? String, !etag.isEmpty {
                self.etag = etag
            }
            
            do {
                result = try JSONDecoder().decode(FeatureResponse.self, from: data)
            } catch {
                Printer.printMessage(error.localizedDescription)
            }
            
            guard let json = result else {
                completionHandler?(.decoding)
                return
            }
            
            self.createFeatureMap(features: json)
            if (self.ready) {
                SwiftEventBus.post("update")
            } else {
                SwiftEventBus.post("ready")
                self.ready = true
            }
            
            completionHandler?(nil)
        })
    }
}

fileprivate extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

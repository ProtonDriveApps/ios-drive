// Copyright (c) 2026 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation

/// Shared, per-endpoint-family 429 gate. When any caller observes a 429,
/// it records the Retry-After (or a configurable default if the header is
/// absent / unparseable). Subsequent and concurrent callers in the same
/// family wait at `waitIfNeeded` until the window expires, instead of
/// racing against an active rate-limit.
public actor RateLimitGate: Sendable {
    public typealias Now = @Sendable () -> Date
    public typealias Sleep = @Sendable (Duration) async throws -> Void

    private let now: Now
    private let sleep: Sleep
    private let defaultRetryAfterSeconds: TimeInterval
    private let maxJitterFactor: Double
    private var blockedUntil: [String: Date] = [:]

    public init(
        defaultRetryAfterSeconds: TimeInterval = 30,
        maxJitterFactor: Double = 0.2,
        now: @escaping Now = { Date.now },
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.defaultRetryAfterSeconds = defaultRetryAfterSeconds
        self.maxJitterFactor = maxJitterFactor
        self.now = now
        self.sleep = sleep
    }

    /// Suspends the caller until the family's blocked-until time has passed.
    /// No-op when the family is not blocked.
    ///
    /// After a successful sleep we recurse to recheck the deadline:
    /// concurrent in-flight requests that also receive 429s call
    /// `recordRateLimited` independently and may extend the window while
    /// we are sleeping; without the recheck a waiter would wake up early
    /// and bypass the new, extended deadline. On cancellation we return
    /// without recursing — the caller's next await (e.g. URLSession in
    /// `Client.attemptRequest`) will observe the cancellation.
    public func waitIfNeeded(family: String) async {
        let nowDate = now()
        guard let until = blockedUntil[family], until > nowDate else { return }
        let delay = until.timeIntervalSince(nowDate)
        do {
            try await sleep(.seconds(delay))
        } catch {
            return
        }
        await waitIfNeeded(family: family)
    }

    /// Records that `family` was rate-limited.
    /// - Parameter retryAfter: the parsed Retry-After value. When `nil`, the gate's
    ///   configured `defaultRetryAfterSeconds` is used.
    /// Smaller incoming values do not shrink an existing window; larger ones extend it.
    public func recordRateLimited(retryAfter: TimeInterval?, family: String, source: String) {
        let base = max(0, retryAfter ?? defaultRetryAfterSeconds)
        let jittered = base + Self.jitter(base: base, maxFactor: maxJitterFactor)
        let candidate = now().addingTimeInterval(jittered)
        let existing = blockedUntil[family] ?? .distantPast
        let chosen = max(existing, candidate)
        blockedUntil[family] = chosen
        let retryAfterDescription = retryAfter.map { "\($0)" } ?? "nil → default \(defaultRetryAfterSeconds)"
        logInfo?("RateLimitGate: family=\(family) blocked for \(jittered)s (source: \(source), retryAfter: \(retryAfterDescription))")
    }

    /// Returns the current blocked-until date for `family`, or `nil` if not blocked.
    /// Exposed for tests and diagnostics.
    public func blockedUntilDate(family: String) -> Date? {
        blockedUntil[family]
    }

    /// Parses HTTP `Retry-After`: numeric seconds or HTTP-date. Returns `nil` for unparseable input.
    public static func parseRetryAfterValue(_ headerValue: String, now: Date = Date.now) -> TimeInterval? {
        if let seconds = Double(headerValue) { return max(0, seconds) }
        guard let date = parseHTTPDate(headerValue) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }

    private static let httpDateFormatters = [
        "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'",
        "EEE',' dd MMM yyyy HH':'mm':'ss'GMT'",
        "EEE','dd MMM yyyy HH':'mm':'ss 'GMT'",
        "EEE','dd MMM yyyy HH':'mm':'ss'GMT'",
        "EEE',' dd MMM yyyy HH':'mm':'ss ZZZZZ",
        "dd MMM yyyy HH':'mm':'ss 'GMT'",
        "dd MMM yyyy HH':'mm':'ss'GMT'",
        "dd MMM yyyy HH':'mm':'ss ZZZZZ",
        "EEEE',' dd-MMM-yy HH':'mm':'ss 'GMT'",
        "EEEE',' dd-MMM-yy HH':'mm':'ss ZZZZZ",
        "EEE MMM d HH':'mm':'ss yyyy",
    ].map {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = $0
        return formatter
    }

    private static func parseHTTPDate(_ value: String) -> Date? {
        for formatter in httpDateFormatters {
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func jitter(base: Double, maxFactor: Double) -> Double {
        let maxJitter = maxFactor * base
        guard maxJitter > 0 else { return 0 }
        return Double.random(in: 0...maxJitter)
    }
}

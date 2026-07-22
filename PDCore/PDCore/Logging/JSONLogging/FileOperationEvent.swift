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

public protocol FileOperationEventContext: Encodable {
    var dictionary: [String: AnyEncodable] { get }
}

extension FileOperationEventContext {
    public var dictionary: [String: AnyEncodable] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return dict.compactMapValues {
            if let e = $0 as? String {
                AnyEncodable(e)
            } else if let e = $0 as? Bool {
                AnyEncodable(e)
            } else if let e = $0 as? Int {
                AnyEncodable(e)
            } else if let e = $0 as? Double {
                AnyEncodable(e)
            } else {
                nil
            }
        }
    }
}

public enum FileOperationEvent: JSONLoggable {
    public enum State<
        Started: FileOperationEventContext,
        Succeeded: FileOperationEventContext,
        Failed: FileOperationEventContext
    >: Encodable {
        case started(Started)
        case succeeded(Succeeded)
        case failed(Failed)

        var logLevel: LogLevel {
            switch self {
            case .started: return .info
            case .succeeded: return .info
            case .failed: return .error
            }
        }

        var stateName: String {
            switch self {
            case .started: return "Start"
            case .succeeded: return "Success"
            case .failed: return "Error"
            }
        }

        var dictionary: [String: AnyEncodable] {
            let dict = switch self {
            case .started(let started): started.dictionary
            case .succeeded(let succeeded): succeeded.dictionary
            case .failed(let failed): failed.dictionary
            }

            return dict.merging(["state": AnyEncodable(stateName)]) { _, second in second }
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(dictionary)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(dictionary)
    }

    public struct FailureContext: FileOperationEventContext {
        public let id: String
        public let errorMessage: String
        public let errorContext: String?
        
        public init(id: String, errorMessage: String) {
            self.id = id
            self.errorMessage = errorMessage
            self.errorContext = nil
        }

        public init(id: String, error: Error?) {
            self.id = id
            self.errorMessage = error?.localizedDescription ?? "-"
            let errorContext = error?.logDescription ?? "-"
            self.errorContext = errorMessage != errorContext ? errorContext : nil
        }
    }

    public enum EventSource: Encodable {
        case system
        case fileViewer
        case executable(URL?)
        case unknown

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }

        public var description: String {
            switch self {
            case .system: "system"
            case .fileViewer: "fileViewer"
            case .executable(let url): "executable:\(url?.lastPathComponent ?? "n/a")"
            case .unknown: "unknown"
            }
        }
    }

    public struct FetchItemStartedContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let eventSource: EventSource

        public init(itemID: String, parentIDs: [String], eventSource: EventSource) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.eventSource = eventSource
        }
    }

    public struct FetchItemSucceededContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let isFolder: Bool

        public init(itemID: String, parentIDs: [String], isFolder: Bool) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.isFolder = isFolder
        }
    }

    public struct FetchContentsStartedContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let expectedVersion: String?

        public init(itemID: String, parentIDs: [String], expectedVersion: String?) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.expectedVersion = expectedVersion
        }
    }

    public struct FetchContentsSucceededContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let fetchedVersion: String?

        public init(itemID: String, parentIDs: [String], fetchedVersion: String) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.fetchedVersion = fetchedVersion
        }
    }

    public struct CreateItemStartedContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let isFolder: Bool
        public let hasContents: Bool
        public let eventSource: EventSource
        public let options: CreateItemOptions

        public init(itemID: String, parentIDs: [String], isFolder: Bool, hasContents: Bool, eventSource: EventSource, options: CreateItemOptions) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.isFolder = isFolder
            self.hasContents = hasContents
            self.eventSource = eventSource
            self.options = options
        }
    }

    public struct CreateItemOptions: OptionSet, Encodable {
        public let rawValue: UInt

        public static let mayAlreadyExist = CreateItemOptions(rawValue: 1 << 0)
        public static let deletionConflicted = CreateItemOptions(rawValue: 1 << 1)

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }

    public struct CreateItemSucceededContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let createdVersion: String

        public init(itemID: String, parentIDs: [String], createdVersion: String) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.createdVersion = createdVersion
        }
    }

    public struct ItemFields: OptionSet, Encodable {
        public let rawValue: UInt

        public static let contents = ItemFields(rawValue: 1 << 0)
        public static let filename = ItemFields(rawValue: 1 << 1)
        public static let parentItemIdentifier = ItemFields(rawValue: 1 << 2)
        public static let lastUsedDate = ItemFields(rawValue: 1 << 3)
        public static let tagData = ItemFields(rawValue: 1 << 4)
        public static let favoriteRank = ItemFields(rawValue: 1 << 5)
        public static let creationDate = ItemFields(rawValue: 1 << 6)
        public static let contentModificationDate = ItemFields(rawValue: 1 << 7)
        public static let fileSystemFlags = ItemFields(rawValue: 1 << 8)
        public static let extendedAttributes = ItemFields(rawValue: 1 << 9)
        public static let typeAndCreator = ItemFields(rawValue: 1 << 10)

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }

    public struct ModifyItemOptions: OptionSet, Encodable {
        public let rawValue: UInt

        public static let mayAlreadyExist = ModifyItemOptions(rawValue: 1 << 0)
        public static let failOnConflict = ModifyItemOptions(rawValue: 1 << 1)
        public static let isImmediateUploadRequestByPresentingApplication = ModifyItemOptions(rawValue: 1 << 2)

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }
    }

    public struct ModifyItemStartedContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let hasContents: Bool
        public let changedFields: ItemFields
        public let options: ModifyItemOptions
        public let eventSource: EventSource
        public let version: String

        public init(itemID: String, parentIDs: [String], eventSource: EventSource, hasContents: Bool, changedFields: ItemFields, options: ModifyItemOptions, version: String) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.eventSource = eventSource
            self.hasContents = hasContents
            self.changedFields = changedFields
            self.options = options
            self.version = version
        }
    }

    public struct ModifyItemSucceededContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let stillPendingFields: ItemFields
        public let version: String

        public init(itemID: String, parentIDs: [String], stillPendingFields: ItemFields, version: String) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.stillPendingFields = stillPendingFields
            self.version = version
        }
    }

    public struct DeleteItemStartedContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]
        public let isRecursive: Bool
        public let eventSource: EventSource
        public let version: String

        public init(itemID: String, parentIDs: [String], isRecursive: Bool, eventSource: EventSource, version: String) {
            self.itemID = itemID
            self.parentIDs = parentIDs
            self.isRecursive = isRecursive
            self.eventSource = eventSource
            self.version = version
        }
    }

    public struct DeleteItemSucceededContext: FileOperationEventContext {
        public let itemID: String
        public let parentIDs: [String]

        public init(itemID: String, parentIDs: [String]) {
            self.itemID = itemID
            self.parentIDs = parentIDs
        }
    }

    public struct EnumeratorStartedContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let eventSource: EventSource

        public init(containerType: ContainerType, eventSource: EventSource) {
            self.containerType = containerType
            self.eventSource = eventSource
        }
    }

    public struct EnumeratorFinishedContext: FileOperationEventContext {
        public let containerType: ContainerType

        public init(containerType: ContainerType) {
            self.containerType = containerType
        }
    }

    public struct EnumerateItemsStartedContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let pageNumber: Int

        public init(containerType: ContainerType, pageNumber: Int) {
            self.containerType = containerType
            self.pageNumber = pageNumber
        }
    }

    public enum ContainerType: Encodable {
        case workingSet
        case rootContainer
        case trashContainer
        case folder(String)

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }

        public var description: String {
            switch self {
            case .workingSet: return "workingSet"
            case .rootContainer: return "rootContainer"
            case .trashContainer: return "trashContainer"
            case .folder(let name): return "folder:\(name)"
            }
        }
    }

    public enum ItemEnumerationMode: Encodable {
        case api
        case db
    }

    public struct EnumerateItemsSucceededContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let itemEnumerationMode: ItemEnumerationMode
        public let enumeratedItemIDs: [String]
        public let hasMorePages: Bool

        public init(containerType: ContainerType, itemEnumerationMode: ItemEnumerationMode, enumeratedItemIDs: [String], hasMorePages: Bool) {
            self.containerType = containerType
            self.itemEnumerationMode = itemEnumerationMode
            self.enumeratedItemIDs = enumeratedItemIDs
            self.hasMorePages = hasMorePages
        }
    }

    public struct EnumerateChangesStartedContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let syncAnchor: String?

        public init(containerType: ContainerType, syncAnchor: String?) {
            self.containerType = containerType
            self.syncAnchor = syncAnchor
        }
    }

    public struct EnumerateChangesSucceededContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let updatedItemIDs: [String]
        public let deletedItemIDs: [String]
        public let newSyncAnchor: String?

        public init(containerType: ContainerType, updatedItemIDs: [String], deletedItemIDs: [String], newSyncAnchor: String?) {
            self.containerType = containerType
            self.updatedItemIDs = updatedItemIDs
            self.deletedItemIDs = deletedItemIDs
            self.newSyncAnchor = newSyncAnchor
        }
    }

    public struct EnumerationFailureContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let errorMessage: String
        public let errorContext: String?

        public init(containerType: ContainerType, errorMessage: String) {
            self.containerType = containerType
            self.errorMessage = errorMessage
            self.errorContext = nil
        }
        
        public init(containerType: ContainerType, error: Error?) {
            self.containerType = containerType
            self.errorMessage = error?.localizedDescription ?? "-"
            let errorContext = error?.logDescription ?? "-"
            self.errorContext = errorMessage != errorContext ? errorContext : nil
        }
    }

    public struct EventLoopPollStartedContext: FileOperationEventContext {
        public let loopType: EventLoopType
        public let volumeID: String?
        public let sinceEventID: String

        public init(loopType: EventLoopType, volumeID: String?, sinceEventID: String) {
            self.loopType = loopType
            self.volumeID = volumeID
            self.sinceEventID = sinceEventID
        }
    }

    public enum EventLoopType: String, Encodable {
        case drive
        case general
    }

    public struct EventLoopPollSucceededContext: FileOperationEventContext {
        public let loopType: EventLoopType
        public let volumeID: String?
        public let eventCount: Int
        public let latestEventID: String
        public let hasMorePages: Bool
        public let requiresCacheReset: Bool

        public init(loopType: EventLoopType, volumeID: String?, eventCount: Int, latestEventID: String, hasMorePages: Bool, requiresCacheReset: Bool) {
            self.loopType = loopType
            self.volumeID = volumeID
            self.eventCount = eventCount
            self.latestEventID = latestEventID
            self.hasMorePages = hasMorePages
            self.requiresCacheReset = requiresCacheReset
        }
    }

    public struct EventLoopProcessStartedContext: FileOperationEventContext {
        public let loopType: EventLoopType
        public let volumeID: String?

        public init(loopType: EventLoopType, volumeID: String?) {
            self.loopType = loopType
            self.volumeID = volumeID
        }
    }

    public struct EventLoopProcessSucceededContext: FileOperationEventContext {
        public let loopType: EventLoopType
        public let count: Int
        public let volumeID: String?

        public init(loopType: EventLoopType, count: Int, volumeID: String?) {
            self.loopType = loopType
            self.count = count
            self.volumeID = volumeID
        }
    }

    public struct EventProcessStartedContext: FileOperationEventContext {
        public let eventID: String
        public let eventType: EventProcessType
        public let nodeID: String
        public let volumeID: String
        public let shareID: String

        public init(eventID: String, eventType: EventProcessType, nodeID: String, volumeID: String, shareID: String) {
            self.eventID = eventID
            self.eventType = eventType
            self.nodeID = nodeID
            self.volumeID = volumeID
            self.shareID = shareID
        }
    }

    public enum EventProcessType: String, FileOperationEventContext {
        case create
        case delete
        case updateContent
        case updateMetadata

        init(eventType: GenericEventType) {
            switch eventType {
            case .create:
                self = .create
            case .delete:
                self = .delete
            case .updateContent:
                self = .updateContent
            case .updateMetadata:
                self = .updateMetadata
            }
        }
    }

    public struct EventProcessSucceededContext: FileOperationEventContext {
        public let eventID: String
        public let eventType: EventProcessType
        public let nodeID: String
        public let volumeID: String?
        public let shareID: String
        public let outcome: EventProcessOutcome

        public init(eventID: String, eventType: EventProcessType, nodeID: String, volumeID: String?, shareID: String, outcome: EventProcessOutcome) {
            self.eventID = eventID
            self.eventType = eventType
            self.nodeID = nodeID
            self.volumeID = volumeID
            self.shareID = shareID
            self.outcome = outcome
        }
    }

    public enum EventProcessOutcome: String, Encodable {
        case applied
        case ignored
        case disregarded
    }

    public struct SignalEnumeratorStartedContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let reason: SignalEnumeratorReason

        public init(containerType: ContainerType, reason: SignalEnumeratorReason) {
            self.containerType = containerType
            self.reason = reason
        }
    }

    public struct SignalEnumeratorSucceededContext: FileOperationEventContext {
        public let containerType: ContainerType
        public let reason: SignalEnumeratorReason

        public init(containerType: ContainerType, reason: SignalEnumeratorReason) {
            self.containerType = containerType
            self.reason = reason
        }
    }

    public enum SignalEnumeratorReason: String, Encodable {
        case eventsReceived
        case eventsApplied
        case fullResync
        case forceRefresh
        case draftsCleared
        case reenumerationRequired
        case postMigration
        case keepDownloadedStateChanged
        case keepDownloadedStateUpdatedBasedOnParent
        case keepDownloadedStateProcessItems
        case removeDownloadedStateChanged
        case domainReconnected
        case tests
    }

    public struct ExtensionInitStartedContext: FileOperationEventContext {
        public let domainIdentifier: String
        public let backingStoreIdentifier: String

        public init(domainIdentifier: String, backingStoreIdentifier: String) {
            self.domainIdentifier = domainIdentifier
            self.backingStoreIdentifier = backingStoreIdentifier
        }
    }

    public struct ExtensionInitSucceededContext: FileOperationEventContext {
        public let domainIdentifier: String

        public init(domainIdentifier: String) {
            self.domainIdentifier = domainIdentifier
        }
    }

    public struct ExtensionInvalidateStartedContext: FileOperationEventContext {
        public let domainIdentifier: String

        public init(domainIdentifier: String) {
            self.domainIdentifier = domainIdentifier
        }
    }

    public struct ExtensionInvalidateSucceededContext: FileOperationEventContext {
        public let domainIdentifier: String

        public init(domainIdentifier: String) {
            self.domainIdentifier = domainIdentifier
        }
    }

    public struct DomainConnectionChangeStartedContext: FileOperationEventContext {
        public let domainIdentifier: String
        public let isConnected: Bool
        public let reason: DomainConnectionReason

        public init(domainIdentifier: String, isConnected: Bool, reason: DomainConnectionReason) {
            self.domainIdentifier = domainIdentifier
            self.isConnected = isConnected
            self.reason = reason
        }
    }

    public struct DomainConnectionChangeEndedContext: FileOperationEventContext {
        public let domainIdentifier: String
        public let isConnected: Bool
        public let reason: DomainConnectionReason

        public init(domainIdentifier: String, isConnected: Bool, reason: DomainConnectionReason) {
            self.domainIdentifier = domainIdentifier
            self.isConnected = isConnected
            self.reason = reason
        }
    }

    public enum DomainConnectionReason: String, Encodable {
        case appStartedRunning
        case appStoppedRunning
        case signedOut
    }

    // MARK: - Event Cases

    case fetchItem(State<FetchItemStartedContext, FetchItemSucceededContext, FailureContext>)
    case fetchContents(State<FetchContentsStartedContext, FetchContentsSucceededContext, FailureContext>)
    case createItem(State<CreateItemStartedContext, CreateItemSucceededContext, FailureContext>)
    case modifyItem(State<ModifyItemStartedContext, ModifyItemSucceededContext, FailureContext>)
    case deleteItem(State<DeleteItemStartedContext, DeleteItemSucceededContext, FailureContext>)

    case enumerator(State<EnumeratorStartedContext, EnumeratorFinishedContext, EnumerationFailureContext>)
    case enumerateItems(State<EnumerateItemsStartedContext, EnumerateItemsSucceededContext, EnumerationFailureContext>)
    case enumerateChanges(State<EnumerateChangesStartedContext, EnumerateChangesSucceededContext, EnumerationFailureContext>)

    case eventLoopProcess(State<EventLoopProcessStartedContext, EventLoopProcessSucceededContext, FailureContext>)
    case eventProcess(State<EventProcessStartedContext, EventProcessSucceededContext, FailureContext>)

    case signalEnumerator(State<SignalEnumeratorStartedContext, SignalEnumeratorSucceededContext, FailureContext>)

    case extensionInit(State<ExtensionInitStartedContext, ExtensionInitSucceededContext, FailureContext>)
    case extensionInvalidate(State<ExtensionInvalidateStartedContext, ExtensionInvalidateSucceededContext, FailureContext>)
    case domainConnectionChanged(State<DomainConnectionChangeStartedContext, DomainConnectionChangeEndedContext, FailureContext>)

    public var eventName: String {
        let prefix = switch self {
        case .fetchItem: "fetchItem"
        case .fetchContents: "fetchContents"
        case .createItem: "createItem"
        case .modifyItem: "modifyItem"
        case .deleteItem: "deleteItem"
        case .enumerator: "enumerator"
        case .enumerateItems: "enumerateItems"
        case .enumerateChanges: "enumerateChanges"
        case .eventLoopProcess: "eventLoopProcess"
        case .eventProcess: "eventProcess"
        case .signalEnumerator: "signalEnumerator"
        case .extensionInit: "extensionInit"
        case .extensionInvalidate: "extensionInvalidate"
        case .domainConnectionChanged: "domainConnectionChanged"
        }
        switch self {
        case .fetchItem(.failed(let failedState)),
             .fetchContents(.failed(let failedState)),
             .createItem(.failed(let failedState)),
             .modifyItem(.failed(let failedState)),
             .deleteItem(.failed(let failedState)),
             .eventLoopProcess(.failed(let failedState)),
             .eventProcess(.failed(let failedState)),
             .signalEnumerator(.failed(let failedState)),
             .extensionInit(.failed(let failedState)),
             .extensionInvalidate(.failed(let failedState)),
             .domainConnectionChanged(.failed(let failedState)):
            return "\(prefix) failed — \(failedState.errorMessage)"
        case .enumerator(.failed(let failedState)),
             .enumerateItems(.failed(let failedState)),
             .enumerateChanges(.failed(let failedState)):
            return "\(prefix) failed — \(failedState.errorMessage)"
        default:
            return prefix
        }
    }

    public var domain: LogDomain {
        switch self {
        case .fetchItem: return .syncing
        case .fetchContents: return .syncing
        case .createItem: return .syncing
        case .modifyItem: return .syncing
        case .deleteItem: return .syncing
        case .enumerator: return .enumerating
        case .enumerateItems: return .enumerating
        case .enumerateChanges: return .enumerating
        case .eventLoopProcess: return .events
        case .eventProcess: return .events
        case .signalEnumerator: return .enumerating
        case .extensionInit: return .fileProvider
        case .extensionInvalidate: return .fileProvider
        case .domainConnectionChanged: return .fileProvider
        }
    }

    public var logLevel: LogLevel {
        switch self {
        case .fetchItem(let state): return state.logLevel
        case .fetchContents(let state): return state.logLevel
        case .createItem(let state): return state.logLevel
        case .modifyItem(let state): return state.logLevel
        case .deleteItem(let state): return state.logLevel
        case .enumerator(let state): return state.logLevel
        case .enumerateItems(let state): return state.logLevel
        case .enumerateChanges(let state): return state.logLevel
        case .eventLoopProcess(let state): return state.logLevel
        case .eventProcess(let state): return state.logLevel
        case .signalEnumerator(let state): return state.logLevel
        case .extensionInit(let state): return state.logLevel
        case .extensionInvalidate(let state): return state.logLevel
        case .domainConnectionChanged: return .info
        }
    }

    public var dictionary: [String: AnyEncodable] {
        switch self {
        case .fetchItem(let state): return state.dictionary
        case .fetchContents(let state): return state.dictionary
        case .createItem(let state): return state.dictionary
        case .modifyItem(let state): return state.dictionary
        case .deleteItem(let state): return state.dictionary
        case .enumerator(let state): return state.dictionary
        case .enumerateItems(let state): return state.dictionary
        case .enumerateChanges(let state): return state.dictionary
        case .eventLoopProcess(let state): return state.dictionary
        case .eventProcess(let state): return state.dictionary
        case .signalEnumerator(let state): return state.dictionary
        case .extensionInit(let state): return state.dictionary
        case .extensionInvalidate(let state): return state.dictionary
        case .domainConnectionChanged(let context): return context.dictionary
        }
    }
}

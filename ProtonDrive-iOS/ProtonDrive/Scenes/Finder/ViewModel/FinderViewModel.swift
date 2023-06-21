// Copyright (c) 2023 Proton AG
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

import SwiftUI
import UIKit
import Combine
import PDCore
import PDUIComponents
import ProtonCore_Networking

typealias ListState = TrashViewModel.ListState
typealias ObservableFinderViewModel = FinderViewModel & ObservableObject

protocol NodeEditionViewModel {
    func setFavorite(_ favorite: Bool, nodes: [Node])
    func markOfflineAvailable(_ mark: Bool, nodes: [Node])
    func sendToTrash(_ currentNodes: [Node], completion: @escaping (Result<Void, Error>) -> Void)
    func sendError(_ error: Error)
}

struct NodeWrapper: Identifiable, Equatable {
    let id: String
    let node: Node

    init(_ node: Node) {
        self.id = node.id
        self.node = node
    }
}

protocol FinderViewModel: NodeEditionViewModel, FlatNavigationBarDelegate {
    associatedtype Model: FinderModel, NodesListing, ThumbnailLoader
    typealias ApplyActionCompletion = () -> Void
    var model: Model { get }
    
    var sorting: SortPreference { get }
    var supportsSortingSwitch: Bool { get }
    var permanentChildrenSectionTitle: String { get }
    func subscribeToSort()

    var layout: Layout { get }
    var supportsLayoutSwitch: Bool { get }
    func changeLayout()
    
    var childrenCancellable: AnyCancellable? { get set }
    var transientChildren: [NodeWrapper] { get set }
    var permanentChildren: [NodeWrapper] { get set }
    
    var isVisible: Bool { get set }
    var genericErrors: ErrorRegulator { get }
    
    var nodeName: String { get }
    var isUpdating: Bool { get set }
    var trailingNavBarItems: [NavigationBarButton] { get }
    var leadingNavBarItems: [NavigationBarButton] { get }
    var lastUpdated: Date { get }

    func refreshOnAppear()
    func didScrollToBottom()
    
    func selected(file: File)
    func childViewModel(for node: Node) -> NodeCellConfiguration
    func applyAction(completion: @escaping ApplyActionCompletion)
    
    var isUploadDisclaimerVisible: Bool { get }
    func closeUploadDisclaimer()
}

extension FinderViewModel {
    var node: Folder? {
        self.model.folder
    }
    
    func subscribeToChildren() {
        self.childrenCancellable?.cancel()
        self.childrenCancellable = self.model.children()
            .filter { [weak self] _, _ in
                // reordering is heavy operation, so we do not want to perform it on all the folders at once when the app-wide setting is changed
                // instead we will call refreshOnAppear() when the view is back visible
                self?.isVisible == true
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .sink { [weak self] activeSorted, uploading in
                guard let self = self, self.isVisible else { return }
                self.permanentChildren = activeSorted.map(NodeWrapper.init)
                self.transientChildren = uploading.map(NodeWrapper.init)
            }
    }
    
    func switchSorting(_ newValue: SortPreference) {
        self.model.switchSorting(newValue)
    }
    
    private var noChildren: Bool {
        permanentChildren.isEmpty && transientChildren.isEmpty
    }
    
    private var provedChildrenCount: Bool {
        lastUpdated > .distantPast && !isUpdating
    }
    
    var provedEmpty: Bool {
        noChildren && provedChildrenCount
    }
    
    var needsNoConnectionBackground: Bool {
        guard model is NodesFetching, isVisible else {
            return false
        }
        
        return noChildren && !provedChildrenCount
    }
    
    var emptyBackgroundConfig: EmptyViewConfiguration? {
        guard provedEmpty else { return nil }
        
        switch self.model {
        case is NodesFetching: return .folder
        case is SharedModel: return .shared
        case is OfflineAvailableModel: return .offlineAvailable
        default: return nil
        }
    }

    var isUploadDisclaimerVisible: Bool { false }

    func closeUploadDisclaimer() {}
}

extension FinderViewModel {
    
    func numberOfControllers(_ count: Int, _ root: RootViewModel) {
        root.isAccessible = count == 1
    }

}

extension FinderViewModel where Self: HasMultipleSelection {

    func actionBarAction(_ tapped: ActionBarButtonViewModel?, sheet: Binding<FinderCoordinator.Destination?>, menuItem: Binding<FinderMenu?>) {
        let nodes = self.permanentChildren.filter { self.selection.selected.contains($0.id) }
        
        switch tapped {
        case .trashMultiple:
            let vm = NodeRowActionMultipleMenuViewModel(nodes: nodes.map(\.node), model: self)
            menuItem.wrappedValue = .trash(vm: vm, isNavigationMenu: false)
            
        case .moveMultiple where !nodes.isEmpty:
            sheet.wrappedValue = .move(nodes.map(\.node), parent: self.node ?? nodes.map(\.node).first!.parentLink)
            
        case .offlineAvailableMultiple:
            self.markOfflineAvailable(!nodes.map(\.node).allSatisfy(\.isMarkedOfflineAvailable), nodes: nodes.map(\.node))
            
        default: break
        }
    }
}

extension FinderViewModel where Self: UploadingViewModel, Self: DownloadingViewModel, Self: HasMultipleSelection {
    func childViewModel(for node: Node) -> NodeCellConfiguration {
        NodeCellWithProgressConfiguration(
            from: node,
            // selection should not be available for uploading files
            selectionModel: node.state?.existsOnCloud == true ? self.prepareSelectionModel() : nil,
            // progresses come from Uploader a little later that nodes from db
            progressesAvailable: getNormalizedUploadProgresses() != nil,
            progressTracker: makeFileProgressTracker(for: node),
            downloadProgresses: self.downloadProgresses,
            thumbnailLoader: self.model,
            nodeStatePolicy: nodeStatePolicy
        )
    }

    func makeFileProgressTracker(for node: Node) -> ProgressTracker? {
        let uploadProgresses = getNormalizedUploadProgresses()
        if let file = node as? File {
            if let uploadID = file.uploadID,
               let uploadProgress = uploadProgresses?[uploadID],
               file.activeRevisionDraft != nil {
                return ProgressTracker(progress: uploadProgress, direction: .upstream)
            } else {
                return downloadProgresses.first { $0.matches(file.id) }
            }
        }
        return nil
    }

    func getNormalizedUploadProgresses() -> UploadProgresses? {
        uploadsCount > 0 ? uploadProgresses : nil
    }

    func isUploadFailed(node: Node) -> Bool {
        let progressTracker = makeFileProgressTracker(for: node)
        let areProgressesAvailable = getNormalizedUploadProgresses() != nil
        return nodeStatePolicy.isUploadFailed(for: node, progressTracker: progressTracker, areProgressesAvailable: areProgressesAvailable)
    }
}

extension FinderViewModel where Self: DownloadingViewModel, Self: HasMultipleSelection {
    func childViewModel(for node: Node) -> NodeCellConfiguration {
        NodeCellWithProgressConfiguration(
            from: node,
            selectionModel: self.prepareSelectionModel(),
            downloadProgresses: self.downloadProgresses,
            thumbnailLoader: self.model,
            nodeStatePolicy: DisabledNodeStatePolicy()
        )
    }
}

extension FinderViewModel where Self: UploadingViewModel, Self.Model: UploadsListing {
    
    func subscribeToChildrenUploading() {
        self.childrenUploadCancellable?.cancel()
        self.childrenUploadCancellable = self.model.childrenUploading()
        .catch {  [weak self] error -> Empty<([File], [FileUploader.OperationID: FileUploader.CurrentProgress]), Error> in
            switch error {
            case UploaderErrors.canceled:
                break // not all errors should be propagated to UI

            case let error where error is CloudSlot.Errors:
                self?.genericErrors.send(error)

            case let error where error is ValidationError<String>:
                self?.genericErrors.send(error)

            case let error as NSError where FinderError(error) == .noSpaceOnCloud:
                self?.genericErrors.send(error)
                fallthrough

            default:
                self?.uploadErrors.send(error)
            }

            return .init()
        }
        .sink(receiveCompletion: { [weak self] _ in
            self?.subscribeToChildrenUploading()
        }, receiveValue: { [weak self] files, progress in
            self?.uploadsCount = files.count
            self?.uploadProgresses = progress
        })
    }
}

extension FinderViewModel where Self: DownloadingViewModel, Self.Model: DownloadsListing {
    func subscribeToChildrenDownloading() {
        self.childrenDownloadCancellable?.cancel()
        self.childrenDownloadCancellable = self.model.childrenDownloading()
        .receive(on: DispatchQueue.main)
        .catch { [weak self] error -> Empty<[ProgressTracker], Error> in
            let error: Error = (error as? ResponseError)?.underlyingError ?? error
            self?.genericErrors.send(error)
            return .init()
        }
        .sink(receiveCompletion: { [weak self] _ in
            self?.subscribeToChildrenDownloading()
        }, receiveValue: { [weak self] progresses in
            self?.downloadProgresses = progresses
        })
    }
    
    func selected(file: File) {
        self.model.download(node: file)
    }
}

extension FinderViewModel where Self.Model: NodesListing {

    func download(node: Node) {
        guard let file = node as? File,
              file.activeRevisionDraft == nil else { return }

        guard node.state != .uploading else {
            ConsoleLogger.shared?.log(DriveError(DriveFinderUpload(), "FinderViewModel"))
            return
        }

        (self.model as? DownloadsListing)?.download(node: node)
    }
    
    func setFavorite(_ favorite: Bool, nodes: [Node]) {
        model.tower.setFavourite(favorite, nodes: nodes) { _ in }
    }
    
    func markOfflineAvailable(_ mark: Bool, nodes: [Node]) {
        model.tower.markOfflineAvailable(mark, nodes: nodes) { _ in }
    }

    func sendToTrash(_ currentNodes: [Node], completion: @escaping (Result<Void, Error>) -> Void) {
        model.tower.trash(nodes: currentNodes, completion: completion)
    }

    func sendError(_ error: Error) {
        let error: Error = (error as? ResponseError)?.underlyingError ?? error
        genericErrors.send(error)
    }
}

struct DriveFinderUpload: Error {
    
    var localizedDescription: String {
        "Uploading file with no activeRevisionDraft"
    }
}

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

import Combine
import PDCore
import SwiftUI
import UIKit

final class PhotosCollectionViewController: UIViewController {
    private typealias SectionID = String              // PhotosGridViewSection.id (month title)
    private typealias ItemID = AnyVolumeIdentifier     // PhotoGridViewItem.id

    private let viewModel: PhotosGridViewModel
    private let item: (PhotoGridViewItem, String) -> AnyView
    private let onScrolledChanged: ((Bool) -> Void)?
    private let zoomController: PhotosGridZoomController
    private let paginationMargin = 10

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<SectionID, ItemID>!
    private var itemsByID: [ItemID: PhotoGridViewItem] = [:]
    private let refreshControl = UIRefreshControl()
    private var cancellables = Set<AnyCancellable>()
    private var didReportShown = false
    private var isScrolled = false

    private let minItemWidth: CGFloat = PhotosGridLayoutFactory.minItemWidth
    private var appliedColumns: Int?
    private var baseItemWidthAtPinchStart = PhotosGridLayoutFactory.defaultItemWidth

    private var zoomAnchor: ZoomAnchor?
    private let snapshotDissolveDuration: TimeInterval = 0.25

    private var isDragSelecting = false
    private var lastDragViewLocation: CGPoint = .zero
    private var autoScrollDirection: CGFloat = 0
    private var autoScrollLink: CADisplayLink?
    private let autoScrollEdgeInset: CGFloat = 80
    private let autoScrollStep: CGFloat = 12

    init(
        viewModel: PhotosGridViewModel,
        item: @escaping (PhotoGridViewItem, String) -> AnyView,
        zoomController: PhotosGridZoomController,
        onScrolledChanged: ((Bool) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.item = item
        self.zoomController = zoomController
        self.onScrolledChanged = onScrolledChanged
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureCollectionView()
        configureDataSource()
        bind()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.onAppear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        publishZoomLimits()
    }

    // MARK: - Setup

    private func configureCollectionView() {
        appliedColumns = zoomController.columns
        let initialLayout = appliedColumns.map { PhotosGridLayoutFactory.make(columns: $0) }
            ?? PhotosGridLayoutFactory.make()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: initialLayout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        collectionView.addGestureRecognizer(pinch)

        let dragSelect = UILongPressGestureRecognizer(target: self, action: #selector(handleDragSelect))
        dragSelect.minimumPressDuration = 0.35
        collectionView.addGestureRecognizer(dragSelect)

        let selectionDrag = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelect))
        selectionDrag.delegate = self
        collectionView.addGestureRecognizer(selectionDrag)

        refreshControl.addAction(UIAction { [weak self] _ in
            self?.viewModel.refresh()
        }, for: .valueChanged)
        collectionView.refreshControl = refreshControl

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, ItemID> { [weak self] cell, indexPath, id in
            guard let self, let gridItem = self.itemsByID[id] else { return }
            let makeContent = self.item
            let accessibilityIndex = self.accessibilityIndex(for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration { makeContent(gridItem, accessibilityIndex) }
                .margins(.all, 0) // tight photo grid, no cell insets
        }

        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            let title = self?.dataSource.sectionIdentifier(for: indexPath.section) ?? ""
            header.contentConfiguration = UIHostingConfiguration { PhotosSectionHeader(title: title) }
                .margins(.all, 0)
        }

        let footerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewCell>(
            elementKind: PhotosGridLayoutFactory.footerElementKind
        ) { [weak self] footer, _, _ in
            guard let self else { return }
            // The footer hosts a SwiftUI view observing the view model, so it updates
            // itself on paginationStatus changes without any UIKit-side reconfigure.
            let viewModel = self.viewModel
            footer.contentConfiguration = UIHostingConfiguration { PhotosGridFooter(viewModel: viewModel) }
                .margins(.all, 0)
        }

        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: id)
        }
        dataSource.supplementaryViewProvider = { [weak self] _, kind, indexPath in
            guard let self else { return nil }
            switch kind {
            case PhotosGridLayoutFactory.footerElementKind:
                return self.collectionView.dequeueConfiguredReusableSupplementary(using: footerRegistration, for: indexPath)
            default:
                return self.collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
            }
        }
    }

    private func accessibilityIndex(for indexPath: IndexPath) -> String {
        let sectionTitle = dataSource.sectionIdentifier(for: indexPath.section) ?? ""
        return "\(sectionTitle)_\(indexPath.item)"
    }

    private func bind() {
        viewModel.sectionsUpdatePublisher
            .sink { [weak self] sections in self?.apply(sections) }
            .store(in: &cancellables)

        viewModel.scrollToItem
            .sink { [weak self] id in self?.scrollTo(id) }
            .store(in: &cancellables)

        viewModel.isRefreshingPublisher
            .sink { [weak self] isRefreshing in
                if !isRefreshing { self?.refreshControl.endRefreshing() }
            }
            .store(in: &cancellables)

        zoomController.commands
            .sink { [weak self] command in self?.stepZoom(command) }
            .store(in: &cancellables)
    }

    // MARK: - Snapshots

    private func apply(_ sections: [PhotosGridViewSection]) {
        let previous = itemsByID
        var lookup: [ItemID: PhotoGridViewItem] = [:]
        var snapshot = NSDiffableDataSourceSnapshot<SectionID, ItemID>()
        for section in sections {
            snapshot.appendSections([section.title])
            let ids = section.items.map { gridItem -> ItemID in
                lookup[gridItem.id] = gridItem
                return gridItem.id
            }
            snapshot.appendItems(ids, toSection: section.title)
        }
        itemsByID = lookup

        let isInitial = dataSource.snapshot().numberOfItems == 0
        dataSource.apply(snapshot, animatingDifferences: !isInitial)

        // Metadata-only changes (badges, offline/favourite state) -> reconfigure just those cells.
        let changed = lookup.compactMap { id, value -> ItemID? in
            guard let old = previous[id], old != value else { return nil }
            return id
        }
        if !changed.isEmpty {
            var reconfigured = dataSource.snapshot()
            reconfigured.reconfigureItems(changed)
            dataSource.apply(reconfigured, animatingDifferences: false)
        }

        if !didReportShown, snapshot.numberOfItems > 0 {
            didReportShown = true
            viewModel.reportListIsShown()
        }
    }

    private func scrollTo(_ id: ItemID) {
        guard let indexPath = dataSource.indexPath(for: id) else { return }
        collectionView.scrollToItem(at: indexPath, at: .top, animated: false)
    }

    /// Bottom inset so the floating action bar / banners don't cover the last row.
    func setBottomInset(_ inset: CGFloat) {
        guard collectionView.contentInset.bottom != inset else { return }
        collectionView.contentInset.bottom = inset
        collectionView.verticalScrollIndicatorInsets.bottom = inset
    }

    /// Hidden while the custom scrubber is in use (mirrors PhotosGridView).
    func setShowsScrollIndicator(_ shows: Bool) {
        collectionView.showsVerticalScrollIndicator = shows
    }

    // MARK: - Zoom

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            baseItemWidthAtPinchStart = itemWidth(forColumns: currentColumns)
            zoomAnchor = makeZoomAnchor(atViewPoint: recognizer.location(in: view))
        case .changed:
            let width = collectionView.bounds.width
            guard width > 0 else { return }
            // Spread (scale > 1) -> larger cells -> fewer columns -> zoom IN.
            let target = min(max(baseItemWidthAtPinchStart * recognizer.scale, minItemWidth), width)
            // Only rebuild the layout when the target actually crosses a column-count
            // boundary — between boundaries the layout is identical.
            let currentColumns = currentColumns
            let targetColumns = PhotosGridLayoutFactory.numberOfColumns(
                width: width,
                preferableItemWidth: target,
                minimumColumns: PhotosGridLayoutFactory.minimumNumberOfColumns
            )
            guard targetColumns != currentColumns else { return }
            applyLayout(columns: targetColumns)
        case .ended, .cancelled, .failed:
            zoomAnchor = nil
        default:
            break
        }
    }

    private func stepZoom(_ command: PhotosGridZoomController.Command) {
        let step = command == .zoomIn ? -1 : 1
        let targetColumns = currentColumns + step
        guard targetColumns >= PhotosGridLayoutFactory.minimumNumberOfColumns, targetColumns <= maxColumns else { return }
        applyLayout(columns: targetColumns)
    }

    private var currentColumns: Int {
        appliedColumns ?? PhotosGridLayoutFactory.numberOfColumns(
            width: collectionView.bounds.width,
            preferableItemWidth: PhotosGridLayoutFactory.defaultItemWidth
        )
    }

    private var maxColumns: Int {
        PhotosGridLayoutFactory.numberOfColumns(
            width: collectionView.bounds.width,
            preferableItemWidth: minItemWidth,
            minimumColumns: PhotosGridLayoutFactory.minimumNumberOfColumns
        )
    }

    private func itemWidth(forColumns columns: Int) -> CGFloat {
        let columns = max(columns, PhotosGridLayoutFactory.minimumNumberOfColumns)
        let width = collectionView.bounds.width
        return (width - PhotosGridLayoutFactory.spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func publishZoomLimits() {
        guard collectionView.bounds.width > 0 else { return }
        let columns = currentColumns
        let canZoomIn = columns > PhotosGridLayoutFactory.minimumNumberOfColumns
        let canZoomOut = columns < maxColumns
        DispatchQueue.main.async { [weak self] in
            self?.zoomController.setLimits(canZoomIn: canZoomIn, canZoomOut: canZoomOut)
        }
    }

    private struct ZoomAnchor {
        let id: ItemID
        let unitOffset: CGPoint
        let viewportOffsetY: CGFloat
    }

    private func makeZoomAnchor(atViewPoint viewPoint: CGPoint) -> ZoomAnchor? {
        let contentPoint = view.convert(viewPoint, to: collectionView)
        guard let indexPath = indexPathForItem(nearestTo: contentPoint),
              let id = dataSource.itemIdentifier(for: indexPath),
              let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame,
              frame.width > 0, frame.height > 0
        else { return nil }

        let unitOffset = CGPoint(
            x: min(max((contentPoint.x - frame.minX) / frame.width, 0), 1),
            y: min(max((contentPoint.y - frame.minY) / frame.height, 0), 1)
        )
        return ZoomAnchor(
            id: id,
            unitOffset: unitOffset,
            viewportOffsetY: contentPoint.y - collectionView.contentOffset.y
        )
    }

    private func indexPathForItem(nearestTo contentPoint: CGPoint) -> IndexPath? {
        if let indexPath = collectionView.indexPathForItem(at: contentPoint) {
            return indexPath
        }
        return collectionView.indexPathsForVisibleItems
            .compactMap { indexPath -> (indexPath: IndexPath, distance: CGFloat)? in
                guard let frame = collectionView.collectionViewLayout
                    .layoutAttributesForItem(at: indexPath)?.frame else { return nil }
                let dx = frame.midX - contentPoint.x
                let dy = frame.midY - contentPoint.y
                return (indexPath, dx * dx + dy * dy)
            }
            .min { $0.distance < $1.distance }?
            .indexPath
    }

    private func restoreZoomAnchor(_ anchor: ZoomAnchor) {
        guard let indexPath = dataSource.indexPath(for: anchor.id),
              let frame = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)?.frame
        else { return }

        let anchorContentY = frame.minY + anchor.unitOffset.y * frame.height
        let minOffset = -collectionView.adjustedContentInset.top
        let maxOffset = max(minOffset,
                            collectionView.contentSize.height
                                - collectionView.bounds.height
                                + collectionView.adjustedContentInset.bottom)
        let targetY = min(max(anchorContentY - anchor.viewportOffsetY, minOffset), maxOffset)
        collectionView.setContentOffset(
            CGPoint(x: collectionView.contentOffset.x, y: targetY),
            animated: false
        )
    }

    private func applyLayout(columns: Int) {
        appliedColumns = columns
        zoomController.setColumns(columns) // outlives this controller, so zoom survives tag switches
        publishZoomLimits()
        
        // Anchor is either below fingers, or center of the screen (when using buttons)
        let anchor = zoomAnchor ?? makeZoomAnchor(
            atViewPoint: CGPoint(x: collectionView.frame.midX, y: collectionView.frame.midY)
        )
        let layout = PhotosGridLayoutFactory.make(columns: columns)

        // Add overlay to cross dissolve
        let overlay = collectionView.snapshotView(afterScreenUpdates: false)
        if let overlay {
            collectionView.alpha = 0.5
            overlay.frame = collectionView.frame
            overlay.isUserInteractionEnabled = false
            view.addSubview(overlay)
        }

        UIView.performWithoutAnimation {
            self.collectionView.setCollectionViewLayout(layout, animated: false)
            if let anchor {
                self.restoreZoomAnchor(anchor)
            }
            self.collectionView.layoutIfNeeded()
        }

        guard let overlay else {
            return
        }
        
        UIView.animate(
            withDuration: snapshotDissolveDuration,
            delay: 0,
            options: [.allowUserInteraction],
            animations: {
                overlay.alpha = 0
                self.collectionView.alpha = 1
            },
            completion: { _ in
                overlay.removeFromSuperview()
            }
        )
    }

    // MARK: - Drag select

    @objc private func handleDragSelect(_ recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard !isDragSelecting else { return } // the other recognizer already owns it
            lastDragViewLocation = recognizer.location(in: view)
            guard let id = itemID(atViewPoint: lastDragViewLocation) else { return }
            isDragSelecting = true
            collectionView.isScrollEnabled = false // freeze the scroll; we auto-scroll manually
            viewModel.beginDragSelection(at: id)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .changed:
            guard isDragSelecting else { return }
            lastDragViewLocation = recognizer.location(in: view)
            if let id = itemID(atViewPoint: lastDragViewLocation) {
                viewModel.updateDragSelection(to: id)
            }
            updateAutoScroll(for: lastDragViewLocation)
        case .ended, .cancelled, .failed:
            endDragSelect()
        default:
            break
        }
    }

    private func endDragSelect() {
        guard isDragSelecting else { return }
        isDragSelecting = false
        stopAutoScroll()
        collectionView.isScrollEnabled = true
        viewModel.endDragSelection()
    }

    private func itemID(atViewPoint viewPoint: CGPoint) -> ItemID? {
        // Convert to the collection view's content space (accounts for contentOffset).
        let contentPoint = view.convert(viewPoint, to: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: contentPoint) else { return nil }
        return dataSource.itemIdentifier(for: indexPath)
    }

    // MARK: Auto-scroll during drag select

    private func updateAutoScroll(for viewPoint: CGPoint) {
        let frame = collectionView.frame
        if viewPoint.y < frame.minY + autoScrollEdgeInset {
            autoScrollDirection = -1
            startAutoScroll()
        } else if viewPoint.y > frame.maxY - autoScrollEdgeInset {
            autoScrollDirection = 1
            startAutoScroll()
        } else {
            stopAutoScroll()
        }
    }

    private func startAutoScroll() {
        guard autoScrollLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
        link.add(to: .main, forMode: .common)
        autoScrollLink = link
    }

    private func stopAutoScroll() {
        autoScrollLink?.invalidate()
        autoScrollLink = nil
        autoScrollDirection = 0
    }

    @objc private func autoScrollTick() {
        let minOffset = -collectionView.adjustedContentInset.top
        let maxOffset = max(minOffset,
                            collectionView.contentSize.height
                                - collectionView.bounds.height
                                + collectionView.adjustedContentInset.bottom)
        let proposed = collectionView.contentOffset.y + autoScrollStep * autoScrollDirection
        let target = min(max(proposed, minOffset), maxOffset)
        guard target != collectionView.contentOffset.y else {
            stopAutoScroll()
            return
        }
        collectionView.contentOffset.y = target
        // Extend the range to whatever is now under the (stationary) finger.
        if let id = itemID(atViewPoint: lastDragViewLocation) {
            viewModel.updateDragSelection(to: id)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        endDragSelect()
    }
}

// MARK: - Scrolling & pagination

extension PhotosCollectionViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        viewModel.setUpdatedScrollOffset()

        // Report scrolled-away-from-top so the wrapper can hide banners (mirrors
        // PhotosGridView's `isScrolled`).
        let scrolled = scrollView.contentOffset.y > -scrollView.adjustedContentInset.top
        if scrolled != isScrolled {
            isScrolled = scrolled
            onScrolledChanged?(scrolled)
        }

        // Top-most visible item -> drives the scrubber date capsule. Replaces the
        // PhotosGridTopItemResolver + offset-preference machinery from PhotosGridView.
        guard
            let indexPath = collectionView.indexPathsForVisibleItems.min(),
            let id = dataSource.itemIdentifier(for: indexPath),
            let gridItem = itemsByID[id]
        else { return }
        viewModel.updateTopItem(gridItem)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let lastSection = collectionView.numberOfSections - 1
        guard indexPath.section == lastSection else { return }
        let itemCount = collectionView.numberOfItems(inSection: lastSection)
        if indexPath.item >= itemCount - paginationMargin {
            viewModel.didShowLastItem()
        }
    }
}

// MARK: - Drag-select gesture gating

extension PhotosCollectionViewController: UIGestureRecognizerDelegate {
    // Only recognize the drag select gesture if we are dragging more on the horizontal axis
    // This let the user scroll through the gallery in selection mode
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        guard viewModel.isSelecting else { return false }
        let velocity = pan.velocity(in: collectionView)
        return abs(velocity.x) > abs(velocity.y)
    }
}

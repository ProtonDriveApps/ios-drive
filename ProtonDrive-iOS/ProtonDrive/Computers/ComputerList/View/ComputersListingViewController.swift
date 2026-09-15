// Copyright (c) 2025 Proton AG
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
import SwiftUI
import UIKit
import ProtonCoreUIFoundations
import Combine
import PDUIComponents
import PDLocalization
import PDCoreIOS

class ComputersViewController: UIViewController {
    private var initialLoader: UIViewController?
    private var collectionView: UICollectionView!
    private let refreshControl = UIRefreshControl()
    private let verticalStack = UIStackView()
    private let viewModel: ComputersViewModel
    private let cellFactory: ComputersCellControllerFactory
    private var subscriptions = Set<AnyCancellable>()

    private var emptyStateView: UIView?

    init(viewModel: ComputersViewModel, cellFactory: ComputersCellControllerFactory) {
        self.viewModel = viewModel
        self.cellFactory = cellFactory
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm
        navigationItem.title = Localization.computers_screen_title
        setupStackView()
        setupCollectionView()
        setupRefreshControl()
        setupEmptyStateView()

        // Bind the viewModel's data and loading state
        setupBindings()
        viewModel.onViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Trigger the refresh control on view load
        triggerInitialRefresh()
        navigationController?.navigationBar.isHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let collectionView = self.collectionView,
           collectionView.numberOfItems(inSection: 0) > 0 {
            viewModel.reportListIsShown()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.isHidden = true
    }

    private func setupStackView() {
        verticalStack.axis = .vertical

        view.addSubview(verticalStack)
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        verticalStack.fillSuperview()
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: view.bounds.width, height: 60)
        layout.minimumLineSpacing = .zero
        layout.scrollDirection = .vertical

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ComputersSwiftUICollectionViewCell.self, forCellWithReuseIdentifier: ComputersSwiftUICollectionViewCell.reuseIdentifier)
        collectionView.alwaysBounceVertical = true

        collectionView.backgroundColor = ColorProvider.BackgroundNorm
        verticalStack.addArrangedSubview(collectionView)
    }

    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        refreshControl.tintColor = ColorProvider.BrandNorm.withAlphaComponent(0.6)
        collectionView.refreshControl = refreshControl
    }

    private func setupBindings() {
        viewModel.$computers.sink { [weak self] computers in
            self?.collectionView.reloadData()
            self?.viewModel.reportListIsShown()
            self?.updateEmptyState(isEmpty: computers.isEmpty)
            self?.refreshControl.endRefreshing()
            self?.initialLoader?.remove()
            self?.initialLoader = nil
        }.store(in: &subscriptions)

        viewModel.$upgradeRequirementLevel.sink { [weak self] level in
            if level == .none {
                self?.removeUpgradeRequirementBanner()
            } else {
                self?.setupUpgradeRequirementBanner(level: level)
            }
        }
        .store(in: &subscriptions)
    }

    private func triggerInitialRefresh() {
        Task {
            await self.viewModel.fetchComputers()
        }

        guard viewModel.isInitialLoad else {
            return
        }
        let initialLoader = UIHostingController(rootView: ProtonSpinner(size: .medium))
        self.initialLoader = initialLoader
        add(initialLoader)
    }

    @objc private func didPullToRefresh() {
        Task {
            await viewModel.fetchComputers()
            refreshControl.endRefreshing()
        }
    }

    private func setupEmptyStateView() {
        let emptyView = PlaceholderView(viewModel: .computers)
        let emptyUIViewController = UIHostingController(rootView: emptyView)
        emptyUIViewController.view.backgroundColor = .clear
        addChild(emptyUIViewController)
        collectionView.backgroundView = emptyUIViewController.view
        emptyUIViewController.didMove(toParent: self)
    }

    private func updateEmptyState(isEmpty: Bool) {
        collectionView.backgroundView?.isHidden = !isEmpty
    }

    private func setupUpgradeRequirementBanner(level: UpgradeRequirementLevel) {
        removeUpgradeRequirementBanner()
        let banner = UpgradeRequirementBannerView(level: level, handling: viewModel.upgradeRequirementBannerController)
        let vc = banner.embeddedInHostingController()
        addChild(vc)
        verticalStack.insertArrangedSubview(vc.view, at: 0)
        vc.didMove(toParent: self)
    }

    private func removeUpgradeRequirementBanner() {
        let bannerViews = verticalStack.arrangedSubviews.filter { $0 !== collectionView }
        for bannerView in bannerViews {
            verticalStack.removeArrangedSubview(bannerView)

            if let bannerController = children.first(where: { $0.view === bannerView }) {
                bannerController.willMove(toParent: nil)
                bannerController.view.removeFromSuperview()
                bannerController.removeFromParent()
            } else {
                bannerView.removeFromSuperview()
            }
        }
    }
}

// MARK: - UICollectionView Delegate & DataSource

extension ComputersViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.computers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ComputersSwiftUICollectionViewCell.reuseIdentifier, for: indexPath) as? ComputersSwiftUICollectionViewCell else {
            return UICollectionViewCell()
        }
        let computer = viewModel.computers[indexPath.item]
        cell.configure(with: computer, factory: cellFactory)
        return cell
    }
}

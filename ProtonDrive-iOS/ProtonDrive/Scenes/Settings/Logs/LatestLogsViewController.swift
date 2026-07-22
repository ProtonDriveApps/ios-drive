// Copyright (c) 2024 Proton AG
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

import UIKit
import Combine
import PDLocalization

final class LatestLogsViewController: UIViewController {
    private let viewModel: LatestLogsViewModel
    private let logsView = LatestLogsView()
    private var cancellables = Set<AnyCancellable>()

    private static let bottomScrollThreshold: CGFloat = 80

    init(viewModel: LatestLogsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = logsView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: Localization.setting_export_logs,
            style: .plain,
            target: self,
            action: #selector(didTapExportAllLogs)
        )

        wireViewCallbacks()
        setupBindings()
        viewModel.startFetchingData()
    }

    private func wireViewCallbacks() {
        logsView.onSearchTextChanged = { [weak self] in
            self?.viewModel.updateSearchTerm(self?.logsView.searchText ?? "")
        }
        logsView.onPreviousMatch = { [weak self] in
            self?.viewModel.goToPreviousMatch()
        }
        logsView.onNextMatch = { [weak self] in
            self?.viewModel.goToNextMatch()
        }
        logsView.onScrollToBottomTapped = { [weak self] in
            guard let self else { return }
            if self.viewModel.hasMoreContent {
                self.viewModel.loadMoreIfNeeded()
            }
            self.logsView.scrollToEndOfLog()
            self.updateScrollToBottomButtonVisibility()
        }
        logsView.onScrollViewDidScroll = { [weak self] scrollView in
            guard let self else { return }
            self.updateScrollToBottomButtonVisibility()
            guard self.isNearBottom(of: scrollView) else { return }
            self.viewModel.loadMoreIfNeeded()
        }
    }

    private func setupBindings() {
        viewModel.$displayState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                let previousOffset = self.logsView.textView.contentOffset
                self.logsView.configure(with: state)
                self.logsView.textView.layoutIfNeeded()
                self.logsView.textView.contentOffset = previousOffset
                self.updateScrollToBottomButtonVisibility()
            }
            .store(in: &cancellables)

        viewModel.$scrollToMatchRange
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] range in
                self?.logsView.scrollToMatch(range)
                self?.viewModel.clearScrollToMatchRange()
            }
            .store(in: &cancellables)

        viewModel.$isExporting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isExporting in
                self?.navigationItem.rightBarButtonItem?.isEnabled = !isExporting
            }
            .store(in: &cancellables)

        viewModel.logExported
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(activityVC, animated: true)
            }
            .store(in: &cancellables)
    }

    private func isNearBottom(of scrollView: UIScrollView) -> Bool {
        let visibleHeight = scrollView.bounds.height
            - scrollView.adjustedContentInset.top
            - scrollView.adjustedContentInset.bottom
        guard visibleHeight > 0 else { return true }

        let offsetY = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let contentHeight = scrollView.contentSize.height
        return offsetY + visibleHeight >= contentHeight - Self.bottomScrollThreshold
    }

    private func updateScrollToBottomButtonVisibility() {
        logsView.setScrollToBottomButtonHidden(isNearBottom(of: logsView.textView))
    }

    @objc private func didTapExportAllLogs() {
        viewModel.exportAllLogs()
    }
}

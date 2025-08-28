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

class LatestLogsViewController: UIViewController {
    var textView: UITextView!
    var viewModel: LatestLogsViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()

        textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        view.addSubview(textView)
        textView.fillSuperview()

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "All logs",
            style: .plain,
            target: self,
            action: #selector(didTapExportAllLogs)
        )

        setupBindings()

        viewModel.startFetchingData()
    }

    private func setupBindings() {
        viewModel.$latestLogText
            .receive(on: DispatchQueue.main)
            .assign(to: \.text, on: textView)
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
                guard let self = self else { return }
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(activityVC, animated: true)
            }
            .store(in: &cancellables)
    }

    @objc private func didTapExportAllLogs() {
        viewModel.exportAllLogs()
    }

    deinit {
        viewModel.stopFetchingData()
    }
}

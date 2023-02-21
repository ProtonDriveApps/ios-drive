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
import PDCore

final class PDUIActivityViewController: UIActivityViewController, UIAdaptivePresentationControllerDelegate {
    var url: URL?

    convenience init(url: URL?) {
        self.init(activityItems: [url as Any], applicationActivities: nil)
        self.url = url
    }

    override func willMove(toParent parent: UIViewController?) {
        self.parent?.presentationController?.delegate = self
    }

    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        return false
    }
}

struct AppActivityView: UIViewControllerRepresentable {
    let file: File
    let url: URL?

    func makeUIViewController(context: UIViewControllerRepresentableContext<AppActivityView>) -> PDUIActivityViewController {
        let controller = PDUIActivityViewController(url: url)
        controller.completionWithItemsHandler = completionHandler
        controller.excludedActivityTypes = [.copyToPasteboard, .print]
        return controller
    }

    private var completionHandler: UIActivityViewController.CompletionWithItemsHandler {
        return { (activityType, completed, returnedItems, error) in
            self.deleteClearTextFile()
        }
    }

    func updateUIViewController(_ uiViewController: PDUIActivityViewController, context: UIViewControllerRepresentableContext<AppActivityView>) {
    }

    public static func dismantleUIViewController(_ uiViewController: UIViewControllerType, coordinator: Coordinator) {
        uiViewController.completionWithItemsHandler = nil
    }

    func deleteClearTextFile() {
        guard let url = url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

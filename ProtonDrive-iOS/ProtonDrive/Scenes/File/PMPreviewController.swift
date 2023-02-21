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

import QuickLook

final class PMPreviewController: QLPreviewController {
    var share: Bool?

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .allButUpsideDown)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard shouldShare,
        let item = currentPreviewItem else { return }
        share(item)
    }

    private var shouldShare: Bool {
        share ?? false
    }

    override func viewWillDisappear(_ animated: Bool) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            (UIApplication.shared.delegate as? AppDelegate)?.lockOrientationIfNeeded(in: .portrait)
        }
        super.viewWillDisappear(animated)
    }

    private func share(_ item: QLPreviewItem) {
        let vc = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = self.view
        present(vc, animated: true, completion: nil)
    }
}

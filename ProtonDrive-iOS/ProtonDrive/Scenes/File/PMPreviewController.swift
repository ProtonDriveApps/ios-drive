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
import PDCore

final class PMPreviewController: QLPreviewController {
    var model: FileModel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if UIDevice.current.userInterfaceIdiom == .phone {
            lockOrientationIfNeeded(in: .allButUpsideDown)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // This is not an exact timestamp, it may be affected by view rendering.
        // There could be up to a 0.5-second difference between the reported time and the actual UX
        model.viewDidAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        if UIDevice.current.userInterfaceIdiom == .phone {
            lockOrientationIfNeeded(in: .portrait)
        }
        super.viewWillDisappear(animated)
    }
}

extension UIViewController {
    @objc func close() {
        dismiss(animated: true)
    }

    @objc func back() {
        navigationController?.popViewController(animated: true)
    }
}

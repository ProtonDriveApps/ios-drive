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
import PDUIComponents

struct EditNodeUIKitView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController

    @EnvironmentObject var root: RootViewModel
    let vm: EditNodeViewModel
    let nfvm: NameFormattingViewModel

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = EditNodeViewController()
        vc.viewModel = vm
        vc.tfViewModel = nfvm
        vm.onDismiss = { [weak root = self.root] in root?.closeCurrentSheet.send() }
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
}

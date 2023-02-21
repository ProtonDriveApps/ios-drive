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
import PDUIComponents
import ProtonCore_UIFoundations

struct FileView: View {
    @EnvironmentObject var root: RootViewModel
    @State private var isReadyToPresent: Bool = false
    @State private var state: FileModel.Events = .initial
    let coordinator: FileCoordinator
    let model: FileModel
    let share: Bool

    var body: some View {
        Group {
            switch self.state {
            case .initial, .decrypted:
                AlertView(title: "Decrypting...", cancelHandler: self.model.cancel)
            case .closed: EmptyView()
            case let .error(description): AlertView(title: "Decryption failed", message: description, cancelHandler: self.model.cleanup)
            }
        }
        .presentView(isPresented: $isReadyToPresent, style: .fullScreenWithoutBlender) {
            let preview = PMPreviewController()
            preview.share = self.share
            preview.dataSource = self.model
            preview.delegate = self.model
            return preview
        }
        .onReceive(self.model.events) { event in
            self.state = event
            
            switch event {
            case .initial, .error:
                break
            case .decrypted:
                self.isReadyToPresent = true
                self.root.stateRestorationActivity = self.coordinator.buildStateRestorationActivity()
            case .closed:
                self.isReadyToPresent = false
                self.root.stateRestorationActivity = self.coordinator.buildParentRestorationActivity()
                self.root.closeCurrentSheet.send()
            }
        }
        .onAppear {
            if case FileModel.Events.initial = self.state {
                self.model.decrypt()
            }
        }
    }
}

struct AlertView: UIViewControllerRepresentable {
    @State var title: String
    @State var message: String?
    
    typealias CancelHandler = () -> Void
    var cancelHandler: CancelHandler
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        // nothing
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let alert = UIAlertController(title: self.title, message: self.message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { _ in self.cancelHandler() }
        alert.addAction(cancel)
        
        let vc = UIViewController()
        vc.addChild(alert)
        
        vc.view.addSubview(alert.view)
        vc.view.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor).isActive = true
        vc.view.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor).isActive = true
        
        return vc
    }
}

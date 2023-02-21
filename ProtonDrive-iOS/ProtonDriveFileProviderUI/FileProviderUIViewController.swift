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

import UIKit
import FileProviderUI
import PDUIComponents
import PDCore
import ProtonCore_Keymaker
import ProtonCore_Settings
import os.log

class FileProviderUIViewController: FPUIActionExtensionViewController {
    @IBOutlet var containerView: UIView!
    
    private var errorCaught: NSError?
    private lazy var keymaker = Keymaker(autolocker: nil, keychain: DriveKeychain())
    
    override func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {
        // Implement custom actions here: ShareURL creation and editing, etc
    }
    
    override func prepare(forError error: Error) {
        let errorCaught = error as NSError

        switch errorCaught.userInfo[CrossProcessErrorExchange.UnderlyingMessageKey] as? String {
        case .some(CrossProcessErrorExchange.notAuthenticated):
            self.injectSignInController()
            
        case .some(CrossProcessErrorExchange.pinExchangeNotSupported):
            self.injectUnlockNotSupportedViewController()
            
        case .some(CrossProcessErrorExchange.pinExchangeInProgress):
            self.errorCaught = errorCaught
            self.injectUnlockViewController()
            
        default: break
        }
    }
    
    private func injectSignInController() {
        let alert = UIAlertController(title: "Sign In to Proton Drive",
                                      message: "Please open the Proton Drive app to sign in to continue",
                                      preferredStyle: .alert)
        let close = UIAlertAction(title: "Ok", style: .default) { _ in
            self.extensionContext.cancelRequest(withError: CrossProcessErrorExchange.cancelError)
        }
        alert.addAction(close)
        self.present(alert, animated: true, completion: nil)
    }
    
    private func injectUnlockNotSupportedViewController() {
        let alert = UIAlertController(title: "Proton Drive is Locked",
                                      message: "While PIN or Face ID/Touch ID are enabled on Proton Drive the content is not accessible in Files",
                                      preferredStyle: .alert)
        let close = UIAlertAction(title: "Ok", style: .default) { _ in
            self.extensionContext.cancelRequest(withError: CrossProcessErrorExchange.cancelError)
        }
        alert.addAction(close)
        self.present(alert, animated: true, completion: nil)
    }

    private func injectUnlockViewController() {
        let unlocker = UnlockHandler(keymaker: keymaker, delegate: self)
        
        let viewController = PMUnlockViewControllerComposer.assemble(
            header: .drive(subtitle: nil),
            unlocker: unlocker,
            logoutManager: nil,
            logoutAlertSubtitle: "")
        
        DispatchQueue.main.async {
            guard self.children.isEmpty else { return }
            
            self.containerView.addSubview(viewController.view)
            viewController.view.frame = self.containerView.bounds
            viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            viewController.didMove(toParent: self)
        }
    }
    
    @IBAction func cancelButtonTapped(_ sender: Any) {
        extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.failed.rawValue), userInfo: nil))
    }
}

extension FileProviderUIViewController: UnlockHandlerDelegate {
    
    func sealMainKey() {
        guard let mainKey = keymaker.mainKey else { return }
        guard let error = self.errorCaught else { return }
        CrossProcessMainKeyExchange.sealUserInput(mainKey, withKeyPlacedInto: error.userInfo)
        self.extensionContext.completeRequest()
    }

}

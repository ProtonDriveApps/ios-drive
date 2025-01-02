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

import Foundation
import Combine
import UIKit

extension UIViewController {
    
    func adjustSafeAreaForKeyboardHeight(_ cancellables: inout Set<AnyCancellable>) {
        let notificationCenter = NotificationCenter.default
        let initialSafeAreaInsets = self.additionalSafeAreaInsets
        
        notificationCenter.publisher(for: UIResponder.keyboardWillHideNotification, object: nil)
            .sink { [weak self] _ in
                self?.additionalSafeAreaInsets = initialSafeAreaInsets
            }
            .store(in: &cancellables)
        
        notificationCenter.publisher(for: UIResponder.keyboardWillChangeFrameNotification, object: nil)
            .sink { [weak self] notification in
                guard let keyboardValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
                
                guard let self = self else { return }

                let keyboardScreenEndFrame = keyboardValue.cgRectValue
                let keyboardViewEndFrame = self.view.convert(keyboardScreenEndFrame, from: self.view.window)
                
                let correction = self.view.safeAreaInsets.bottom - self.additionalSafeAreaInsets.bottom
                self.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardViewEndFrame.height - correction, right: 0)
            }
            .store(in: &cancellables)
    }
    
}

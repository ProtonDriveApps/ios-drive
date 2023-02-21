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
import PDCore
import PDUIComponents

class Deeplink {
    typealias UnderlyingType = NodeIdentifier
    typealias CollectionType = [UnderlyingType]
    
    private static let AnimationSwitchDelay = 250 // milliseconds
    
    private var tab: NavigationBarButtonViewModel.RawValue?
    private var modal: UnderlyingType?
    private var chain: CollectionType?
    
    private let lock = NSLock()
    
    func finalModal() -> UnderlyingType? {
        return modal
    }
    
    func latestTab() -> NavigationBarButtonViewModel? {
        guard let raw = self.tab else { return nil }
        return NavigationBarButtonViewModel(rawValue: raw)
    }
    
    func next(after previous: UnderlyingType?) -> UnderlyingType? {
        guard let previous = previous else { return nil }
        guard let next = self.chain?.firstIndex(of: previous)?.advanced(by: 1) else { return nil }
        guard let total = self.chain?.count, total > next else { return nil }
        return self.chain?[next]
    }
    
    func inject(_ modal: UnderlyingType) {
        self.modal = modal
    }
    
    func inject(_ tab: NavigationBarButtonViewModel) {
        self.tab = tab.rawValue
    }
    
    func inject(_ chain: CollectionType) {
        /*
         Animations of NavigationView push transition can not be switched off in any other way on iOS 14. Earlier betas were crashing when deeplink had more than 2 steps. Don't forget to switch animations on in invaludate() method!

         Original radar: FB7840140
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.AnimationSwitchDelay)) {
            UINavigationBar.setAnimationsEnabled(false)
        }
        
        lock.lock()
        defer { lock.unlock() }
        
        self.chain = chain
    }
    
    func invalidate() {
        /*
         This little delay lets the last screen of a deeplink to be pushed without animation, but all the following ones will have one. This is a workaround for change in iOS 14 where all deeplinks in NavigationLink are animated.

         Original radar: FB7840140
         */
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Self.AnimationSwitchDelay * 2)) {
            UINavigationBar.setAnimationsEnabled(true)
        }
        
        self.tab = nil
        self.chain = nil
        self.modal = nil
    }
}

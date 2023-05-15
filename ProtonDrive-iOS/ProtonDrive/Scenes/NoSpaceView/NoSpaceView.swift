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
import ProtonCore_UIFoundations
import PDUIComponents

struct NoSpaceView: View {
    @EnvironmentObject var root: RootViewModel
    @Environment(\.acknowledgedNotEnoughStorage) var acknowledgedNotEnoughStorage
    var storage: Storage
    
    var body: some View {
        VStack(alignment: .center) {

            Spacer()
                .frame(height: 72)

            Text(self.storage.title)
                .font(.title)
                .bold()
                .foregroundColor(ColorProvider.TextNorm)

            Text(self.storage.subtitle)
                .font(.subheadline)
                .foregroundColor(ColorProvider.TextWeak)
                .padding(.top, 8)

            if self.storage == .local {
                BlueRectButton(title: "Go to local storage settings",
                               action: self.openSettings)
                .fixedSize()
                .padding(.top, 30)
            }

            if self.storage == .cloud {
                NoSpaceAdviceView()
            }

            Spacer()
        }
        .lineLimit(nil)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal)
        .closable { root.closeCurrentSheet.send() }
        .onDisappear {
            self.acknowledgedNotEnoughStorage.wrappedValue = true
        }
    }
    
    func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
            UIApplication.shared.canOpenURL(settingsUrl) else
        {
            return
        }
        UIApplication.shared.open(settingsUrl) { _ in }
    }
}

struct NoSpaceLocallyView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NoSpaceView(storage: .local)
            
            NoSpaceView(storage: .cloud)
        }
    }
}

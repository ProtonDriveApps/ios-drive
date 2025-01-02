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
import ProtonCoreUIFoundations
import PDLocalization

struct TechnicalErrorPlaceholderView: View {
    @EnvironmentObject var root: RootViewModel
    var message: String = Localization.technical_error_placeholder
    
    var body: some View {
        ScrollView {
            VStack(alignment: .center) {
                Text("⚠️")
                .font(.title)
                .foregroundColor(ColorProvider.TextNorm)
                .padding(.top, 30)
                
                Text(message)
                .font(.subheadline)
                .foregroundColor(ColorProvider.TextWeak)
                .padding(.top, 8)
            }
            .lineLimit(nil)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
        }
        .closable { root.closeCurrentSheet.send() }
    }
}

struct ErrorPlaceholder_Previews: PreviewProvider {
    static var previews: some View {
        TechnicalErrorPlaceholderView()
    }
}

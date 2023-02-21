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
import Combine
import PDCore
import ProtonCore_UIFoundations
import PDUIComponents

struct ProgressesStatusToast: View {
    @EnvironmentObject var tabBar: TabBarViewModel
    @State var isVisible = false
    var uploadErrors: ErrorRegulator
    var failedUploads: Int

    func dismiss() {
        self.isVisible = false
    }
    
    var message: String {
        "Failed to upload \(failedUploads) file\(failedUploads > 1 ? "s" : "")"
    }
    
    @ViewBuilder var body: some View {
        Group {
            VStack {
                if self.isVisible && failedUploads > 0 {
                    RectangleToast(message: self.message,
                                   orientation: .vertical,
                                   backgroundColor: ColorProvider.NotificationError) {
                        HStack {
                            Button(action: self.dismiss) {
                                Text("Dismiss")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        Color.white.opacity(0.2)
                                            .cornerRadius(.small)
                                            .padding(-5)
                                )
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom)
                    }
                } else {
                    EmptyView()
                }
            }
        }
        .onReceive(uploadErrors.stream.replaceError(with: nil)) { received in
            guard received != nil else { return }
            self.isVisible = true
        }
    }
}

struct UploadsStatusToast_Previews: PreviewProvider {
    static let uploadErrors: ErrorRegulator = .init()

    static var previews: some View {
        Group {
            ProgressesStatusToast(uploadErrors: self.uploadErrors, failedUploads: 2)

            ProgressesStatusToast(uploadErrors: self.uploadErrors, failedUploads: 2)

            ProgressesStatusToast(uploadErrors: self.uploadErrors, failedUploads: 0)
        }
        .previewLayout(.sizeThatFits)
    }
}

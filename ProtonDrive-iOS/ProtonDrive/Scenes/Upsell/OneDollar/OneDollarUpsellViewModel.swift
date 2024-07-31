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

final class OneDollarUpsellViewModel: ObservableObject {
    private let appStoreProductID: String
    private let priceRepository: SubscriptionPriceRepositoryProtocol
    private let settings: OneDollarUpsellSettings
    
    @Published var localPriceLabel: String
    
    let onButtonTapped: () -> Void
    let onSkipButtonTapped: () -> Void
    
    init(
        defaultPriceLabel: String,
        appStoreProductID: String,
        priceRepository: SubscriptionPriceRepositoryProtocol,
        settings: OneDollarUpsellSettings,
        onButtonTapped: @escaping () -> Void,
        onSkipButtonTapped: @escaping () -> Void
    ) {
        self.localPriceLabel = defaultPriceLabel
        self.appStoreProductID = appStoreProductID
        self.priceRepository = priceRepository
        self.settings = settings
        self.onButtonTapped = onButtonTapped
        self.onSkipButtonTapped = onSkipButtonTapped
    }
    
    func onAppear() {
        settings.isUpsellShown = true
    }
    
    @MainActor
    func fetchLocalPrice() async {
        do {
            let price = try await priceRepository.fetchPriceLabel(appStoreId: appStoreProductID)
            self.localPriceLabel = price
        } catch {
            // fallback to default hardcoded value
        }
    }
}

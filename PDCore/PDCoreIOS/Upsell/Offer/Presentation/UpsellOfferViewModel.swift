// Copyright (c) 2026 Proton AG
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

import Combine
import PDCore

@MainActor
final class UpsellOfferViewModel: ObservableObject {
    @Published private(set) var selectedIndex: Int
    @Published private(set) var isPurchasing = false

    let content: UpsellOfferContent

    /// Renewal disclosure for the currently selected cycle (coupon options show their post-promo rate).
    var footnote: String {
        content.cycleOptions[safe: selectedIndex]?.footnote ?? ""
    }

    private let offer: UpsellOfferData
    private let purchaseResource: UpsellPurchaseResource
    private let couponInteractor: UpsellCouponInteractorProtocol
    private weak var coordinator: UpsellCoordinatorProtocol?
    private let messageHandler: UserMessageHandlerProtocol

    init(
        offer: UpsellOfferData,
        purchaseResource: UpsellPurchaseResource,
        couponInteractor: UpsellCouponInteractorProtocol,
        coordinator: UpsellCoordinatorProtocol,
        messageHandler: UserMessageHandlerProtocol = UserMessageHandler(),
        viewDataFactory: UpsellOfferViewDataFactory = UpsellOfferViewDataFactory()
    ) {
        self.offer = offer
        self.purchaseResource = purchaseResource
        self.couponInteractor = couponInteractor
        self.coordinator = coordinator
        self.messageHandler = messageHandler

        self.content = viewDataFactory.makeContent(from: offer)
        self.selectedIndex = Self.defaultSelectedIndex(offer.cycleOptions)
    }

    func select(_ index: Int) {
        selectedIndex = index
    }

    func close() {
        coordinator?.dismiss()
    }

    func purchase() {
        guard !isPurchasing, let cycleOption = offer.cycleOptions[safe: selectedIndex] else {
            return
        }

        switch cycleOption.price {
        case .coupon(let code, _, let currencyCode):
            // Coupon cycles are redeemed on the web, not via StoreKit.
            redeemCoupon(code: code, cycleMonths: cycleOption.cycleMonths, currency: currencyCode)
        case .store:
            purchaseFromStore(productID: cycleOption.productID)
        }
    }

    private func purchaseFromStore(productID: String) {
        isPurchasing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let outcome = try await self.purchaseResource.purchase(productID: productID)
                switch outcome {
                case .pending:
                    // Pending awaits external approval (e.g. Ask to Buy) and completes out of band
                    // via the transactions observer; let the user know before leaving the modal.
                    self.messageHandler.handleSuccess(self.content.pendingMessage)
                    self.coordinator?.dismiss()
                case .purchased:
                    // Finalizes via the transactions observer; nothing more to do in the modal.
                    self.coordinator?.dismiss()
                case .cancelled:
                    break
                }
            } catch {
                self.messageHandler.handleError(PlainMessageError(error.localizedDescription))
            }
            self.isPurchasing = false
        }
    }

    private func redeemCoupon(code: String, cycleMonths: Int, currency: String) {
        let input = UpsellCheckoutInput(coupon: code, plan: offer.planName, cycle: String(cycleMonths), currency: currency)
        isPurchasing = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await self.couponInteractor.execute(input: input)
                self.isPurchasing = false
                self.coordinator?.open(url: url)
                self.coordinator?.dismiss()
            } catch {
                self.isPurchasing = false
                Log.error("Failed to generate upsell coupon URL", error: error, domain: .subscriptions)
                self.messageHandler.handleError(PlainMessageError(error.localizedDescription))
            }
        }
    }

    /// Pre-selects the coupon (discounted) option when present, otherwise the yearly cycle.
    private static func defaultSelectedIndex(_ options: [CycleOption]) -> Int {
        if let coupon = options.firstIndex(where: { $0.price.hasCoupon }) {
            return coupon
        }
        if let yearly = options.firstIndex(where: { $0.cycleMonths == 12 }) {
            return yearly
        }
        return 0
    }
}

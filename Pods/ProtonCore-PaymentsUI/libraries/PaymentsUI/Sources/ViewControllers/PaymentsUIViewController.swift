//
//  PaymentsUIViewController.swift
//  ProtonCorePaymentsUI - Created on 01/06/2021.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

#if os(iOS)

import UIKit
import ProtonCoreFoundations
import ProtonCoreUIFoundations
import ProtonCoreObservability
import ProtonCoreFeatureFlags
import ProtonCoreUtilities

protocol PaymentsUIViewControllerDelegate: AnyObject {
    func viewControllerWillAppear(isFirstAppearance: Bool)
    func userDidCloseViewController()
    func userDidDismissViewController()
    func userDidSelectPlan(plan: PlanPresentation, addCredits: Bool, completionHandler: @escaping () -> Void)
    func userDidSelectPlan(plan: AvailablePlansPresentation, completionHandler: @escaping () -> Void)
    func planPurchaseError()
    func purchaseBecameUnavailable()
}

extension PaymentsUIViewControllerDelegate { // for backwards compatibility
    func purchaseBecameUnavailable() { }
}

public final class PaymentsUIViewController: UIViewController, AccessibleView {
    private var firstAvailablePlanIndexPath: IndexPath?
    private var firstAvailablePlanCell: PlanCell?

    private lazy var selectedCycle = viewModel?.defaultCycle

    private var isDynamicPlansEnabled: Bool {
        featureFlagsRepository.isEnabled(CoreFeatureFlagType.dynamicPlan)
    }

    // MARK: - Constants

    private let sectionHeaderView = "PlanSectionHeaderView"
    private let sectionHeaderHeight: CGFloat = 91.0

    // MARK: - Outlets

    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var tableHeaderTitleLabel: UILabel! {
        didSet {
            tableHeaderTitleLabel.textColor = ColorProvider.TextNorm
        }
    }
    @IBOutlet weak var tableHeaderDescriptionLabel: UILabel! {
        didSet {
            tableHeaderDescriptionLabel.textColor = ColorProvider.TextWeak
        }
    }
    @IBOutlet var tableHeaderImageViews: [UIImageView]!
    @IBOutlet weak var tableFooterTextLabel: UILabel! {
        didSet {
            tableFooterTextLabel.textColor = ColorProvider.TextWeak
            tableFooterTextLabel.font = .adjustedFont(forTextStyle: .subheadline)
            tableFooterTextLabel.adjustsFontForContentSizeCategory = true
            tableFooterTextLabel.adjustsFontSizeToFitWidth = false
        }
    }
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.dataSource = self
            tableView.delegate = self
            tableView.register(AlertBoxCell.self, forCellReuseIdentifier: AlertBoxCell.reuseIdentifier)
            tableView.register(PlanCell.nib, forCellReuseIdentifier: PlanCell.reuseIdentifier)
            tableView.register(CurrentPlanCell.nib, forCellReuseIdentifier: CurrentPlanCell.reuseIdentifier)
            tableView.separatorStyle = .none
            tableView.estimatedRowHeight = UITableView.automaticDimension
            tableView.rowHeight = UITableView.automaticDimension
            tableView.estimatedSectionHeaderHeight = sectionHeaderHeight
        }
    }
    @IBOutlet weak var infoIcon: UIImageView! {
        didSet {
            infoIcon.image = IconProvider.infoCircle
            infoIcon.tintColor = ColorProvider.IconWeak
        }
    }
    @IBOutlet weak var buttonStackView: UIStackView! {
        didSet {
            buttonStackView.isAccessibilityElement = true
        }
    }
    @IBOutlet weak var spacerView: UIView! {
        didSet {
            spacerView.isHidden = true
        }
    }
    @IBOutlet weak var extendSubscriptionButton: ProtonButton! {
        didSet {
            extendSubscriptionButton.isHidden = true
            extendSubscriptionButton.isAccessibilityElement = true
            extendSubscriptionButton.setMode(mode: .solid)
            extendSubscriptionButton.setTitle(PUITranslations._extend_subscription_button.l10n, for: .normal)
        }
    }

    // MARK: - Properties

    weak var delegate: PaymentsUIViewControllerDelegate?
    var featureFlagsRepository: FeatureFlagsRepositoryProtocol = FeatureFlagsRepository.shared
    var viewModel: PaymentsUIViewModel?
    var mode: PaymentsUIMode = .signup
    var modalPresentation = false
    var hideFooter = false
    private let planConnectionErrorView = PlanConnectionErrorView()
    public var onDohTroubleshooting: () -> Void = {}

    private let navigationBarAdjuster = NavigationBarAdjustingScrollViewDelegate()

    override public var preferredStatusBarStyle: UIStatusBarStyle { darkModeAwarePreferredStatusBarStyle() }

    private var controllerDidAlreadyAppear = false

    override public func viewDidLoad() {
        super.viewDidLoad()
        if #unavailable(iOS 13.0) {
            if Brand.currentBrand == .vpn {
                tableView.indicatorStyle = .white
            }
        }

        view.backgroundColor = ColorProvider.BackgroundNorm
        tableView.backgroundColor = ColorProvider.BackgroundNorm
        tableView.tableHeaderView?.backgroundColor = ColorProvider.BackgroundNorm
        tableView.tableFooterView?.backgroundColor = ColorProvider.BackgroundNorm
        tableView.tableHeaderView?.isHidden = true
        tableView.tableFooterView?.isHidden = true
        let nib = UINib(nibName: sectionHeaderView, bundle: PaymentsUI.bundle)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: sectionHeaderView)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        if mode != .signup {
            tableView.contentInset = UIEdgeInsets(top: -35, left: 0, bottom: 0, right: 0)
        }
        navigationItem.title = ""
        if modalPresentation {
            setUpCloseButton(showCloseButton: true, action: #selector(PaymentsUIViewController.onCloseButtonTap(_:)))
        } else {
            setUpBackArrow(action: #selector(PaymentsUIViewController.onCloseButtonTap(_:)))
        }

        if isDataLoaded {
            reloadUI()
        }
        generateAccessibilityIdentifiers()
        navigationItem.assignNavItemIndentifiers()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(PaymentsUIViewController.informAboutIAPInProgress),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(preferredContentSizeChanged(_:)),
                         name: UIContentSizeCategory.didChangeNotification,
                         object: nil)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )

        sendObservabilityEvents()
    }

    private func sendObservabilityEvents() {
        switch mode {
        case .signup:
            ObservabilityEnv.report(.screenLoadCountTotal(screenName: .planSelection))
            if isDynamicPlansEnabled {
                ObservabilityEnv.report(.paymentScreenView(screenID: .dynamicPlanSelection))
            }
        case .current:
            if isDynamicPlansEnabled {
                ObservabilityEnv.report(.paymentScreenView(screenID: .dynamicPlansCurrentSubscription))
            }
        case .update:
            if isDynamicPlansEnabled {
                ObservabilityEnv.report(.paymentScreenView(screenID: .dynamicPlansUpgrade))
            }
        }
    }

    var banner: PMBanner?

    @objc private func informAboutIAPInProgress() {
        if viewModel?.iapInProgress == true {
            let banner = PMBanner(message: PUITranslations.iap_in_progress_banner.l10n,
                                  style: PMBannerNewStyle.error,
                                  dismissDuration: .infinity)
            showBanner(banner: banner, position: .top)
            self.banner = banner
        } else {
            self.banner?.dismiss(animated: true)
        }

    }

    @objc
    private func preferredContentSizeChanged(_ notification: Notification) {
        tableFooterTextLabel.font = .adjustedFont(forTextStyle: .subheadline)
    }

    override public func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        navigationBarAdjuster.setUp(for: tableView, parent: parent)
        tableView.delegate = self
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate?.userDidDismissViewController()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ObservabilityEnv.report(.paymentScreenView(screenID: .planSelection))
        delegate?.viewControllerWillAppear(isFirstAppearance: !controllerDidAlreadyAppear)
        controllerDidAlreadyAppear = true
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeaderFooterViewHeight()
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        showExpandButton()
    }

    @IBAction func onExtendSubscriptionButtonTap(_ sender: ProtonButton) {
        guard !isDynamicPlansEnabled else {
            assertionFailure("Auto-renewing subscriptions (but governed with the Dynamic Plans FF) are not extensible")
            return
        }
        extendSubscriptionButton.isSelected = true
        guard case .withExtendSubscriptionButton(let plan) = viewModel?.footerType else {
            extendSubscriptionButton.isSelected = false
            return
        }
        lockUI()
        delegate?.userDidSelectPlan(plan: plan, addCredits: true) { [weak self] in
            self?.unlockUI()
            self?.extendSubscriptionButton.isSelected = false
        }
    }

    // MARK: - Internal methods

    func reloadData() {
        isData = true
        if isViewLoaded {
            tableView.reloadData()
            reloadUI()
        }
    }

    func showPurchaseSuccessBanner() {
        let banner = PMBanner(message: PUITranslations._plan_successfully_upgraded.l10n,
                              style: PMBannerNewStyle.info,
                              dismissDuration: 4.0)
        showBanner(banner: banner, position: .top)
    }

    func extendSubscriptionSelection() {
        extendSubscriptionButton.isSelected = true
        extendSubscriptionButton.isUserInteractionEnabled = false
    }

    func showBanner(banner: PMBanner, position: PMBannerPosition) {
        if !activityIndicator.isHidden {
            activityIndicator.isHidden = true
        }
        PMBanner.dismissAll(on: self)
        banner.show(at: position, on: self)
    }

    func showOverlayConnectionError() {
        guard !view.subviews.contains(planConnectionErrorView) else { return }
        planConnectionErrorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(planConnectionErrorView)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: planConnectionErrorView.topAnchor),
            view.bottomAnchor.constraint(equalTo: planConnectionErrorView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: planConnectionErrorView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: planConnectionErrorView.trailingAnchor)
        ])
    }

    public func planPurchaseError() {
        delegate?.planPurchaseError()
    }

    @objc func applicationWillEnterForeground() {
        delegate?.viewControllerWillAppear(isFirstAppearance: false)
    }

    // MARK: - Actions

    @objc func onCloseButtonTap(_ sender: UIButton) {
        delegate?.userDidCloseViewController()
    }

    // MARK: Private interface

    private func updateHeaderFooterViewHeight() {
        guard isDataLoaded, let headerView = tableView.tableFooterView, let footerView = tableView.tableFooterView else {
            return
        }
        if mode != .signup {
            tableView.tableHeaderView = nil
        } else {
            tableView.tableHeaderView?.isHidden = false
        }
        tableView.tableFooterView?.isHidden = hideFooter

        let width = tableView.bounds.size.width
        let headerSize = headerView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))
        if headerView.frame.size.height != headerSize.height {
            headerView.frame.size.height = headerSize.height
            tableView.tableFooterView = headerView
        }

        let footerSize = footerView.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))
        if footerView.frame.size.height != footerSize.height {
            footerView.frame.size.height = footerSize.height
            tableView.tableFooterView = footerView
        }
    }

    private func reloadUI() {
        guard isDataLoaded else { return }
        var hasExtendSubscriptionButton = false
        switch viewModel?.footerType {
        case .withPlansToBuy:
            tableFooterTextLabel.text = PUITranslations._plan_footer_desc.l10n
        case .withoutPlansToBuy, .none:
            tableFooterTextLabel.text = isDynamicPlansEnabled ? PUITranslations.plan_footer_desc_dynamic.l10n : PUITranslations.plan_footer_desc_purchased.l10n
        case .withExtendSubscriptionButton:
            tableFooterTextLabel.text = PUITranslations.plan_footer_desc_purchased.l10n
            hasExtendSubscriptionButton = !isDynamicPlansEnabled
        case .disabled:
            hideFooter = true
        }
        spacerView.isHidden = !hasExtendSubscriptionButton
        extendSubscriptionButton.isHidden = !hasExtendSubscriptionButton
        activityIndicator.isHidden = true
        updateHeaderFooterViewHeight()
        if mode == .signup {
            tableHeaderTitleLabel.text = PUITranslations.select_plan_title.l10n
            tableHeaderDescriptionLabel.text = PUITranslations._select_plan_description.l10n
            navigationItem.title = ""
            setupHeaderView()
        } else {
            if modalPresentation {
                switch mode {
                case .current:
                    navigationItem.title = PUITranslations.subscription_title.l10n
                    updateTitleAttributes()
                case .update:
                    if FeatureFlagsRepository.shared.isEnabled(CoreFeatureFlagType.dynamicPlan) {
                        navigationItem.title = PUITranslations.upgrade_plan_title.l10n
                    } else {
                        switch viewModel?.footerType {
                        case .withPlansToBuy:
                            navigationItem.title = PUITranslations.upgrade_plan_title.l10n
                        case .withoutPlansToBuy, .withExtendSubscriptionButton, .disabled, .none:
                            navigationItem.title = PUITranslations.current_plan_title.l10n
                        }
                    }
                    updateTitleAttributes()
                default:
                    break
                }
            } else {
                navigationItem.setHidesBackButton(true, animated: false)
                navigationItem.title = ""
            }
        }
        navigationItem.assignNavItemIndentifiers()
    }

    private(set) var isData = false

    private var isDataLoaded: Bool {
        return isData || mode == .signup
    }

    private func setupHeaderView() {
        let appIcons: [UIImage] = [
            IconProvider.mailMainTransparent,
            IconProvider.calendarMainTransparent,
            IconProvider.driveMainTransparent,
            IconProvider.vpnMainTransparent
        ]
        for (index, element) in tableHeaderImageViews.enumerated() {
            element.image = appIcons[index]
        }
    }

    private func showExpandButton() {
        if isDynamicPlansEnabled {
            showExpandButtonForDynamicPlans()
        } else {
            showExpandButtonForStaticPlans()
        }
    }

    private func showExpandButtonForStaticPlans() {
        guard let viewModel = viewModel else { return }
        for section in viewModel.plans.indices {
            guard viewModel.plans.indices.contains(section) else { continue }
            for row in viewModel.plans[section].indices {
                let indexPath = IndexPath(row: row, section: section)
                if let cell = tableView.cellForRow(at: indexPath) as? PlanCell, viewModel.shouldShowExpandButton {
                    cell.showExpandButton()
                }
            }
        }
    }

    private func showExpandButtonForDynamicPlans() {
        guard let viewModel = viewModel else { return }
        for section in viewModel.dynamicPlans.indices {
            guard viewModel.dynamicPlans.indices.contains(section) else { continue }
            for row in viewModel.dynamicPlans[section].indices {
                let indexPath = IndexPath(row: row, section: section)
                if let cell = tableView.cellForRow(at: indexPath) as? PlanCell, viewModel.shouldShowExpandButton {
                    cell.showExpandButton()
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension PaymentsUIViewController: UITableViewDataSource {

    public func numberOfSections(in tableView: UITableView) -> Int {
        if isDynamicPlansEnabled {
            return viewModel?.dynamicPlans.count ?? 0
        } else {
            return viewModel?.plans.count ?? 0
        }
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isDynamicPlansEnabled {
            return filteredCycles(at: section)?.count ?? 0
        } else {
            return viewModel?.plans[safeIndex: section]?.count ?? 0
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isDynamicPlansEnabled {
            return cellForDynamicConfig(tableView, cellForRowAt: indexPath)
        } else {
            return cellForStaticConfig(tableView, cellForRowAt: indexPath)
        }
    }

    private func cellForStaticConfig(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        guard let plan = viewModel?.plans[safeIndex: indexPath.section]?[safeIndex: indexPath.row] else { return cell }
        switch plan.planPresentationType {
        case .plan:
            cell = tableView.dequeueReusableCell(withIdentifier: PlanCell.reuseIdentifier, for: indexPath)
            if let cell = cell as? PlanCell {
                cell.delegate = self
                cell.configurePlan(plan: plan, indexPath: indexPath, isSignup: mode == .signup, isExpandButtonHidden: viewModel?.isExpandButtonHidden ?? true)
            }
            cell.selectionStyle = .none
        case .current:
            cell = tableView.dequeueReusableCell(withIdentifier: CurrentPlanCell.reuseIdentifier, for: indexPath)
            if let cell = cell as? CurrentPlanCell {
                cell.configurePlan(plan: plan)
            }
            cell.isUserInteractionEnabled = false
        }
        return cell
    }

    private func cellForDynamicConfig(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = UITableViewCell()
        guard let plan = filteredCycles(at: indexPath.section)?[safeIndex: indexPath.row] else { return cell }
        switch plan {
        case .alert(let alertBoxViewModel):
            cell = tableView.dequeueReusableCell(withIdentifier: AlertBoxCell.reuseIdentifier, for: indexPath)
            if let cell = cell as? AlertBoxCell {
                cell.configure(with: alertBoxViewModel, action: scrollToFirstAvailablePlan)
            }
        case .currentPlan(let currentPlan):
            cell = tableView.dequeueReusableCell(withIdentifier: CurrentPlanCell.reuseIdentifier, for: indexPath)
            if let cell = cell as? CurrentPlanCell {
                cell.configurePlan(currentPlan: currentPlan)
            }
            cell.isUserInteractionEnabled = false
        case .availablePlan(let availablePlan):
            cell = tableView.dequeueReusableCell(withIdentifier: PlanCell.reuseIdentifier, for: indexPath)
            if let cell = cell as? PlanCell {
                cell.delegate = self
                cell.configurePlan(availablePlan: availablePlan, indexPath: indexPath, isSignup: mode == .signup, isExpandButtonHidden: viewModel?.isExpandButtonHidden ?? true, isPurchaseButtonDisabled: viewModel?.shouldDisablePurchaseButtons ?? true)
                if indexPath.row == 0 {
                    firstAvailablePlanIndexPath = indexPath
                    firstAvailablePlanCell = cell
                }
            }
            cell.selectionStyle = .none
        }

        return cell
    }

    private func scrollToFirstAvailablePlan() {
        guard let indexPath = firstAvailablePlanIndexPath,
              let cell = firstAvailablePlanCell,
              let dynamicPlan = cell.dynamicPlan else { return }
        if !dynamicPlan.isExpanded {
            cell.selectCell()
        }
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let viewModel, viewModel.dynamicPlans.count > 1, mode == .current && section == viewModel.dynamicPlans.count - 1 else { return nil }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: sectionHeaderView)
        if let header = view as? PlanSectionHeaderView {
            header.titleLabel.text = PUITranslations.upgrade_plan_title.l10n
            header.cycleSelectorDelegate = self
            header.configureCycleSelector(cycles: cycles(at: section), selectedCycle: selectedCycle)
        }
        return view
    }
}

// MARK: - UITableViewDelegate

extension PaymentsUIViewController: UITableViewDelegate {

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let viewModel, viewModel.dynamicPlans.count > 1, mode == .current && section == viewModel.dynamicPlans.count - 1 else { return 0 }
        return UITableView.automaticDimension
    }

    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isDynamicPlansEnabled {
            guard let plan = filteredCycles(at: indexPath.section)?[safeIndex: indexPath.row] else { return }
            if case .availablePlan = plan,
               let cell = tableView.cellForRow(at: indexPath) as? PlanCell {
                cell.selectCell()
            }
        } else {
            guard let plan = viewModel?.plans[safeIndex: indexPath.section]?[safeIndex: indexPath.row] else { return }
            if case .plan = plan.planPresentationType {
                if let cell = tableView.cellForRow(at: indexPath) as? PlanCell {
                    cell.selectCell()
                }
            }
        }
    }
}

// MARK: - CycleSelectorDelegate

extension PaymentsUIViewController: CycleSelectorDelegate {
    func didSelectCycle(cycle: Int?) {
        selectedCycle = cycle
        reloadData()
    }

    private func filteredCycles(at section: Int) -> [PaymentCellType]? {
        if selectedCycle != nil {
            return viewModel?.dynamicPlans[safeIndex: section]?.filter {
                switch $0 {
                case .alert, .currentPlan:
                    return true
                case .availablePlan(let availablePlansPresentation):
                    return availablePlansPresentation.details.cycle == selectedCycle || availablePlansPresentation.details.isFreePlan
                }
            }
        } else {
            return viewModel?.dynamicPlans[safeIndex: section]
        }
    }

    private func cycles(at section: Int) -> Set<Int> {
        Set(viewModel?.dynamicPlans[safeIndex: section]?.compactMap {
            switch $0 {
            case .alert, .currentPlan:
                return nil
            case .availablePlan(let availablePlansPresentation):
                return availablePlansPresentation.details.cycle
            }
        } ?? [])
    }
}

// MARK: - PlanCellDelegate

extension PaymentsUIViewController: PlanCellDelegate {
    func cellDidChange(indexPath: IndexPath) {
        tableView.beginUpdates()
        tableView.endUpdates()
        tableView.scrollToRow(at: indexPath, at: .none, animated: true)
    }

    // Static plans
    func userPressedSelectPlanButton(plan: PlanPresentation, completionHandler: @escaping () -> Void) {
        lockUI()
        delegate?.userDidSelectPlan(plan: plan, addCredits: false) { [weak self] in
            self?.unlockUI()
            completionHandler()
        }
    }

    // Dynamic plans
    func userPressedSelectPlanButton(plan: AvailablePlansPresentation, completionHandler: @escaping () -> Void) {
        guard !(viewModel?.shouldDisablePurchaseButtons ?? true) else {
            delegate?.purchaseBecameUnavailable()
            return
        }
        lockUI()
        delegate?.userDidSelectPlan(plan: plan) { [weak self] in
            self?.unlockUI()
            completionHandler()
        }
    }
}

#endif

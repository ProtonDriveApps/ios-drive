//
//  HVHelpViewControllerForMacOS.swift
//  ProtonCore-HumanVerification - Created on 2/1/16.
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

import AppKit
import ProtonCore_CoreTranslation
import ProtonCore_UIFoundations
import ProtonCore_Foundations

protocol HVHelpViewControllerDelegate: AnyObject {
    func didDismissHelpViewController()
}

public final class HVHelpViewController: NSViewController {

    // MARK: - Outlets

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var textBackground: NSTextField!
    @IBOutlet weak var headerLabel: NSTextField!

    weak var delegate: HVHelpViewControllerDelegate?
    public var viewModel: HelpViewModel!
    
    static let cellIdentifier = NSUserInterfaceItemIdentifier(rawValue: "HVHelpViewControllerCell")

    // MARK: - View controller life cycle

    override public func viewDidLoad() {
        super.viewDidLoad()
        let cellNib = NSNib(nibNamed: "HVHelpCell", bundle: HVCommon.bundle)
        tableView.register(cellNib, forIdentifier: HVHelpViewController.cellIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        configureUI()
    }
    
    override public func viewDidAppear() {
        super.viewDidAppear()
        view.window?.styleMask = [.closable, .titled]
        view.window?.minSize = view.fittingSize
        view.window?.maxSize = view.fittingSize
    }

    // MARK: - Private Interface

    private func configureUI() {
        tableView.backgroundColor = ColorProvider.BackgroundNorm
        tableView.usesAutomaticRowHeights = true
        title = ""
        headerLabel.backgroundColor = ColorProvider.BackgroundNorm
        headerLabel.textColor = ColorProvider.TextNorm
        headerLabel.stringValue = CoreString._hv_help_header
        headerLabel.isBezeled = false
        headerLabel.isEditable = false
        headerLabel.sizeToFit()
        textBackground.backgroundColor = ColorProvider.BackgroundNorm
    }

}

// MARK: - UITableViewDataSource

extension HVHelpViewController: NSTableViewDataSource {
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.helpMenuItems.count
    }
    
    public func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        viewModel.helpMenuItems[row]
    }
}

// MARK: - UITableViewDelegate

extension HVHelpViewController: NSTableViewDelegate {
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: HVHelpViewController.cellIdentifier,
                                      owner: self) as! HVHelpCell
        cell.update(with: viewModel.helpMenuItems[row])
        return cell
    }
    
    public func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0 else { return }
        let item = viewModel.helpMenuItems[row]
        tableView.deselectRow(row)
        guard let url = item.url else { return }
        NSWorkspace.shared.open(url)
    }
}

extension HVHelpViewController: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        delegate?.didDismissHelpViewController()
    }
}

final class HVHelpCell: NSTableCellView {
 
    @IBOutlet var icon: NSImageView!
    @IBOutlet var title: NSTextField!
    @IBOutlet var subtitle: NSTextField!
    @IBOutlet var arrow: NSImageView!
    
    var observation: NSKeyValueObservation?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUpObservation()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpObservation()
    }
    
    private func setUpObservation() {
        observation = observe(\.objectValue) { myself, value in
            guard let item = value.newValue as? HelpViewModel.HumanItem else { return }
            myself.update(with: item)
        }
    }
    
    func update(with item: HelpViewModel.HumanItem) {
        icon.image = item.image
        arrow.image = IconProvider.arrowRight
        title.stringValue = item.title
        subtitle.stringValue = item.subtitle
        title.sizeToFit()
        subtitle.sizeToFit()
    }
}

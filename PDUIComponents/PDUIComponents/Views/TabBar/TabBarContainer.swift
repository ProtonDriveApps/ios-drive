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
import ProtonCoreUIFoundations

#if os(iOS)
public struct TabBarContainer: View {
    public init(vm: TabBarViewViewModel, tabItems: [TabItem]) {
        self.vm = vm
        self.items = tabItems
    }
    
    @ObservedObject private var vm: TabBarViewViewModel
    @EnvironmentObject private var root: RootViewModel
    private let items: [TabItem]

    public var body: some View {
        // native TabView reloads the NavigationViews every time you open in on iOS 13 - known issue that is fixed in iOS 14
        // however, even on iOS 14 TabView does not allow hiding the bar, so we resort to the Legacy one for the time being
        UITabBarControllerWrapper(isHidden: $vm.isTabBarHidden, currentTab: $vm.currentTab, activateTab: $vm.activateTab, items: items.map(\.viewModel)) {
            items.map { $0.view.environmentObject(vm).environmentObject(root) }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
/// Setup of UIKit's UITabBarController that lays inside the SwiftUI view
private struct UITabBarControllerWrapper<Content>: UIViewControllerRepresentable where Content: View {
    typealias ViewModel = NavigationBarButtonViewModel
    
    @Binding var isHidden: Bool
    @Binding var currentTab: ViewModel
    @Binding var activateTab: ViewModel
    
    var items: [ViewModel]
    var content: () -> [Content]

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        
        // style
        self.setupTabBarImages(tabBarController.tabBar)
        self.setupTabBarTypography()

        // create and install view controllers
        let controllers: [UIHostingController<Content>] = zip(items, content()).map { viewModel, view in
            let vc = UIHostingController(rootView: view)
            vc.edgesForExtendedLayout = .bottom
            vc.extendedLayoutIncludesOpaqueBars = true

            let image = UIImage(named: viewModel.iconName)
            let selectedImage = UIImage(named: viewModel.selectedIconName)
            vc.tabBarItem = UITabBarItem(title: viewModel.title, image: image, selectedImage: selectedImage)
            
            return vc
        }
        tabBarController.setViewControllers(controllers, animated: false)
        return tabBarController
    }

    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        // pre-rendered color changes when we switch dark mode on
        self.setupTabBarImages(uiViewController.tabBar)
        
        // VM needs to track this value for state restoration
        self.currentTab = .init(rawValue: uiViewController.selectedIndex) ?? .automatic
        
        // VM enforces selection during deeplinking, but only once
        if currentTab != activateTab, activateTab != .automatic {
            uiViewController.selectedIndex = activateTab.id
            activateTab = .automatic
        }
        
        uiViewController.tabBar.isHidden = isHidden // hides and unhides UITabBar
        uiViewController.selectedViewController?.additionalSafeAreaInsets = .init(top: 0, left: 0, bottom: isHidden ? -uiViewController.tabBar.bounds.height : 0, right: 0) // adjust safe area when UITabBar is hidden
    }
    
    private func setupTabBarImages(_ tabBar: UITabBar) {
        // a trick to force UITabBarController keep layout of as if the bar was transculent,
        // but neglect transparency at the same time
        if #available(iOS 15.0, *) {
            tabBar.backgroundImage = UIImage.fromColor(.clear)
            tabBar.shadowImage = UIImage.fromColor(ColorProvider.SeparatorNorm)
        }
        
        tabBar.isTranslucent = true

        // real colors that are rendered
        tabBar.backgroundColor = ColorProvider.BackgroundNorm
        tabBar.barTintColor = ColorProvider.BackgroundNorm
        tabBar.tintColor = ColorProvider.BrandNorm
    }
    
    private func setupTabBarTypography() {
        let appearance = UITabBarItem.appearance()
        let attributes: [NSAttributedString.Key: AnyObject] = [.font: UIFont.preferredFont(forTextStyle: .caption2)]
        
        var normalAttributes = attributes
        normalAttributes[.foregroundColor] = ColorProvider.TextWeak as UIColor
        appearance.setTitleTextAttributes(normalAttributes, for: .normal)
        
        var selectedAttributes = attributes
        selectedAttributes[.foregroundColor] = ColorProvider.BrandNorm as UIColor
        appearance.setTitleTextAttributes(selectedAttributes, for: .selected)
    }
}

// MARK: - Previews

struct TabBarContainer_Previews: PreviewProvider {
    static var vm = TabBarViewViewModel(initialTab: .files)
    static var children: [TabItem] = [
        .init(tab: .files, content: AnyView(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))),
        .init(tab: .favorites, content: AnyView(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))),
        .init(tab: .recent, content: AnyView(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all))),
        .init(tab: .sharing, content: AnyView(ColorProvider.BackgroundNorm.edgesIgnoringSafeArea(.all)))
    ]
    
    static var previews: some View {
        Group {
            TabBarContainer(vm: vm, tabItems: children)
            .previewDevice(.init("iPhone 8"))
            
            TabBarContainer(vm: vm, tabItems: children)
            .previewDevice(.init("iPhone 11"))
            
            TabBarContainer(vm: vm, tabItems: children)
            .previewDevice(.init("iPad8,1"))
        }
    }
}

private extension UIImage {
    class func fromColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)

        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()

        context!.setFillColor(color.cgColor)
        context!.fill(rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image!
    }
}
#endif

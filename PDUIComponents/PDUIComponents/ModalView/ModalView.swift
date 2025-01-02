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

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public enum PresentationStyle {
    case fullScreenWithBlender, fullScreenWithoutBlender, sheet
}

extension PresentationStyle {
    var style: UIModalPresentationStyle {
        switch self {
        case .fullScreenWithBlender, .fullScreenWithoutBlender:
            return .overFullScreen
        case .sheet:
            return .automatic
        }
    }
}

extension View {
    public func presentView<Content>(isPresented: Binding<Bool>, style: PresentationStyle = .sheet, @ViewBuilder content: @escaping () -> Content) -> some View where Content: View {
        self.modifier(PresentModifier(isPresented: isPresented, addition: content, presentationStyle: style))
    }
    
    public func presentView<Content>(isPresented: Binding<Bool>, style: PresentationStyle = .sheet, content: @escaping () -> Content) -> some View where Content: UIViewController {
        self.modifier(UIPresentModifier(isPresented: isPresented, addition: content, presentationStyle: style))
    }

    public func presentView<Item, Content>(item: Binding<Item?>, style: PresentationStyle = .sheet, @ViewBuilder content: @escaping (Item) -> Content) -> some View where Item: Identifiable, Content: View {
        self.modifier(PresentModifierItem(item: item, addition: content, presentationStyle: style))
    }
}

private struct PresentModifier<Addition: View>: ViewModifier {
    @Binding var isPresented: Bool
    var addition: () -> Addition
    let presentationStyle: PresentationStyle

    func body(content: Content) -> some View {
        content
            .background(ZStack {
                if isPresented {
                    ViewControllerContainer(isPresented: $isPresented, presentationStyle: presentationStyle, content: UIHostingController(rootView: addition()))
                }
            })
    }
}

private struct UIPresentModifier<Addition: UIViewController>: ViewModifier {
    @Binding var isPresented: Bool
    var addition: () -> Addition
    let presentationStyle: PresentationStyle

    func body(content: Content) -> some View {
        content
            .background(ZStack {
                if isPresented {
                    ViewControllerContainer(isPresented: $isPresented, presentationStyle: presentationStyle, content: addition())
                }
            })
    }
}

private struct PresentModifierItem<Addition: View, Item: Identifiable>: ViewModifier {
    @Binding var item: Item?
    var addition: (Item) -> Addition
    let presentationStyle: PresentationStyle

    func body(content: Content) -> some View {
        content
            .background(ZStack {
                if item != nil {
                    let binding = Binding(get: { item != nil },
                                          set: { new in DispatchQueue.main.async { item = new ? item : .none } })
                    ViewControllerContainer(isPresented: binding, presentationStyle: presentationStyle, content: UIHostingController(rootView: addition(item!)))
                }
            })
    }
}

private struct ViewControllerContainer: UIViewControllerRepresentable {
    typealias Context = UIViewControllerRepresentableContext<ViewControllerContainer>

    @Binding var isPresented: Bool
    let presentationStyle: PresentationStyle
    let content: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        let child = content
        child.presentationController?.delegate = context.coordinator
        if self.presentationStyle == .fullScreenWithBlender {
            child.transitioningDelegate = context.coordinator
        }
        
        let proxyViewController = ProxyViewController()
        proxyViewController.child = child
        
        context.coordinator.proxyViewController = proxyViewController
        return proxyViewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        (uiViewController as! ProxyViewController).child?.dismiss(animated: true) {
                coordinator.container.isPresented = false
                coordinator.content.dismiss(animated: true, completion: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(container: self, presentationStyle: presentationStyle)
    }
}

extension ViewControllerContainer {
    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate, UIViewControllerTransitioningDelegate {
        let container: ViewControllerContainer
        var proxyViewController: UIViewController?
        private let presentationStyle: PresentationStyle
        
        init(container: ViewControllerContainer, presentationStyle: PresentationStyle) {
            self.container = container
            self.presentationStyle = presentationStyle
        }

        var content: UIViewController {
            container.content
        }
        
        func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            FadeInAnimation()
        }
        
        func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
            FadeOutAnimation()
        }

        func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
            presentationStyle.style
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            false
        }
    }
}

extension ViewControllerContainer {
    final class ProxyViewController: UIViewController {
        var presentationStyle: UIModalPresentationStyle?
        var child: UIViewController?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            child?.modalPresentationStyle = self.presentationStyle ?? .automatic

            if let child = child {
                self.present(child, animated: true, completion: nil)
            }
        }
    }
}
#endif

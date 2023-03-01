//
//  LinkButton.swift
//  PDUIComponents
//
//  Created by Jan Halousek on 01.02.2023.
//

import SwiftUI
import ProtonCore_UIFoundations

#if os(iOS)
public struct LinkButton: View {
    let title: String
    let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
        }
        .buttonStyle(BrandButtonStyle())
    }
}
#endif

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
import ProtonCoreUIFoundations

public struct ErrorToastModifier: ViewModifier {
    public typealias Stream = PassthroughSubject<Error?, Never>

    public enum Location {
        case top, bottom, bottomWithOffset(CGFloat)
        
        var edge: Edge {
            switch self {
            case .top: return .top
            case .bottom, .bottomWithOffset: return .bottom
            }
        }
        func verticalPadding(_ keyboardOverflow: CGFloat = 0) -> EdgeInsets {
            switch self {
            case .top: return .init(top: 32.0, leading: 0, bottom: 0, trailing: 0)
            case .bottom: return .init(top: 0.0, leading: 0.0, bottom: keyboardOverflow, trailing: 0.0)
            case .bottomWithOffset(let offset): return .init(top: 0.0, leading: 0.0, bottom: keyboardOverflow + offset, trailing: 0.0)
            }
        }
    }
    
    var location: Location
    @State var foregroundColor: Color
    @State var backgroundColor: Color
    var label: AnyView
    var source: Stream
    @State private var errorMessage: String?
    @State private var keyboardOverflow: CGFloat = 0
    
    public func body(content: Content) -> some View {
        ZStack {
            content
            
            VStack {
                if self.location.edge == .bottom {
                    Spacer()
                }
                
                if self.errorMessage != nil {
                    RectangleToast(message: self.errorMessage!,
                                   foregroundColor: self.foregroundColor,
                                   backgroundColor: self.backgroundColor) {
                        self.label
                    }
                    .transition(.move(edge: self.location.edge))
                    .padding(self.location.verticalPadding(self.keyboardOverflow))
                    .padding(.horizontal)
                }
                
                if self.location.edge == .top {
                    Spacer()
                }
            }
            .animation(.linear(duration: 0.2))
            .onReceive(self.source) { message in
                self.errorMessage = message?.localizedDescription
            }
            .onReceive(Publishers.keyboardRect) { keyboard in
                self.keyboardOverflow = keyboard.height
            }
        }
    }
}

struct ErrorToastViewModifiers_Previews: PreviewProvider {
    static var errors = ErrorToastModifier.Stream()
    
    static var previews: some View {
        Group {            
            Spacer()
                .frame(width: 300, height: 300)
                .errorToast(errors: self.errors)
        }
        .previewLayout(.sizeThatFits)
        .onAppear {
            self.errors.send(NSError(domain: "THE ERROR MESSAGE MAY BE VERY LONG AND EVEN MULTILINE", code: 1, userInfo: nil))
        }
    }
}

extension View {
    private func errorToast<Content: View>(
        location: ErrorToastModifier.Location,
        foregroundColor: Color = Color.white,
        backgroundColor: Color? = nil,
        errors: ErrorToastModifier.Stream,
        @ViewBuilder label: () -> Content
    ) -> some View {
        let backgroundColor = backgroundColor ?? Color.NotificationError
        return ModifiedContent(content: self, modifier: ErrorToastModifier(location: location, foregroundColor: foregroundColor, backgroundColor: backgroundColor, label: label().any(), source: errors))
    }
    
    public func errorToast(
        location: ErrorToastModifier.Location = .top,
        errors: ErrorToastModifier.Stream
    ) -> some View {
        self.errorToast(location: location, errors: errors) {
            Button(action: {
                errors.send(nil)
            }, label: {
                Text("OK")
                    .foregroundColor(.white)
                    .background(
                        Rectangle()
                            .foregroundColor(.white.opacity(0.2))
                            .frame(width: 46, height: 36)
                            .cornerRadius(2)
                    )
                    .frame(width: 48, height: 48)
                    .padding(.trailing)
            })
            .accessibility(identifier: "ErrorToastModifier.errorToast.Error_button")
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    public func retryError(
        action: @escaping () -> Void,
        errors: ErrorToastModifier.Stream
    ) -> some View {
        self.errorToast(location: .bottom, errors: errors) {
            Button(action: {
                action()
                errors.send(nil)
            }, label: {
                Text("Retry")
                    .foregroundColor(.white)
                    .background(
                        Rectangle()
                            .foregroundColor(.white.opacity(0.2))
                            .frame(width: 52, height: 36)
                            .cornerRadius(2)
                    )
                    .frame(width: 54, height: 48)
                    .padding(.horizontal)
            })
            .accessibility(identifier: "ErrorToastModifier.errorToast.Error_button")
            .buttonStyle(PlainButtonStyle())
        }
    }
}

public final class ErrorRegulator {
    public typealias Output = Error?

    private(set) var lastValue: Output
    private var cancellable: Cancellable?

    // Maybe we should have a concrete number of error types for UI events
    public let stream = ErrorToastModifier.Stream()
    private let regulator: CurrentValueSubject<Output, Never>

    public init(initialValue: Output = nil) {
        self.lastValue = initialValue
        self.regulator = .init(initialValue)

        cancellable = regulator
            .receive(on: DispatchQueue.main)
            .handleEvents(receiveOutput: { [weak self] error in
                self?.stream.send(error)
            })
            .delay(for: 3, scheduler: RunLoop.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] error in
                    guard
                        error?.localizedDescription == self?.lastValue?.localizedDescription else { return }
                    self?.stream.send(nil)
                  })
    }

    public func send(_ value: Output) {
        lastValue = value
        regulator.send(value)
    }
}

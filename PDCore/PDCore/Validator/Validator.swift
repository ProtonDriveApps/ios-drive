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

import Foundation

public struct Validator<T> {
    public let validate: (T) -> [ValidationError<T>]

    public init(validate: @escaping (T) -> [ValidationError<T>]) {
        self.validate = validate
    }
}

public struct ValidationError<T>: Error, Equatable {
    public let location: PartialKeyPath<T>
    public let message: String

    public init(location: PartialKeyPath<T>, message: String) {
        self.location = location
        self.message = message
    }
    
}

extension ValidationError: LocalizedError {
    public var errorDescription: String? {
        message
    }
}

extension Validator {
    public init<Value>(_ keyPath: KeyPath<T, Value>, where condition: @escaping (Value) -> Bool, message: String) {
        validate = { t in
            guard condition(t[keyPath: keyPath]) else {
                return [ValidationError(location: keyPath, message: message)]
            }
            return []
        }
    }

    public init<Value: Collection>(nonEmpty keyPath: KeyPath<T, Value>) {
        validate = { t in
            guard !t[keyPath: keyPath].isEmpty else {
                return [ValidationError(location: keyPath, message: "Expected non-empty value")]
            }
            return []
        }
    }

    public init<Value: Collection>(contains keyPath: KeyPath<T, Value>, where condition: @escaping (Value.Element) -> Bool, message: String) {
        validate = { t in
            guard t[keyPath: keyPath].contains(where: condition) else {
                return [ValidationError(location: keyPath, message: message)]
            }
            return []
        }
    }

    public init(combining validators: [Validator<T>]) {
        validate = { t in
            validators.flatMap { $0.validate(t) }
        }
    }

    public func lift<Target>(_ keyPath: KeyPath<Target, T>) -> Validator<Target> {
        return Validator<Target> { target in
            let errors = validate(target[keyPath: keyPath])
            return errors.map { error in
                let kp = keyPath as PartialKeyPath<Target>
                let newLocation = kp.appending(path: error.location)!
                return ValidationError(location: newLocation, message: error.message)
            }
        }
    }

    public func with(message: String) -> Validator<T> {
        return Validator { t in
            let errors = validate(t)
            return errors.map { error in
                ValidationError(location: error.location, message: message)
            }
        }
    }
}

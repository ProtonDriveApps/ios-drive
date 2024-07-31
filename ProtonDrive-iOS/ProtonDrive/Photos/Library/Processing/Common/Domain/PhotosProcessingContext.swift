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

import PDCore

protocol PhotosProcessingContext {
    var initialIdentifiers: Set<PhotoIdentifier> { get }
    var validIdentifiers: Set<PhotoIdentifier> { get }
    var invalidIdentifiers: Set<PhotoIdentifier> { get }
    var failedIdentifiers: Set<PhotoIdentifier> { get }
    var missingIdentifiers: Set<PhotoIdentifier> { get }
    var skippedIdentifiers: Set<PhotoIdentifier> { get }
    var newIdentifiers: Set<PhotoIdentifier> { get }
    var duplicatedCompoundIdentifiers: [PhotoIdentifier] { get }
    var importedCompoundsCount: Int { get }
    var importedCompoundsDeltaCount: Int { get }
    var createdCompounds: [PhotoAssetCompound] { get }
    var validatedCompounds: [PhotoAssetCompoundType] { get }
    var invalidAssets: [PhotoAsset] { get }
    var errors: [Error] { get }
    func completeIdentifiersValidation(identifiers: PhotoIdentifiers)
    func addCreated(compounds: [PhotoAssetCompound], identifier: PhotoIdentifier)
    func completeCompoundsCreation()
    func addGenericError(identifier: PhotoIdentifier, error: Error)
    func addTemporaryError(identifier: PhotoIdentifier, error: Error)
    func addMissing(identifier: PhotoIdentifier)
    func replace(initialIdentifier: PhotoIdentifier, updatedIdentifier: PhotoIdentifier)
    func completeCompoundsValidation(result: FilteredPhotoCompoundsResult)
    func failValidation(compounds: [PhotoAssetCompound], error: Error)
    func completeImport()
    func failProcessing(compounds: [PhotoAssetCompoundType], error: Error)
    func fetchDuplicatedCompounds(by identifier: PhotoIdentifier) -> [PhotoAssetCompound]
}

final class ConcretePhotosProcessingContext: PhotosProcessingContext {
    private struct IdentifierCompoundPair {
        let identifier: PhotoIdentifier
        let compound: PhotoAssetCompound
    }

    private struct IdentifierCompoundTypePair {
        let identifier: PhotoIdentifier
        let compound: PhotoAssetCompoundType
    }

    let initialIdentifiers: Set<PhotoIdentifier>
    private(set) var validIdentifiers: Set<PhotoIdentifier> = []
    private(set) var invalidIdentifiers: Set<PhotoIdentifier> = []
    private(set) var failedIdentifiers: Set<PhotoIdentifier> = []
    private(set) var missingIdentifiers: Set<PhotoIdentifier> = []
    private(set) var skippedIdentifiers: Set<PhotoIdentifier> = []
    private var replacedIdentifiers = [PhotoIdentifier: PhotoIdentifier]()
    private(set) var duplicatedCompoundIdentifiers: [PhotoIdentifier] = []
    private var duplicatedCompounds: [PhotoIdentifier: [PhotoAssetCompound]] = [:]
    
    private var createdCompoundPairs = [IdentifierCompoundPair]()
    private var validatedCompoundPairs = [IdentifierCompoundTypePair]()
    private var importedCompoundPairs = [IdentifierCompoundTypePair]()
    private(set) var invalidAssets: [PhotoAsset] = []
    private(set) var errors: [Error] = []

    var newIdentifiers: Set<PhotoIdentifier> {
        Set(replacedIdentifiers.values)
    }

    var createdCompounds: [PhotoAssetCompound] {
        createdCompoundPairs.map(\.compound)
    }

    var validatedCompounds: [PhotoAssetCompoundType] {
        validatedCompoundPairs.map(\.compound)
    }

    var importedCompoundsCount: Int {
        importedCompoundPairs.count
    }

    var importedCompoundsDeltaCount: Int {
        importedCompoundsCount - Set(importedCompoundPairs.map(\.identifier)).count
    }

    init(initialIdentifiers: Set<PhotoIdentifier>) {
        self.initialIdentifiers = initialIdentifiers
    }

    func completeIdentifiersValidation(identifiers: PhotoIdentifiers) {
        Log.info("\(Self.self).completeIdentifiersValidation, count: \(identifiers.count)", domain: .photosProcessing)
        validIdentifiers = Set(identifiers)
        invalidIdentifiers = initialIdentifiers.subtracting(validIdentifiers)
    }

    func addCreated(compounds: [PhotoAssetCompound], identifier: PhotoIdentifier) {
        Log.info("\(Self.self).addCreated, count: \(compounds.count)", domain: .photosProcessing)
        compounds.forEach { compound in
            createdCompoundPairs.append(IdentifierCompoundPair(identifier: identifier, compound: compound))
        }
    }

    func completeCompoundsCreation() {
        Log.info("\(Self.self).completeCompoundsCreation", domain: .photosProcessing)
        let processedIdentifiers = createdCompoundPairs.map(\.identifier) + failedIdentifiers + skippedIdentifiers + missingIdentifiers + replacedIdentifiers.keys
        let newSkippedIdentifiers = Set(validIdentifiers).subtracting(processedIdentifiers)
        skippedIdentifiers.formUnion(newSkippedIdentifiers)
    }

    func addGenericError(identifier: PhotoIdentifier, error: Error) {
        Log.error(error, domain: .photosProcessing)
        failedIdentifiers.insert(identifier)
        errors.append(error)
    }

    func addTemporaryError(identifier: PhotoIdentifier, error: Error) {
        Log.info("\(Self.self).addTemporaryError: \(error.localizedDescription)", domain: .photosProcessing)
        skippedIdentifiers.insert(identifier)
    }

    func addMissing(identifier: PhotoIdentifier) {
        Log.info("\(Self.self).addMissing", domain: .photosProcessing)
        missingIdentifiers.insert(identifier)
    }

    func replace(initialIdentifier: PhotoIdentifier, updatedIdentifier: PhotoIdentifier) {
        Log.info("\(Self.self).replace", domain: .photosProcessing)
        replacedIdentifiers[initialIdentifier] = updatedIdentifier
    }

    func completeCompoundsValidation(result: FilteredPhotoCompoundsResult) {
        Log.info("\(Self.self).completeCompoundsValidation, validCompounds: \(result.validCompounds.count), validPartialCompounds: \(result.validPartialCompounds.count), invalidCompounds: \(result.invalidCompounds.count), failedCompounds: \(result.failedCompounds.count)", domain: .photosProcessing)
        var validIdentifiers = Set<PhotoIdentifier>()
        result.validCompounds.forEach { compound in
            guard let pair = createdCompoundPairs.first(where: { $0.compound == compound }) else { return }
            validIdentifiers.insert(pair.identifier)
            let typePair = IdentifierCompoundTypePair(identifier: pair.identifier, compound: .new(pair.compound))
            validatedCompoundPairs.append(typePair)
        }
        result.validPartialCompounds.forEach { partialCompound in
            guard let pair = createdCompoundPairs.first(where: { $0.compound == partialCompound.originalCompound }) else { return }
            validIdentifiers.insert(pair.identifier)
            let typePair = IdentifierCompoundTypePair(identifier: pair.identifier, compound: .existing(linkID: partialCompound.primaryLinkId, secondary: partialCompound.secondary))
            validatedCompoundPairs.append(typePair)
        }
        result.invalidCompounds.forEach { compound in
            guard let pair = createdCompoundPairs.first(where: { $0.compound == compound }) else { return }
            invalidAssets += compound.allAssets
            duplicatedCompoundIdentifiers.append(pair.identifier)
            var compounds = duplicatedCompounds[pair.identifier] ?? []
            compounds.append(compound)
            duplicatedCompounds[pair.identifier] = compounds
            if !validIdentifiers.contains(pair.identifier) {
                invalidIdentifiers.insert(pair.identifier)
            }
        }
        invalidAssets += result.invalidAssets
        result.failedCompounds.forEach { compound in
            guard let pair = createdCompoundPairs.first(where: { $0.compound == compound }) else { return }
            failedIdentifiers.insert(pair.identifier)
            skippedIdentifiers.remove(pair.identifier)
        }
    }

    func failValidation(compounds: [PhotoAssetCompound], error: Error) {
        Log.error(error, domain: .photosProcessing)
        compounds.forEach { compound in
            guard let pair = createdCompoundPairs.first(where: { $0.compound == compound }) else { return }
            invalidAssets += compound.allAssets
            skippedIdentifiers.insert(pair.identifier)
        }
    }

    func completeImport() {
        Log.info("\(Self.self).completeImport, count: \(validatedCompoundPairs.count)", domain: .photosProcessing)
        importedCompoundPairs = validatedCompoundPairs
    }

    func failProcessing(compounds: [PhotoAssetCompoundType], error: Error) {
        let error = DriveError(withDomainAndCode: error)
        Log.error(error, domain: .photosProcessing)
        invalidAssets += compounds.flatMap(\.allAssets)
        errors.append(error)
        let failedIdentifiers = validatedCompoundPairs.filter { compounds.contains($0.compound) }.map(\.identifier)
        self.failedIdentifiers.formUnion(failedIdentifiers)
    }
    
    func fetchDuplicatedCompounds(by identifier: PhotoIdentifier) -> [PhotoAssetCompound] {
        duplicatedCompounds[identifier] ?? []
    }
}

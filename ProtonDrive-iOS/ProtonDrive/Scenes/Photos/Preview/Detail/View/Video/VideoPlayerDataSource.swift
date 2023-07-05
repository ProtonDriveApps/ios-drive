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

import AVKit

final class PlayerDataSource: ObservableObject {
    let player: AVPlayer
    private let item: AVPlayerItem
    private var observers = [NSKeyValueObservation]()

    init(url: URL) {
        item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
    }

    func addObservers() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil) { [weak self] _ in
            self?.player.seek(to: .zero)
        }
        let statusObserver = item.observe(\AVPlayerItem.status) { [weak self] playerItem, _ in
            guard playerItem.status == .readyToPlay else { return }
            self?.player.play()
        }
        let boundsObserver = item.observe(\AVPlayerItem.presentationSize) { [weak self] _, _ in
            guard let self = self else { return }
            self.objectWillChange.send()
        }
        observers = [statusObserver, boundsObserver]
    }

    func removeObservers() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        observers.forEach { $0.invalidate() }
        observers = []
    }

    func getSize(from size: CGSize) -> CGSize {
        let contentSize = item.presentationSize
        guard size != .zero && contentSize != .zero else {
            return .zero
        }

        let ratio = min(size.width / contentSize.width, size.height / contentSize.height)
        return CGSize(width: contentSize.width * ratio, height: contentSize.height * ratio)
    }
}

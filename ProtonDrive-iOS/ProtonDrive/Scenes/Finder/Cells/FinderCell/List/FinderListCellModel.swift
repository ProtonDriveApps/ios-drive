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

enum FinderListSeparator {
    case divider
    case progressing(progress: Double)
}

extension NodeCellConfiguration {
    var separator: FinderListSeparator {
        isInProgress ? .progressing(progress: progressCompleted) : .divider
    }

    var secondLine: NodeListSecondLine {
        NodeListSecondLine(figure: figure, subtitle: secondLineSubtitle, isFailedStyle: (uploadFailed && !uploadPaused))
    }

    private var figure: SecondLineFigure {
        if isInProgress && progressDirection == .downstream {
            return .spinner
        } else if isInProgress && progressDirection == .upstream {
            return .uploadSpinner
        } else if uploadPaused {
            return .paused
        } else if uploadFailed {
            return .warning
        } else if uploadWaiting {
            return .spinner
        } else {
            var badges: [Badge] = []

            if !isDownloaded && nodeType == .file {
                badges.append(.cloud)
            }

            if isFavorite {
                badges.append(.favorite)
            }

            if isSavedForOffline {
                badges.append(.offline(downloaded: isDownloaded))
            }

            if isShared {
                badges.append(.shared)
            }

            return .badges(badges)
        }
    }

    var isSelecting: Bool {
        selectionModel?.isMultipleSelectionEnabled ?? false
    }

    var isSelected: Bool {
        selectionModel?.isSelected(id: id) ?? false
    }
}

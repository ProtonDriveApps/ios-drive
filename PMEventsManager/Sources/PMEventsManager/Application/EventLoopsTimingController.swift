// Copyright (c) 2024 Proton AG
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

/// Different event loops have different timing based on their ownership & state.
/// This api creates a single interface for maintaining track of all the loops.
public protocol EventLoopsTimingController {
    /// Interval in which to check for execution
    func getInterval() -> Double
    /// Check which loops are permitted to execute
    /// The api accepts filtered loops to allow legacy implementation
    func getReadyLoops(possible: [LoopID]) -> [LoopID]
    /// Mark the execution to allow time anchoring
    func setExecutedLoops(loopIds: [LoopID])
}

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
import SwiftUI

/*
 DATE STAMPS ———
 less then 2 min:
    just now
 more then 2 min
    2 min ago
    55 min ago
 more than 1 hour
    1 h ago
    4 h ago
    18 h ago
 more than one day
    yesterday
 Older then yesterday:
    Mon DD, e.g. Sep 15
 Older than this year:
    MM.YY, e.g. Sep 2017
 
 */
public enum DateStamper {
    static var relativeDateFormatterNumbers: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
    
    static var relativeDateFormatterNames: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .spellOut
        return formatter
    }()
    
    static var mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.setLocalizedDateFormatFromTemplate("MMMdd")
        return formatter
    }()
    
    static var fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    public static func stamp(for lastModified: Date) -> String {
        let whenUpdated = Calendar.current.dateComponents([.minute, .day, .year],
                                                          from: lastModified,
                                                          to: Date())
        switch whenUpdated {
        case let x where x.year ?? 0 > 0:
            return fullDateFormatter.string(for: lastModified) ?? ""
        
        case let x where x.day ?? 0 > 1,
            let x where x.month ?? 0 > 0:
            return mediumDateFormatter.string(for: lastModified) ?? ""
            
        case let x where x.day ?? 0 == 1:
            return relativeDateFormatterNames.localizedString(for: lastModified, relativeTo: Date())
            
        case let x where x.hour ?? 0 > 0,
             let x where x.minute ?? 0 > 2:
            return relativeDateFormatterNumbers.localizedString(for: lastModified, relativeTo: Date())
    
        default: return "just now"
        }
    }
}

struct DefaultSecondLineSubtitle_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Text(DateStamper.stamp(for: Date()))
            
            Text(DateStamper.stamp(for: Calendar.current.date(byAdding: DateComponents(minute: -3), to: Date())!))
            
            Text(DateStamper.stamp(for: Calendar.current.date(byAdding: DateComponents(hour: -2), to: Date())!))
            
            Text(DateStamper.stamp(for: Calendar.current.date(byAdding: DateComponents(day: -1, hour: -2), to: Date())!))
            
            Text(DateStamper.stamp(for: Calendar.current.date(byAdding: DateComponents(day: -3), to: Date())!))
            
            Text(DateStamper.stamp(for: Calendar.current.date(byAdding: DateComponents(year: -1), to: Date())!))
        }
        .previewLayout(.sizeThatFits)
    }
}

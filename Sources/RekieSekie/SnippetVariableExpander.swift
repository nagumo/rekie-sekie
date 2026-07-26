import Foundation

/// スニペット本文中の {date} {time} {datetime} を、貼り付け時点の日時に置き換える。
enum SnippetVariableExpander {
    static func expand(_ template: String, now: Date = Date()) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"

        let datetimeFormatter = DateFormatter()
        datetimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var result = template
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: now))
        result = result.replacingOccurrences(of: "{time}", with: timeFormatter.string(from: now))
        result = result.replacingOccurrences(of: "{datetime}", with: datetimeFormatter.string(from: now))
        return result
    }
}

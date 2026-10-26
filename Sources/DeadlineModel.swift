import Foundation

struct Deadline: Identifiable {
    // A revised due date keeps the user's priority for the same named deliverable.
    var id: String { stableID ?? title }
    let date: Date
    let isoDate: String
    let time: String
    let title: String
    let detail: String
    var stableID: String? = nil
}

enum DeadlineModel {
    static func nextMorning(after date: Date, calendar: Calendar = .current) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 9, minute: 0, second: 0),
                          matchingPolicy: .nextTime)!
    }

    static func parseDate(_ text: String, calendar: Calendar = .current) -> Date? {
        guard text.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let result = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.year, from: result) == parts[0],
              calendar.component(.month, from: result) == parts[1],
              calendar.component(.day, from: result) == parts[2] else { return nil }
        return result
    }

    static func cells(_ line: String) -> [String] {
        // Obsidian [[path|label]] is a single cell, not two Markdown table cells.
        var cells: [String] = [], current = "", brackets = 0, escaped = false
        for char in line.trimmingCharacters(in: .whitespaces) {
            if escaped { current.append(char); escaped = false; continue }
            if char == "\\" { escaped = true; current.append(char); continue }
            if char == "[" { brackets += 1 }
            if char == "]" { brackets = max(0, brackets - 1) }
            if char == "|" && brackets == 0 { cells.append(current); current = "" }
            else { current.append(char) }
        }
        cells.append(current)
        return cells.dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func parse(_ markdown: String, calendar: Calendar = .current) throws -> [Deadline] {
        var records: [Deadline] = [], sawHeader = false, inTable = false
        for line in markdown.components(separatedBy: .newlines) {
            if line.hasPrefix("| Due date |") { sawHeader = true; inTable = true; continue }
            guard inTable else { continue }
            if !line.hasPrefix("|") { inTable = false; continue }
            let fields = cells(line)
            if fields.first?.hasPrefix("---") == true { continue }
            guard fields.count == 4, let date = parseDate(fields[0], calendar: calendar), !fields[2].isEmpty else {
                throw ModelError.message("Could not read deadline table row: \(line)")
            }
            let pattern = #"\s*<!-- desk-id: ([A-Za-z0-9-]+) -->"#
            let regex = try NSRegularExpression(pattern: pattern)
            let ns = fields[2] as NSString
            let match = regex.firstMatch(in: fields[2], range: NSRange(location: 0, length: ns.length))
            let stableID = match.map { ns.substring(with: $0.range(at: 1)) }
            let title = fields[2].replacingOccurrences(of: pattern, with: "", options: .regularExpression)
            records.append(Deadline(date: date, isoDate: fields[0], time: fields[1], title: title, detail: fields[3], stableID: stableID))
        }
        guard sawHeader else { throw ModelError.message("In the wiki, ‘Due date / Time / Item / Deliverables’ table not found.") }
        guard Set(records.map(\.id)).count == records.count else {
            throw ModelError.message("Duplicate deadline names. Use distinct titles.")
        }
        return records
    }

    static func upcoming(_ deadlines: [Deadline], now: Date, priorities: [String: Int],
                         completed: Set<String>, sort: String, calendar: Calendar = .current) -> [Deadline] {
        let today = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .month, value: 1, to: today)!
        return deadlines.filter { $0.date >= today && $0.date <= end && !completed.contains($0.id) }.sorted {
            let p1 = rank($0, priorities: priorities, sort: sort)
            let p2 = rank($1, priorities: priorities, sort: sort)
            if p1 != p2 { return p1 < p2 }
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.title < $1.title
        }
    }

    static func rank(_ d: Deadline, priorities: [String: Int], sort: String) -> Int {
        if sort == "date" { return 0 }
        if let chosen = priorities[d.id] { return chosen }
        guard sort == "category" else { return 4 }
        if d.title.contains("Peer review") { return 5 }
        if d.title.contains("R&R") { return 1 }
        if ["Grant", "Fellows", "Release", "Released"].contains(where: d.title.contains) { return 2 }
        if d.title.contains("Congress") { return 4 }
        if ["Informetrics", "Psychology Quarterly", "Organization Science", "Special issue"].contains(where: d.title.contains) { return 3 }
        return 6
    }

    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: #"\[\[[^\]|]+\|([^\]]+)\]\]"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
    }

    static func shortTitle(_ d: Deadline) -> String { d.title }
}

enum ModelError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

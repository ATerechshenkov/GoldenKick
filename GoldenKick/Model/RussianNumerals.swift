import Foundation

enum RussianNumerals {
    enum Gender { case masculine, feminine }

    /// Picks the noun form for a number: (одна) минута / (две) минуты / (пять) минут.
    static func plural(_ n: Int, one: String, few: String, many: String) -> String {
        let n10 = n % 10, n100 = n % 100
        if n10 == 1 && n100 != 11 { return one }
        if (2...4).contains(n10) && !(12...14).contains(n100) { return few }
        return many
    }

    private static let unitsMasculine = ["ноль", "один", "два", "три", "четыре", "пять", "шесть", "семь", "восемь", "девять"]
    private static let teens = ["десять", "одиннадцать", "двенадцать", "тринадцать", "четырнадцать", "пятнадцать", "шестнадцать", "семнадцать", "восемнадцать", "девятнадцать"]
    private static let tens = ["", "", "двадцать", "тридцать", "сорок", "пятьдесят", "шестьдесят", "семьдесят", "восемьдесят", "девяносто"]

    /// Cardinal number 0...99 in words, nominative case. Falls back to digits outside the range.
    static func cardinal(_ n: Int, gender: Gender = .masculine) -> String {
        guard (0...99).contains(n) else { return String(n) }
        if n < 10 { return unit(n, gender: gender) }
        if n < 20 { return teens[n - 10] }
        let t = tens[n / 10]
        return n % 10 == 0 ? t : "\(t) \(unit(n % 10, gender: gender))"
    }

    /// «одна минута», «две минуты», «пять минут», «одна минута тридцать секунд».
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60, s = total % 60
        var parts: [String] = []
        if m > 0 {
            parts.append("\(cardinal(m, gender: .feminine)) \(plural(m, one: "минута", few: "минуты", many: "минут"))")
        }
        if s > 0 || m == 0 {
            parts.append("\(cardinal(s, gender: .feminine)) \(plural(s, one: "секунда", few: "секунды", many: "секунд"))")
        }
        return parts.joined(separator: " ")
    }

    private static func unit(_ n: Int, gender: Gender) -> String {
        if gender == .feminine {
            if n == 1 { return "одна" }
            if n == 2 { return "две" }
        }
        return unitsMasculine[n]
    }
}

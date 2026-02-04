import Foundation

/// A rational number represented as numerator/denominator for exact proportional widths.
struct Fraction: Codable, Equatable, Hashable, Sendable {
    let numerator: Int
    let denominator: Int

    init(_ numerator: Int, _ denominator: Int) {
        precondition(denominator > 0, "Denominator must be positive")
        let g = Self.gcd(abs(numerator), denominator)
        self.numerator = numerator / g
        self.denominator = denominator / g
    }

    var doubleValue: Double {
        Double(numerator) / Double(denominator)
    }

    static let oneHalf = Fraction(1, 2)
    static let oneThird = Fraction(1, 3)
    static let twoThirds = Fraction(2, 3)
    static let oneQuarter = Fraction(1, 4)
    static let threeQuarters = Fraction(3, 4)
    static let oneFifth = Fraction(1, 5)
    static let one = Fraction(1, 1)

    /// Standard presets for snap-to-preset behavior.
    static let presets: [Fraction] = [
        .oneFifth, .oneQuarter, .oneThird, .oneHalf, .twoThirds, .threeQuarters, .one,
    ]

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a; var b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a
    }
}

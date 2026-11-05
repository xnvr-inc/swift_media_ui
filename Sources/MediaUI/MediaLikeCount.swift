import Foundation

/// Likes always display a count, including when the provider omitted it.
public enum MediaLikeCount {
    public static func display(_ value: String?) -> String {
        guard let count = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              count.unicodeScalars.contains(where: CharacterSet.decimalDigits.contains) else { return "0" }
        return count
    }
}

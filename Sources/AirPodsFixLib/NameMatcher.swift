/// Returns `true` if `name` contains "airpods" (case-insensitive).
public func isAirPodsName(_ name: String) -> Bool {
    name.lowercased().contains("airpods")
}

import SwiftUI

public struct MediaAppIdentityRows: View {
    private let name: String

    public init(name: String) { self.name = name }

    public var body: some View {
        LabeledContent("이름", value: name)
        LabeledContent("사용 범위", value: "개인용")
    }
}

public struct MediaAppVersionRow: View {
    private let identifier: String

    public init(identifier: String) { self.identifier = identifier }

    public var body: some View {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            LabeledContent("현재 버전", value: "\(version) (\(build))")
                .accessibilityIdentifier(identifier)
        }
    }
}

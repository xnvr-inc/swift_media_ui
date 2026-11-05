import SwiftUI

/// Independent preset buttons for a volume row, including rows inside a List or Form.
public struct MediaVolumePresets: View {
    private let percentages: [Int]
    private let apply: (Float) -> Void

    public init(percentages: [Int] = [10, 30, 50, 70, 100], apply: @escaping (Float) -> Void) {
        self.percentages = percentages
        self.apply = apply
    }

    public var body: some View {
        HStack {
            ForEach(percentages, id: \.self) { percent in
                Button {
                    apply(Float(percent) / 100)
                } label: {
                    Text("\(percent)%")
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

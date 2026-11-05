import SwiftUI

public enum MediaToolbarWordmarkMetrics {
    #if os(tvOS)
    public static let height: CGFloat = 39
    public static let leadingInset = MediaLayout.pageInset
    #elseif os(macOS)
    public static let size = CGSize(width: 117, height: 26)
    public static let leadingInset: CGFloat = 14
    #else
    public static let size = CGSize(width: 124, height: 30)
    #endif
}

#if os(iOS)
/// iPhone and iPad put the original artwork in the same native leading slot.
public struct MediaToolbarWordmarkItem: ToolbarContent {
    private let image: Image
    private let title: String
    private let identifier: String

    public init(image: Image, title: String, identifier: String) {
        self.image = image
        self.title = title
        self.identifier = identifier
    }

    public var body: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarLeading) { mark }.sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { mark }
        }
    }

    private var mark: some View {
        image.renderingMode(.original).resizable().scaledToFit()
            .frame(width: MediaToolbarWordmarkMetrics.size.width, height: MediaToolbarWordmarkMetrics.size.height, alignment: .leading)
            .accessibilityLabel(title).accessibilityIdentifier(identifier)
    }
}
#elseif os(macOS)
import AppKit

@MainActor public enum MediaMacToolbarWordmark {
    public static func item(_ identifier: NSToolbarItem.Identifier, image artwork: NSImage?,
                            title: String, accessibilityID: String) -> NSToolbarItem {
        let size = MediaToolbarWordmarkMetrics.size
        let leading = MediaToolbarWordmarkMetrics.leadingInset
        let height = MediaLayout.toolbarHeight
        let box = NSView(frame: CGRect(x: 0, y: 0, width: 2 * leading + size.width, height: height))
        let image = NSImageView(frame: CGRect(x: leading, y: (height - size.height) / 2,
                                              width: size.width, height: size.height))
        image.image = artwork
        image.imageAlignment = .alignLeft
        image.imageScaling = .scaleProportionallyUpOrDown
        image.setAccessibilityLabel(title)
        image.setAccessibilityIdentifier(accessibilityID)
        box.addSubview(image)
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = box
        if #available(macOS 26, *) { item.isBordered = false }
        return item
    }
}
#elseif os(tvOS)
import UIKit

/// A noninteractive peer of the native tab strip, aligned to its center.
public final class TVMediaToolbarWordmark: UIImageView {
    public init(image artwork: UIImage?, title: String, accessibilityID: String) {
        super.init(image: artwork)
        contentMode = .scaleAspectFit
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityIdentifier = accessibilityID
    }

    public required init?(coder: NSCoder) { fatalError() }

    public func install(in host: UIView, alignedTo tabBar: UITabBar) {
        let aspect = image.map { $0.size.width / max(1, $0.size.height) } ?? 1
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: MediaToolbarWordmarkMetrics.leadingInset),
            centerYAnchor.constraint(equalTo: tabBar.centerYAnchor),
            widthAnchor.constraint(equalTo: heightAnchor, multiplier: max(0.01, aspect)),
            heightAnchor.constraint(equalToConstant: MediaToolbarWordmarkMetrics.height),
        ])
    }
}
#endif

#if os(tvOS)
import UIKit

/// Finds the nearest playable card by visual row, including nested shelves.
@MainActor public enum TVBrowseRowFocus {
    public struct Target {
        public let list: UICollectionView
        public let path: IndexPath
        public let distance: CGFloat
    }

    public static func cell(containing view: UIView) -> UICollectionViewCell? {
        var candidate: UIView? = view
        while let current = candidate {
            if let cell = current as? UICollectionViewCell { return cell }
            candidate = current.superview
        }
        return nil
    }

    public static func focusTarget(in cell: UICollectionViewCell) -> UIView? {
        // A media card with separate play and channel actions is itself unfocusable.
        let target: UIView = (cell as? TVPlayableMediaCell)?.playbackButton ?? cell
        return target.canBecomeFocused ? target : nil
    }

    public static func distance(from origin: CGRect, to frame: CGRect, heading: UIFocusHeading) -> CGFloat {
        heading == .down ? frame.minY - origin.minY : origin.minY - frame.minY
    }

    public static func layoutFrame(of cell: UICollectionViewCell, in scroll: UIScrollView) -> CGRect {
        var ancestor = cell.superview
        while let view = ancestor {
            if let list = view as? UICollectionView, let path = list.indexPath(for: cell),
               let frame = list.layoutAttributesForItem(at: path)?.frame {
                return list.convert(frame, to: scroll)
            }
            ancestor = view.superview
        }
        return cell.convert(cell.bounds, to: scroll)
    }

    public static func nearest(to origin: CGRect, in scroll: UIScrollView, heading: UIFocusHeading) -> Target? {
        let search = scroll.bounds.insetBy(dx: 0, dy: -scroll.bounds.height)
        var closest: (target: Target, horizontal: CGFloat)?
        for list in collections(in: scroll) {
            let bounds = list.convert(search, from: scroll)
            let attributes = list.collectionViewLayout.layoutAttributesForElements(in: bounds) ?? []
            for item in attributes where item.representedElementCategory == .cell && !item.isHidden {
                let frame = list.convert(item.frame, to: scroll)
                let vertical = distance(from: origin, to: frame, heading: heading)
                guard vertical > 2 else { continue }
                if let cell = list.cellForItem(at: item.indexPath), focusTarget(in: cell) == nil { continue }
                let horizontal = abs(frame.midX - origin.midX)
                if let closest {
                    let rowDifference = vertical - closest.target.distance
                    if rowDifference > 2 || (abs(rowDifference) <= 2 && horizontal >= closest.horizontal) { continue }
                }
                closest = (Target(list: list, path: item.indexPath, distance: vertical), horizontal)
            }
        }
        return closest?.target
    }

    private static func collections(in view: UIView) -> [UICollectionView] {
        guard !view.isHidden, !(view is UICollectionViewCell) else { return [] }
        let own = (view as? UICollectionView).map { [$0] } ?? []
        return own + view.subviews.flatMap(collections(in:))
    }
}

#endif

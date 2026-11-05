import Foundation

public struct PlaybackMultiviewLayout {
    public let columns: Int
    public let rows: Int
    public let frames: [CGRect]

    public static func stageFrames(count: Int, size: CGSize, spacing: CGFloat = MediaMultiviewMetrics.tileSpacing,
                                   featuredIndex: Int? = nil, aspectRatios: [CGFloat]? = nil) -> [CGRect] {
        if count == 1 { return [CGRect(origin: .zero, size: size)] }
        return Self(count: count, size: size, controlsHeight: 0, spacing: spacing,
                    featuredIndex: featuredIndex, aspectRatios: aspectRatios).frames
    }

    public init(count: Int, size: CGSize, controlsHeight: CGFloat, spacing: CGFloat = MediaMultiviewMetrics.tileSpacing, featuredIndex: Int? = nil, aspectRatios: [CGFloat]? = nil) {
        guard count > 0, size.width > 0, size.height > controlsHeight else {
            columns = 1; rows = 0; frames = []
            return
        }
        if let featuredIndex, count > 1, (0..<count).contains(featuredIndex),
           size.width > spacing, size.height > CGFloat(count - 2) * spacing {
            columns = 2
            rows = count - 1
            let secondaryHeight = (size.height - CGFloat(count - 2) * spacing) / CGFloat(count - 1)
            let availableWidth = size.width - spacing
            let maximumSecondaryWidth = availableWidth * 0.3
            let secondaryWidth: CGFloat
            if count >= 4, secondaryHeight > controlsHeight {
                // Height limits the video once enough small players are stacked.
                // Give unused column width back to the featured player.
                secondaryWidth = min(maximumSecondaryWidth, (secondaryHeight - controlsHeight) * MediaCardMetrics.landscapeAspect)
            } else {
                secondaryWidth = maximumSecondaryWidth
            }
            let primaryWidth = availableWidth - secondaryWidth
            var secondaryIndex = 0
            // Keep frames in session order so changing the featured video
            // only moves existing player views and never recreates playback.
            frames = (0..<count).map { index in
                if index == featuredIndex {
                    return CGRect(x: 0, y: 0, width: primaryWidth, height: size.height)
                }
                defer { secondaryIndex += 1 }
                return CGRect(x: primaryWidth + spacing, y: CGFloat(secondaryIndex) * (secondaryHeight + spacing),
                              width: secondaryWidth, height: secondaryHeight)
            }
            return
        }
        if let aspects = aspectRatios, aspects.count == count,
           aspects.allSatisfy({ $0.isFinite && $0 > 0 }),
           aspects.contains(where: { abs($0 - MediaCardMetrics.landscapeAspect) > 0.01 }), controlsHeight == 0 {
            var bestFrames: [CGRect] = []
            var bestColumns = 1, bestRows = count
            var bestArea: CGFloat = -1
            for cols in 1...count {
                let rowCount = (count + cols - 1) / cols
                guard size.height > CGFloat(rowCount - 1) * spacing, size.width > CGFloat(cols - 1) * spacing else { continue }
                let rowAspects = stride(from: 0, to: count, by: cols).map { start in Array(aspects[start..<min(count, start + cols)]) }
                let heights = rowAspects.map { row in (size.width - CGFloat(row.count - 1) * spacing) / row.reduce(0, +) }
                let scale = min(1, (size.height - CGFloat(rowCount - 1) * spacing) / heights.reduce(0, +))
                let totalHeight = heights.reduce(0, +) * scale + CGFloat(rowCount - 1) * spacing
                var y = (size.height - totalHeight) / 2
                var candidate: [CGRect] = []
                for (row, height) in zip(rowAspects, heights) {
                    let h = height * scale
                    let width = row.reduce(0, +) * h + CGFloat(row.count - 1) * spacing
                    var x = (size.width - width) / 2
                    for aspect in row { let w = h * aspect; candidate.append(CGRect(x: x, y: y, width: w, height: h)); x += w + spacing }
                    y += h + spacing
                }
                let area = candidate.reduce(CGFloat.zero) { $0 + $1.width * $1.height }
                if area > bestArea { bestArea = area; bestFrames = candidate; bestColumns = cols; bestRows = rowCount }
            }
            columns = bestColumns; rows = bestRows; frames = bestFrames
            return
        }
        let aspect: CGFloat = MediaCardMetrics.landscapeAspect
        var bestColumns = 1
        var bestRows = count
        var bestWidth: CGFloat = 0
        var bestHeight: CGFloat = 0
        var bestArea: CGFloat = -1
        for candidateColumns in 1...count {
            let candidateRows = (count + candidateColumns - 1) / candidateColumns
            let slotWidth = (size.width - CGFloat(candidateColumns - 1) * spacing) / CGFloat(candidateColumns)
            let slotHeight = (size.height - CGFloat(candidateRows - 1) * spacing) / CGFloat(candidateRows)
            let videoWidth = max(0, min(slotWidth, (slotHeight - controlsHeight) * aspect))
            let videoHeight = videoWidth / aspect
            let area = videoWidth * videoHeight
            if area > bestArea {
                bestArea = area
                bestColumns = candidateColumns
                bestRows = candidateRows
                bestWidth = videoWidth
                bestHeight = videoHeight + controlsHeight
            }
        }
        columns = bestColumns
        rows = bestRows
        let totalHeight = CGFloat(bestRows) * bestHeight + CGFloat(bestRows - 1) * spacing
        let top = max(0, (size.height - totalHeight) / 2)
        frames = (0..<count).map { index in
            let row = index / bestColumns
            let column = index % bestColumns
            let itemsInRow = min(bestColumns, count - row * bestColumns)
            let rowWidth = CGFloat(itemsInRow) * bestWidth + CGFloat(itemsInRow - 1) * spacing
            return CGRect(x: (size.width - rowWidth) / 2 + CGFloat(column) * (bestWidth + spacing),
                          y: top + CGFloat(row) * (bestHeight + spacing), width: bestWidth, height: bestHeight)
        }
    }
}

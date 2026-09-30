import Foundation
import CoreGraphics

/// Squarified treemap (Bruls et al.). `values` must be sorted descending and > 0.
nonisolated enum Treemap {
    static func layout(values: [Double], in rect: CGRect) -> [CGRect] {
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else { return [] }
        let area = Double(rect.width * rect.height)
        let scaled = values.map { $0 / total * area }
        var result = [CGRect](repeating: .zero, count: values.count)
        var remaining = rect
        var i = 0

        func worst(_ sum: Double, _ minV: Double, _ maxV: Double, _ side: Double) -> Double {
            max(side * side * maxV / (sum * sum), sum * sum / (side * side * minV))
        }

        while i < scaled.count {
            let side = Double(min(remaining.width, remaining.height))
            var rowEnd = i + 1
            var sum = scaled[i]
            var best = worst(sum, scaled[i], scaled[i], side)
            while rowEnd < scaled.count {
                let newSum = sum + scaled[rowEnd]
                let w = worst(newSum, scaled[rowEnd], scaled[i], side)
                if w > best { break }
                sum = newSum; best = w; rowEnd += 1
            }
            if remaining.width >= remaining.height {
                let colW = CGFloat(sum / Double(remaining.height))
                var y = remaining.minY
                for k in i..<rowEnd {
                    let h = CGFloat(scaled[k]) / max(colW, 0.0001)
                    result[k] = CGRect(x: remaining.minX, y: y, width: colW, height: h)
                    y += h
                }
                remaining = CGRect(x: remaining.minX + colW, y: remaining.minY,
                                   width: max(0, remaining.width - colW), height: remaining.height)
            } else {
                let rowH = CGFloat(sum / Double(remaining.width))
                var x = remaining.minX
                for k in i..<rowEnd {
                    let w = CGFloat(scaled[k]) / max(rowH, 0.0001)
                    result[k] = CGRect(x: x, y: remaining.minY, width: w, height: rowH)
                    x += w
                }
                remaining = CGRect(x: remaining.minX, y: remaining.minY + rowH,
                                   width: remaining.width, height: max(0, remaining.height - rowH))
            }
            i = rowEnd
        }
        return result
    }
}

import AppKit
import Common

func restoredFloatingWindowFrame(proportion: CGPoint, size: CGSize, in destination: CGRect) -> CGRect {
    let x = destination.minX + proportion.x * destination.width
    let y = destination.minY + proportion.y * destination.height
    return CGRect(x: x.coerce(in: destination.minX ... max(destination.minX, destination.maxX - size.width)),
                  y: y.coerce(in: destination.minY ... max(destination.minY, destination.maxY - size.height)),
                  width: size.width, height: size.height)
}

func mappedFloatingWindowFrame(_ frame: CGRect, from source: CGRect, to destination: CGRect) -> CGRect {
    let proportion = CGPoint(x: (frame.minX - source.minX) / source.width,
                             y: (frame.minY - source.minY) / source.height)
    return restoredFloatingWindowFrame(proportion: proportion, size: frame.size, in: destination)
}

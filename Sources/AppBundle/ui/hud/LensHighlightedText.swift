import SwiftUI

func lensHighlightedText(_ text: String, ranges: [Range<Int>]) -> AttributedString {
    var result = AttributedString(text)
    for range in ranges {
        let start = result.characters.index(result.startIndex, offsetBy: range.lowerBound)
        let end = result.characters.index(result.startIndex, offsetBy: range.upperBound)
        result[start..<end].backgroundColor = Color(red: 1, green: 213 / 255, blue: 74 / 255)
        result[start..<end].foregroundColor = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)
    }
    return result
}

struct TileWindowControls: View {
    let entry: TileEntry
    let pictureSize: CGSize
    let scale: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(tileControlRects(in: CGRect(origin: .zero, size: pictureSize), scale: scale), id: \.0) { control, rect in
                if entry.controls.allows(control) {
                    Circle().fill(color(control))
                        .frame(width: rect.width, height: rect.height)
                        .shadow(color: .black.opacity(0.4), radius: 3 * scale, y: scale)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .frame(width: pictureSize.width, height: pictureSize.height)
        .allowsHitTesting(false)
    }
    private func color(_ control: TileWindowControl) -> Color {
        switch control {
            case .close: Color(red: 1, green: 95 / 255, blue: 87 / 255)
            case .minimize: Color(red: 254 / 255, green: 188 / 255, blue: 46 / 255)
            case .fullscreen: Color(red: 40 / 255, green: 200 / 255, blue: 64 / 255)
        }
    }
}

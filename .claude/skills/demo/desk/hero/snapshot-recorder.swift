import AVFoundation
import CoreGraphics
import Foundation
import ScreenCaptureKit

// Full-screen snapshots also capture the settled frame after a workspace switch.
let args = CommandLine.arguments
let seconds = Double(args[2])!
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let display = content.displays[0]
let filter = SCContentFilter(display: display, excludingWindows: [])
let config = SCStreamConfiguration()
config.width = display.width
config.height = display.height
config.showsCursor = false
let writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: args[1]), fileType: .mov)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: display.width,
    AVVideoHeightKey: display.height,
    AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false],
])
input.expectsMediaDataInRealTime = true
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
    kCVPixelBufferWidthKey as String: display.width,
    kCVPixelBufferHeightKey as String: display.height,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let start = Date().timeIntervalSince1970
try JSONSerialization.data(withJSONObject: ["epoch": start]).write(to: URL(fileURLWithPath: args[1] + ".clock.json"))
var frames = 0
var stamps: [Double] = []
while Date().timeIntervalSince1970 - start < seconds {
    let image: CGImage = try await withCheckedThrowingContinuation { continuation in
        SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
            if let image { continuation.resume(returning: image) }
            else { continuation.resume(throwing: error ?? NSError(domain: "filming", code: 1)) }
        }
    }
    let elapsed = Date().timeIntervalSince1970 - start
    var pixel: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixel)
    guard let pixel else { fatalError("pixel allocation failed") }
    CVPixelBufferLockBaseAddress(pixel, [])
    let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: display.width, height: display.height,
                            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: display.width, height: display.height))
    CVPixelBufferUnlockBaseAddress(pixel, [])
    if input.isReadyForMoreMediaData {
        guard adaptor.append(pixel, withPresentationTime: CMTime(seconds: elapsed, preferredTimescale: 60000)) else {
            fatalError(String(describing: writer.error))
        }
        frames += 1
        stamps.append(elapsed)
    }
    let next = Double(frames) / 15
    let wait = next - (Date().timeIntervalSince1970 - start)
    if wait > 0 { try await Task.sleep(for: .seconds(wait)) }
}
input.markAsFinished()
await writer.finishWriting()
guard writer.status == .completed else { fatalError(String(describing: writer.error)) }
try JSONSerialization.data(withJSONObject: ["epoch": start, "sampleSeconds": stamps]).write(to: URL(fileURLWithPath: args[1] + ".clock.json"))
print("Recorded \(frames) full-screen snapshots")

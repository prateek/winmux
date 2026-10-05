import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

final class Recorder: NSObject, SCStreamOutput, @unchecked Sendable {
    let writer: AVAssetWriter
    let input: AVAssetWriterInput
    let adaptor: AVAssetWriterInputPixelBufferAdaptor
    let metadata: URL
    var first: CMTime?
    var times: [Double] = []
    var displayTimes: [Double] = []
    var receiptTimes: [Double] = []
    init(path: String, width: Int, height: Int) throws {
        metadata = URL(fileURLWithPath: path + ".clock.json")
        writer = try AVAssetWriter(outputURL: URL(fileURLWithPath: path), fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height, AVVideoCompressionPropertiesKey: [AVVideoAllowFrameReorderingKey: false, AVVideoExpectedSourceFrameRateKey: 60]])
        input.mediaTimeScale = 1_000_000_000
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        input.expectsMediaDataInRealTime = true
        writer.add(input)
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sample: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sample.isValid, CMSampleBufferGetImageBuffer(sample) != nil,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue else { return }
        var info = mach_timebase_info_data_t(); mach_timebase_info(&info)
        let received = Double(mach_absolute_time()) * Double(info.numer) / Double(info.denom) / 1e9
        let pts = CMTime(seconds: received, preferredTimescale: 1_000_000_000)
        let source = CMSampleBufferGetImageBuffer(sample)!
        var copy: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(source), CVPixelBufferGetHeight(source), kCVPixelFormatType_32BGRA, nil, &copy)
        guard let copy else { fatalError("pixel allocation failed") }
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(copy, [])
        for row in 0..<CVPixelBufferGetHeight(source) {
            memcpy(CVPixelBufferGetBaseAddress(copy)!.advanced(by: row * CVPixelBufferGetBytesPerRow(copy)),
                   CVPixelBufferGetBaseAddress(source)!.advanced(by: row * CVPixelBufferGetBytesPerRow(source)),
                   min(CVPixelBufferGetBytesPerRow(source), CVPixelBufferGetBytesPerRow(copy)))
        }
        CVPixelBufferUnlockBaseAddress(copy, [])
        CVPixelBufferUnlockBaseAddress(source, .readOnly)
        if first == nil {
            first = pts
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            try! JSONSerialization.data(withJSONObject: ["firstPTS": pts.seconds, "clock": "Mach absolute seconds", "requestedFPS": 60]).write(to: metadata)
        }
        if input.isReadyForMoreMediaData {
            guard adaptor.append(copy, withPresentationTime: CMTimeSubtract(pts, first!)) else { fatalError(writer.error!.localizedDescription) }
            times.append(pts.seconds)
            let ticks = (attachments.first?[.displayTime] as? NSNumber)?.uint64Value ?? 0
            receiptTimes.append(received)
            displayTimes.append(Double(ticks) * Double(info.numer) / Double(info.denom) / 1e9)
        }
    }
    func finish() async {
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed, let first else { fatalError("recording failed: \(String(describing: writer.error))") }
        try! JSONSerialization.data(withJSONObject: ["firstPTS": first.seconds, "clock": "Mach absolute seconds", "framePTS": times, "displayTimes": displayTimes, "receiptTimes": receiptTimes]).write(to: metadata)
    }
}

let args = CommandLine.arguments
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let display = content.displays[0]
let config = SCStreamConfiguration()
config.width = display.width; config.height = display.height
config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
config.showsCursor = false
config.queueDepth = 8
config.pixelFormat = kCVPixelFormatType_32BGRA
let recorder = try Recorder(path: args[1], width: config.width, height: config.height)
let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: config, delegate: nil)
let queue = DispatchQueue(label: "trace-recording")
try stream.addStreamOutput(recorder, type: .screen, sampleHandlerQueue: queue)
try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    stream.startCapture { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
}
try await Task.sleep(for: .seconds(Double(args[2])!))
try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    stream.stopCapture { error in
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
}
queue.sync {}
await recorder.finish()

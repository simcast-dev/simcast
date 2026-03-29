import AVFoundation
import CoreMedia
import ScreenCaptureKit

final class FileRecordingReceiver: VideoFrameReceiver, @unchecked Sendable {
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private var lastTime: CMTime?
    let outputURL: URL
    private let dimensions: CGSize

    init(outputURL: URL, dimensions: CGSize) {
        self.outputURL = outputURL
        self.dimensions = dimensions
    }

    func start() throws {
        // Remove any existing file at the output path to avoid AVAssetWriter error
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(dimensions.width),
            AVVideoHeightKey: Int(dimensions.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoExpectedSourceFrameRateKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true
        writer.add(input)

        // Pixel buffer adaptor handles format conversion from SCK's IOSurface-backed
        // BGRA buffers to what VideoToolbox expects for H.264 encoding.
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(dimensions.width),
                kCVPixelBufferHeightKey as String: Int(dimensions.height),
            ]
        )

        writer.startWriting()
        self.assetWriter = writer
        self.videoInput = input
        self.adaptor = adaptor
    }

    nonisolated func sckManager(didOutput sampleBuffer: CMSampleBuffer) {
        // SCK delivers buffers with status .idle/.blank/.suspended — only record .complete frames
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue else { return }

        guard let writer = assetWriter, let adaptor = adaptor,
              writer.status == .writing,
              adaptor.assetWriterInput.isReadyForMoreMediaData,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if startTime == nil {
            startTime = timestamp
            writer.startSession(atSourceTime: timestamp)
        }
        lastTime = timestamp
        adaptor.append(pixelBuffer, withPresentationTime: timestamp)
    }

    func sckManagerDidStop() {}

    func stop() async -> Double {
        videoInput?.markAsFinished()
        await assetWriter?.finishWriting()
        let duration: Double
        if let start = startTime, let end = lastTime {
            duration = CMTimeGetSeconds(end) - CMTimeGetSeconds(start)
        } else {
            duration = 0
        }
        assetWriter = nil
        videoInput = nil
        adaptor = nil
        startTime = nil
        lastTime = nil
        return duration
    }
}

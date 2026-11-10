import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

@main struct GifTool {
    static func main() async throws {
        let args = CommandLine.arguments
        let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
        let duration = try await asset.load(.duration).seconds
        let interval = 0.06
        let frames = Int(ceil(duration / interval))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 420, height: 540)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 60)
        let target = URL(fileURLWithPath: args[2])
        guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.gif.identifier as CFString, frames, nil) else {
            throw NSError(domain: "GIF", code: 1)
        }
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for index in 0..<frames {
            let second = Double(index) * interval
            let image = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600)).image
            let delay = min(interval, duration - second)
            let properties = [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay,
                kCGImagePropertyGIFUnclampedDelayTime: delay
            ]]
            CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination),
              let source = CGImageSourceCreateWithURL(target as CFURL, nil) else {
            throw NSError(domain: "GIF", code: 2)
        }
        let count = CGImageSourceGetCount(source)
        let dimensions = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)! as NSDictionary
        var actualDuration = 0.0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil)! as NSDictionary
            let gif = properties[kCGImagePropertyGIFDictionary] as! NSDictionary
            let delay = gif[kCGImagePropertyGIFUnclampedDelayTime] ?? gif[kCGImagePropertyGIFDelayTime]
            actualDuration += (delay as! NSNumber).doubleValue
        }
        for index in [0, count / 2, count - 1] {
            guard CGImageSourceCreateImageAtIndex(source, index, nil) != nil else {
                throw NSError(domain: "GIFDecode", code: index)
            }
        }
        guard count == frames, abs(actualDuration - duration) < 0.02 else {
            throw NSError(domain: "GIFDuration", code: 3)
        }
        let size = (try FileManager.default.attributesOfItem(atPath: target.path)[.size] as! NSNumber).intValue
        let result: [String: Any] = [
            "file": target.lastPathComponent, "frames": count, "duration_seconds": actualDuration,
            "width": dimensions[kCGImagePropertyPixelWidth]!, "height": dimensions[kCGImagePropertyPixelHeight]!, "bytes": size
        ]
        let json = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        print(String(data: json, encoding: .utf8)!)
    }
}

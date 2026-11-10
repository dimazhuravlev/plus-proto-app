import Foundation
import AVFoundation
import AppKit

@main struct VideoTool {
    static func main() async throws {
        let args = CommandLine.arguments
        if args[1] == "inspect" {
            var records = [[String: Any]]()
            for path in args.dropFirst(2) {
                let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                let duration = try await asset.load(.duration).seconds
                let track = try await asset.loadTracks(withMediaType: .video)[0]
                let size = try await track.load(.naturalSize)
                let fps = try await track.load(.nominalFrameRate)
                records.append(["file": URL(fileURLWithPath: path).lastPathComponent,
                    "duration_seconds": duration, "width": Int(size.width), "height": Int(size.height), "fps": fps])
                guard duration > 0 && duration <= 5 else { throw NSError(domain: "VideoDuration", code: 1) }
            }
            let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8)!)
        } else if args[1] == "encode" {
            let asset = AVURLAsset(url: URL(fileURLWithPath: args[2]))
            let track = try await asset.loadTracks(withMediaType: .video)[0]
            let size = try await track.load(.naturalSize)
            let composition = AVMutableVideoComposition()
            let y: CGFloat = 120
            let height: CGFloat = min(1540, size.height - y)
            composition.renderSize = CGSize(width: size.width, height: height)
            composition.frameDuration = CMTime(value: 1, timescale: 30)
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: 4.9, preferredTimescale: 600))
            let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            layer.setTransform(CGAffineTransform(translationX: 0, y: -y), at: .zero)
            instruction.layerInstructions = [layer]
            composition.instructions = [instruction]
            let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
            exporter.videoComposition = composition
            exporter.timeRange = instruction.timeRange
            exporter.shouldOptimizeForNetworkUse = true
            let target = URL(fileURLWithPath: args[3])
            try? FileManager.default.removeItem(at: target)
            try await exporter.export(to: target, as: .mp4)
            let output = AVURLAsset(url: target)
            let duration = try await output.load(.duration).seconds
            print("\(target.lastPathComponent): \(duration)s, \(Int(size.width))×\(Int(height))")
        } else if args[1] == "sheet" {
            let names = Array(args.dropFirst(4))
            let width = 1200, rowHeight = 286
            let height = rowHeight * names.count
            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            NSColor.black.setFill()
            NSRect(x: 0, y: 0, width: width, height: height).fill()
            for (row, name) in names.enumerated() {
                let bottom = height - (row + 1) * rowHeight
                (name as NSString).draw(at: NSPoint(x: 8, y: bottom + 260), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.white])
                for index in 0..<6 {
                    if let image = NSImage(contentsOfFile: args[2]+"/"+name+"-\(index).jpg") {
                        image.draw(in: NSRect(x: index * 200, y: bottom, width: 200, height: 255))
                    }
                }
            }
            NSGraphicsContext.restoreGraphicsState()
            try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: URL(fileURLWithPath: args[3]))
        } else if args[1] == "frames" {
            let asset = AVURLAsset(url: URL(fileURLWithPath: args[2]))
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            for (index, second) in [0.1, 0.8, 1.4, 2.2, 3.2, 4.6].enumerated() {
                let frame = try await generator.image(at: CMTime(seconds: second, preferredTimescale: 600)).image
                let rep = NSBitmapImageRep(cgImage: frame)
                try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85])!.write(to: URL(fileURLWithPath: args[3]+"-\(index).jpg"))
            }
        }
    }
}

import CoreImage
import UIKit
import Vision

/// A photo ready to become part of a piece: upright and scaled down, the piece cut out of its
/// background when Vision finds it, its main colors and a guess of what it is. Everything runs on
/// the device, without a network.
struct ProcessedPhoto {
    let original: UIImage
    let cutout: UIImage?
    let colors: [String]
    let category: Category?
}

enum PhotoProcessor {
    /// The longest side photos are kept at.
    static let maxSide: CGFloat = 1600

    static func process(_ image: UIImage, removeBackground: Bool) async -> ProcessedPhoto {
        await Task.detached(priority: .userInitiated) {
            let upright = normalized(image, maxSide: maxSide)
            let cutout = removeBackground ? self.cutout(upright) : nil
            let colorSource = cutout ?? upright
            let colors = dominantColors(colorSource, ignoringBackground: cutout == nil)
            let category = classify(upright)
            return ProcessedPhoto(original: upright, cutout: cutout, colors: colors, category: category)
        }.value
    }

    /// The photo drawn upright (the camera's orientation applied) with its longest side at most
    /// `maxSide` points, at scale 1.
    static func normalized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// The pieces Vision sees in front of the background, on a transparent background and cropped
    /// to them, or nil when it finds none (or cannot run, as in the simulator).
    static func cutout(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances, from: handler, croppedToInstancesExtent: true)
            let ci = CIImage(cvPixelBuffer: buffer)
            guard let out = CIContext().createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: out)
        } catch {
            return nil
        }
    }

    /// The palette colors of the piece, read from a small copy of the image. Transparent pixels
    /// (the removed background) do not count; without a cut-out the border of the photo, most
    /// likely background, is left out instead.
    static func dominantColors(_ image: UIImage, ignoringBackground: Bool) -> [String] {
        guard let cg = image.cgImage else { return [] }
        let side = 48
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = data.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return [] }
        let margin = ignoringBackground ? side / 5 : 0
        var pixels: [(red: Double, green: Double, blue: Double)] = []
        for y in margin..<(side - margin) {
            for x in margin..<(side - margin) {
                let i = (y * side + x) * 4
                let alpha = Double(data[i + 3])
                guard alpha > 160 else { continue }
                // Undo the premultiplication: edge pixels would look darker than the cloth.
                pixels.append((Double(data[i]) * 255 / alpha, Double(data[i + 1]) * 255 / alpha, Double(data[i + 2]) * 255 / alpha))
            }
        }
        return PaletteColor.dominant(pixels: pixels)
    }

    /// What the piece most likely is, from Vision's built-in image classifier.
    static func classify(_ image: UIImage) -> Category? {
        guard let cg = image.cgImage else { return nil }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        guard (try? handler.perform([request])) != nil, let results = request.results else { return nil }
        return Category.guess(from: results.map { (identifier: $0.identifier, confidence: $0.confidence) })
    }
}

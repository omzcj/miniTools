import CoreGraphics
import Foundation
import ImageIO

enum ImageCodec {
    static let pngTypeIdentifier = "public.png"
    static let jpegTypeIdentifier = "public.jpeg"

    static func pngData(from imageData: Data) throws -> Data {
        try encodedData(from: decodedImage(from: imageData), typeIdentifier: pngTypeIdentifier)
    }

    static func jpegData(from imageData: Data, quality: Double = 0.92) throws -> Data {
        let image = try opaqueImage(from: decodedImage(from: imageData))
        return try encodedData(
            from: image,
            typeIdentifier: jpegTypeIdentifier,
            properties: [kCGImageDestinationLossyCompressionQuality: min(max(quality, 0.1), 1)]
        )
    }

    static func compressedJPEGData(from imageData: Data, quality: Double) throws -> Data {
        let result = try jpegData(from: imageData, quality: quality)
        guard result.count < imageData.count else {
            throw MiniToolsError.processingFailed("压缩后的图片没有变小，剪贴板保持不变")
        }
        return result
    }

    static func pixelDimensions(from imageData: Data) throws -> (width: Int, height: Int) {
        guard
            let source = CGImageSourceCreateWithData(imageData as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
            let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        else {
            throw MiniToolsError.processingFailed("无法读取剪贴板图片尺寸")
        }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        return (5...8).contains(orientation) ? (height, width) : (width, height)
    }

    static func decodedImage(from data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw MiniToolsError.processingFailed("无法读取剪贴板图片像素")
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let maxPixelSize = max(width, height)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard maxPixelSize > 0,
              let result = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw MiniToolsError.processingFailed("无法读取剪贴板图片像素")
        }
        return result
    }

    static func encodedData(
        from image: CGImage,
        typeIdentifier: String,
        properties: [CFString: Any] = [:]
    ) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            typeIdentifier as CFString,
            1,
            nil
        ) else {
            throw MiniToolsError.processingFailed("图片编码器不可用")
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MiniToolsError.processingFailed("图片编码失败")
        }
        return output as Data
    }

    private static func opaqueImage(from image: CGImage) throws -> CGImage {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else {
            throw MiniToolsError.processingFailed("无法创建 JPEG 绘图环境")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let result = context.makeImage() else {
            throw MiniToolsError.processingFailed("JPEG 透明背景处理失败")
        }
        return result
    }
}

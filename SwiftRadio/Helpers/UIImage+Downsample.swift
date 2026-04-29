//
//  UIImage+Downsample.swift
//  SwiftRadio
//

import UIKit
import ImageIO

extension UIImage {

    /// Decodes `data` with a hard cap on the larger dimension to avoid multi‑megapixel bitmaps in RAM (now playing background, artwork, logos).
    static func swr_decodedImage(from data: Data, maxPixelSize: CGFloat = 1080) -> UIImage? {
        guard !data.isEmpty else { return nil }
        let cap = Int(max(128, maxPixelSize))
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldAllowFloat: true,
            kCGImageSourceThumbnailMaxPixelSize: cap,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

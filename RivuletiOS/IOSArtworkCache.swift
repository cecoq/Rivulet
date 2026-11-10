// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2025-2026 Bain Gurley

import Foundation
import UIKit

/// Memory cache for every piece of iOS artwork. Plex's transcode URLs carry
/// their requested size, so URL identity is also decode-size identity.
actor IOSArtworkCache {
    static let shared = IOSArtworkCache()

    /// NSCache is thread-safe; read synchronously so a recreated tile shows
    /// its art on the first frame instead of flashing a placeholder.
    nonisolated(unsafe) private let images = NSCache<NSURL, UIImage>()
    private var downloads: [URL: Task<UIImage?, Never>] = [:]
    /// Trusts the self-signed certificates a raw-IP or plex.direct server presents, as the API client does.
    private static let session = URLSession(configuration: .default, delegate: PlexCertificateDelegate(), delegateQueue: nil)

    private init() {
        images.countLimit = 400
        images.totalCostLimit = 160 * 1024 * 1024
    }

    nonisolated func cachedImage(for url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = images.object(forKey: url as NSURL) { return cached }
        if let existing = downloads[url] { return await existing.value }

        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            // A downloaded poster reads straight from disk.
            let fetched = url.isFileURL
                ? (try? Data(contentsOf: url)).map { ($0, URLResponse()) }
                : try? await Self.session.data(from: url)
            guard let (data, response) = fetched,
                  ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400 else {
                return nil
            }
            // Decode here, off the main thread, instead of at first draw.
            var image = UIImage(data: data)
            if image == nil {
                image = await SVGRasterizer.decode(data, maxPixelSize: 512).map { UIImage(cgImage: $0) }
            }
            guard let image else { return nil }
            return Self.normalizedForDisplay(image)
        }
        downloads[url] = task
        let image = await task.value
        downloads[url] = nil

        if let image {
            let pixels = image.cgImage.map { $0.width * $0.height }
                ?? Int(image.size.width * image.size.height)
            images.setObject(image, forKey: url as NSURL, cost: pixels * 4)
        }
        return image
    }

    /// Decode into a conventional bitmap before UIKit sees the image. The
    /// guide creates many thumbnails at once; leaving ImageIO's original
    /// color space/decompression deferred causes UIKit's render server to
    /// report -17102 and briefly drop the artwork surface.
    nonisolated private static func normalizedForDisplay(_ image: UIImage) -> UIImage? {
        guard let source = image.cgImage else { return image }
        let width = source.width
        let height = source.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .high
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let rendered = context.makeImage() else { return nil }
        return UIImage(cgImage: rendered, scale: image.scale, orientation: image.imageOrientation)
    }
}

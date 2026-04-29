//
//  StreamBitrateTracker.swift
//  SwiftRadio
//

import AVFoundation
import FRadioPlayer

extension Notification.Name {
    /// Posted when a new measured bitrate is available (typically Auto / adaptive streams).
    static let streamMeasuredBitrateDidUpdate = Notification.Name("streamMeasuredBitrateDidUpdate")
}

/// Reads approximate stream bitrate from `AVPlayerItem` access logs (adaptive HLS / progressive).
final class StreamBitrateTracker {

    static let shared = StreamBitrateTracker()

    /// Latest measured bitrate in kbps (nil if unknown).
    private(set) var measuredBitrateKbps: Int?

    private var accessLogObserver: NSObjectProtocol?
    private var pollTimer: Timer?

    private init() {}

    func resetMeasuredBitrate() {
        measuredBitrateKbps = nil
        NotificationCenter.default.post(name: .streamMeasuredBitrateDidUpdate, object: nil)
    }

    /// Begin observing access-log updates and light polling while Auto mode needs live bitrate.
    func start() {
        guard accessLogObserver == nil else { return }

        accessLogObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemNewAccessLogEntry,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAccessLogNotification(notification)
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.pollPlayerItemBitrate()
        }
        RunLoop.main.add(pollTimer!, forMode: .common)

        pollPlayerItemBitrate()
    }

    func stop() {
        if let accessLogObserver {
            NotificationCenter.default.removeObserver(accessLogObserver)
            self.accessLogObserver = nil
        }
        pollTimer?.invalidate()
        pollTimer = nil
        measuredBitrateKbps = nil
    }

    private func handleAccessLogNotification(_ notification: Notification) {
        guard let item = notification.object as? AVPlayerItem else { return }
        guard matchesActiveStream(item) else { return }
        applyBitrate(from: item)
    }

    private func pollPlayerItemBitrate() {
        guard let item = fradioPrivatePlayerItem() else { return }
        guard matchesActiveStream(item) else { return }
        applyBitrate(from: item)
    }

    private func matchesActiveStream(_ item: AVPlayerItem) -> Bool {
        guard let asset = item.asset as? AVURLAsset else { return false }
        guard let playing = FRadioPlayer.shared.radioURL else { return false }
        return asset.url.absoluteString == playing.absoluteString
    }

    private func applyBitrate(from item: AVPlayerItem) {
        guard let event = item.accessLog()?.events.last else { return }
        let bps = event.indicatedBitrate > 0 ? event.indicatedBitrate : event.observedBitrate
        guard bps > 0 else { return }
        let kbps = max(1, Int(round(bps / 1000.0)))
        if measuredBitrateKbps != kbps {
            measuredBitrateKbps = kbps
            NotificationCenter.default.post(name: .streamMeasuredBitrateDidUpdate, object: nil)
        }
    }

    /// FRadioPlayer keeps `playerItem` private; reflection is used only to poll bitrate between access-log posts.
    private func fradioPrivatePlayerItem() -> AVPlayerItem? {
        let mirror = Mirror(reflecting: FRadioPlayer.shared)
        for child in mirror.children {
            if child.label == "playerItem", let item = child.value as? AVPlayerItem {
                return item
            }
        }
        return nil
    }
}

// MARK: - Status line

enum StreamQualityStatusFormatting {

    static func statusLine(station: RadioStation?, mode: StreamQualityMode, measuredKbps: Int?) -> String {
        guard let station else {
            return StreamQualityStatusFormatting.modeOnly(mode)
        }

        switch mode {
        case .auto:
            if let kbps = measuredKbps, kbps > 0 {
                return String(format: Content.Player.autoWithBitrate, kbps)
            }
            return Content.Player.autoQualityShort
        case .low, .medium, .high:
            let eff = station.effectiveStreamQuality(for: mode)
            if eff == .auto {
                return modeOnly(mode)
            }
            let tierTitle = tierLineTitle(for: eff)
            if let label = station.bitrateLabel(for: eff) {
                return String(format: Content.Player.tierWithBitrateLabel, tierTitle, label)
            }
            return tierTitle
        }
    }

    private static func tierLineTitle(for mode: StreamQualityMode) -> String {
        switch mode {
        case .auto: return Content.Player.autoQualityShort
        case .low: return Content.Player.tierLowTitle
        case .medium: return Content.Player.tierMidTitle
        case .high: return Content.Player.tierHighTitle
        }
    }

    private static func modeOnly(_ mode: StreamQualityMode) -> String {
        switch mode {
        case .auto: return Content.Player.autoQualityShort
        case .low: return Content.Player.tierLowTitle
        case .medium: return Content.Player.tierMidTitle
        case .high: return Content.Player.tierHighTitle
        }
    }
}

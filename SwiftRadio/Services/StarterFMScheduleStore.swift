//
//  StarterFMScheduleStore.swift
//  SwiftRadio
//

import Foundation

extension Notification.Name {
    /// Posted when the computed on-air slot for the bundled Starter FM grid changes.
    static let starterFMScheduleCurrentShowDidChange = Notification.Name("starterFMScheduleCurrentShowDidChange")
}

/// Loads bundled `StarterFMSchedule.json` and publishes the current on-air slot (Sydney time).
final class StarterFMScheduleStore {

    static let shared = StarterFMScheduleStore()

    private let lock = NSLock()
    private var document: StarterFMScheduleDocument?
    private var lastSignature: String = ""
    private var pollTimer: Timer?

    private init() {
        reloadFromBundle()
    }

    func reloadFromBundle() {
        let decoder = JSONDecoder()
        guard let url = Bundle.main.url(forResource: "StarterFMSchedule", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? decoder.decode(StarterFMScheduleDocument.self, from: data) else {
            lock.lock()
            document = nil
            lock.unlock()
            refreshAndNotifyIfNeeded(force: true)
            return
        }
        lock.lock()
        document = doc
        lock.unlock()
        refreshAndNotifyIfNeeded(force: true)
    }

    func ensurePollingStarted() {
        DispatchQueue.main.async { [weak self] in
            self?.installTimerIfNeeded()
        }
    }

    private func installTimerIfNeeded() {
        assert(Thread.isMainThread)
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refreshAndNotifyIfNeeded(force: false)
        }
        if let t = pollTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func refreshAndNotifyIfNeeded(force: Bool) {
        let slot = currentSlotNow()
        let sig = StarterFMScheduleEngine.signature(for: slot)
        lock.lock()
        let changed = force || sig != lastSignature
        if changed {
            lastSignature = sig
        }
        lock.unlock()
        guard changed else { return }
        let post = {
            NotificationCenter.default.post(name: .starterFMScheduleCurrentShowDidChange, object: nil)
        }
        if Thread.isMainThread {
            post()
        } else {
            DispatchQueue.main.async(execute: post)
        }
    }

    func currentSlotNow() -> StarterFMShowSlot? {
        lock.lock()
        let doc = document
        lock.unlock()
        guard let doc else { return nil }
        return StarterFMScheduleEngine.currentSlot(in: doc, now: Date())
    }

    func scheduleDocument() -> StarterFMScheduleDocument? {
        lock.lock()
        let d = document
        lock.unlock()
        return d
    }
}

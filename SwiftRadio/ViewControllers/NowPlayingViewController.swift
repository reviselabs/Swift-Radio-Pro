//
//  NowPlayingViewControllerWIP.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2024-01-13.
//  Copyright © 2024 matthewfecher.com. All rights reserved.
//

import UIKit
import MediaPlayer
import AVKit
import FRadioPlayer
import NVActivityIndicatorView
import LNPopupController

protocol NowPlayingViewControllerDelegate: AnyObject {
    func didSelectBottomSheetOption(_ option: BottomSheetViewController.Option, from controller: NowPlayingViewController)
    func didTapCompanyButton(_ nowPlayingViewController: NowPlayingViewController)
    func nowPlayingViewControllerDidRequestStarterFMSchedule(_ controller: NowPlayingViewController)
}

extension NowPlayingViewControllerDelegate {
    func nowPlayingViewControllerDidRequestStarterFMSchedule(_ controller: NowPlayingViewController) {}
}

class NowPlayingViewController: UIViewController {

    // MARK: - Delegate
    weak var delegate: NowPlayingViewControllerDelegate?

    // MARK: - UI
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let backgroundBlurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let backgroundDimView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let albumArtworkView = AlbumArtworkView()
    private let controlsView = ControlsView()
    private let controlsCardView: UIVisualEffectView = {
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        card.layer.cornerRadius = 22
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }()
    private var topConstraint: NSLayoutConstraint?

    // MARK: - Popup Bar
    private lazy var playPauseButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: UIImage(systemName: "play.fill"), style: .plain, target: self, action: #selector(popupBarPlayPauseTapped))
        return button
    }()

    // MARK: - Properties
    private let player = FRadioPlayer.shared
    private let manager = StationsManager.shared

    private var streamBitrateObserver: NSObjectProtocol?
    private var playbackQualityObserver: NSObjectProtocol?
    private var externalNowPlayingObserver: NSObjectProtocol?
    private var starterFMScheduleObserver: NSObjectProtocol?
    private var appResignActiveObserver: NSObjectProtocol?
    private var appDidBecomeActiveObserver: NSObjectProtocol?

    private var marqueesPausedForMinimizedPopup = false
    private var marqueesPausedForBackground = false

    /// Title line can change every bitrate sample; the menu must only be rebuilt when mode/station changes.
    private var lastStreamQualityTitleKey: String = ""
    private var lastStreamQualityMenuKey: String = ""

    // MARK: - Lifecycle Methods

    override func viewDidLoad() {
        super.viewDidLoad()

        player.addObserver(self)
        manager.addObserver(self)

        setupViews()
        setupStreamQualityObservers()
        setupExternalNowPlayingObserver()
        setupStarterFMScheduleObserver()
        stationDidChange()
        isPlayingDidChange(player.isPlaying)
        controlsView.setLive(player.duration == 0)

        // Popup bar button items
        popupItem.barButtonItems = [playPauseButton]

        appResignActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.marqueesPausedForBackground = true
            self?.refreshMarqueeScrollingPause()
        }
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.marqueesPausedForBackground = false
            self?.refreshMarqueeScrollingPause()
        }
    }

    deinit {
        if let appResignActiveObserver {
            NotificationCenter.default.removeObserver(appResignActiveObserver)
        }
        if let appDidBecomeActiveObserver {
            NotificationCenter.default.removeObserver(appDidBecomeActiveObserver)
        }
        if let streamBitrateObserver {
            NotificationCenter.default.removeObserver(streamBitrateObserver)
        }
        if let playbackQualityObserver {
            NotificationCenter.default.removeObserver(playbackQualityObserver)
        }
        if let externalNowPlayingObserver {
            NotificationCenter.default.removeObserver(externalNowPlayingObserver)
        }
        if let starterFMScheduleObserver {
            NotificationCenter.default.removeObserver(starterFMScheduleObserver)
        }
        StreamBitrateTracker.shared.stop()
    }

    override func viewDidMove(toPopupContainerContentView popupContentView: LNPopupContentView?) {
        super.viewDidMove(toPopupContainerContentView: popupContentView)
        marqueesPausedForMinimizedPopup = (popupContentView == nil)
        refreshMarqueeScrollingPause()
    }

    private func refreshMarqueeScrollingPause() {
        let paused = marqueesPausedForMinimizedPopup || marqueesPausedForBackground
        controlsView.setMarqueeScrollingPaused(paused)
    }

    private func setupStreamQualityObservers() {
        streamBitrateObserver = NotificationCenter.default.addObserver(
            forName: .streamMeasuredBitrateDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard PlaybackPreferences.shared.streamQualityMode == .auto else { return }
            self?.refreshStreamQualityStatus()
        }

        playbackQualityObserver = NotificationCenter.default.addObserver(
            forName: .playbackQualityPreferenceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncBitrateTracking()
            self?.refreshStreamQualityStatus()
        }
    }

    private func setupExternalNowPlayingObserver() {
        externalNowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .externalNowPlayingMetadataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateLabels()
            self?.updatePopupBarMetadata()
        }
    }

    private func setupStarterFMScheduleObserver() {
        starterFMScheduleObserver = NotificationCenter.default.addObserver(
            forName: .starterFMScheduleCurrentShowDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateStarterFMOnAirLine()
            self?.updatePopupBarMetadata()
        }
    }

    /// Uses stream ICY metadata and/or `nowPlayingURL` JSON when deciding to show the song row.
    private func displayedSongLine() -> (song: String, artist: String)? {
        guard let station = manager.currentStation else { return nil }
        let hasStreamTitle = player.currentMetadata?.trackName != nil
        let hasExternal = station.nowPlayingURL != nil && StationNowPlayingService.shared.hasExternalMetadata(for: station)
        guard hasStreamTitle || hasExternal else { return nil }
        return (station.trackName, station.artistName)
    }

    private func syncBitrateTracking() {
        let mode = PlaybackPreferences.shared.streamQualityMode
        if mode == .auto, manager.currentStation != nil {
            StreamBitrateTracker.shared.stop()
            StreamBitrateTracker.shared.start()
        } else {
            StreamBitrateTracker.shared.stop()
        }
    }

    private func refreshStreamQualityStatus() {
        let station = manager.currentStation
        let mode = PlaybackPreferences.shared.streamQualityMode
        let measured = mode == .auto ? StreamBitrateTracker.shared.measuredBitrateKbps : nil
        let text = StreamQualityStatusFormatting.statusLine(
            station: station,
            mode: mode,
            measuredKbps: measured
        )
        let isHidden = station == nil
        let titleKey = "\(isHidden)|\(station?.streamURL ?? "")|\(mode.rawValue)|\(measured ?? -999)|\(text)"
        let menuKey = "\(isHidden)|\(station?.streamURL ?? "")|\(mode.rawValue)"
        let titleChanged = titleKey != lastStreamQualityTitleKey
        let menuChanged = menuKey != lastStreamQualityMenuKey
        guard titleChanged || menuChanged else { return }
        if titleChanged { lastStreamQualityTitleKey = titleKey }
        if menuChanged { lastStreamQualityMenuKey = menuKey }
        let menu: UIMenu? = menuChanged ? makeStreamQualityMenu() : nil
        controlsView.setStreamQuality(text: text, menu: menu, isHidden: isHidden)
    }

    private func makeStreamQualityMenu() -> UIMenu {
        let current = PlaybackPreferences.shared.streamQualityMode
        let actions = StreamQualityMode.allCases.map { mode -> UIAction in
            UIAction(
                title: streamQualityMenuTitle(for: mode),
                state: mode == current ? .on : .off
            ) { [weak self] _ in
                guard PlaybackPreferences.shared.streamQualityMode != mode else { return }
                PlaybackPreferences.shared.streamQualityMode = mode
                StationsManager.shared.applyCurrentStreamQualityIfNeeded()
                self?.syncBitrateTracking()
                self?.refreshStreamQualityStatus()
            }
        }
        return UIMenu(title: Content.Player.streamQualityMenuTitle, children: actions)
    }

    private func streamQualityMenuTitle(for mode: StreamQualityMode) -> String {
        switch mode {
        case .auto: return Content.Settings.qualityAuto
        case .low: return Content.Settings.qualityLow
        case .medium: return Content.Settings.qualityMedium
        case .high: return Content.Settings.qualityHigh
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        topConstraint?.constant = navigationController != nil ? 16 : 48
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshMarqueeScrollingPause()
    }

    private func isPlayingDidChange(_ isPlaying: Bool) {
        controlsView.setPlaying(isPlaying)
        albumArtworkView.setPlaying(isPlaying)
        updatePopupBarPlayPauseButton(isPlaying: isPlaying)
    }

    func stationDidChange() {
        lastStreamQualityTitleKey = ""
        lastStreamQualityMenuKey = ""
        StreamBitrateTracker.shared.stop()
        syncBitrateTracking()

        albumArtworkView.setImage(nil)
        updateBackground(with: nil)
        manager.currentStation?.getImage { [weak self] image in
            self?.albumArtworkView.setImage(image)
            self?.updateBackground(with: image)
            self?.updatePopupBarImage(image)
        }

        updatePopupBarMetadata()
        updateLabels()
        controlsView.setLive(player.duration == 0)
        refreshStreamQualityStatus()
    }

    func updateLabels() {
        guard let station = manager.currentStation else {
            controlsView.updateNowPlaying(song: nil, artist: nil, stationName: nil, stationDesc: nil)
            updateStarterFMOnAirLine()
            return
        }
        if let line = displayedSongLine() {
            controlsView.updateNowPlaying(
                song: line.song,
                artist: line.artist,
                stationName: station.name,
                stationDesc: station.desc
            )
        } else {
            controlsView.updateNowPlaying(song: nil, artist: nil, stationName: station.name, stationDesc: station.desc)
        }
        updateStarterFMOnAirLine()
    }

    private func updateStarterFMOnAirLine() {
        guard let station = manager.currentStation, station.showsStarterFMShowSchedule else {
            controlsView.setOnAirSchedule(.hidden)
            return
        }
        StarterFMScheduleStore.shared.ensurePollingStarted()
        if StarterFMScheduleStore.shared.scheduleDocument() == nil {
            controlsView.setOnAirSchedule(.unavailable(message: Content.Player.starterFMScheduleUnavailable))
            postOnAirAccessibilityAnnouncement()
            return
        }
        guard let slot = StarterFMScheduleStore.shared.currentSlotNow() else {
            controlsView.setOnAirSchedule(.unavailable(message: Content.Player.starterFMScheduleUnavailable))
            postOnAirAccessibilityAnnouncement()
            return
        }
        controlsView.setOnAirSchedule(.slot(title: slot.title, timeRange: slot.timeRange))
        postOnAirAccessibilityAnnouncement()
    }

    private func postOnAirAccessibilityAnnouncement() {
        guard manager.currentStation?.showsStarterFMShowSchedule == true else { return }
        UIAccessibility.post(notification: .layoutChanged, argument: controlsView)
    }

    /// Text for the mini-player when Starter FM schedule data should appear alongside station / track.
    private func starterFMPopupOnAirSummary() -> String? {
        guard let st = manager.currentStation, st.showsStarterFMShowSchedule else { return nil }
        guard let doc = StarterFMScheduleStore.shared.scheduleDocument() else {
            return Content.Player.starterFMScheduleUnavailable
        }
        guard let slot = StarterFMScheduleEngine.currentSlot(in: doc) else {
            return Content.Player.starterFMScheduleUnavailable
        }
        let p = Content.Player.starterFMOnAirPrefix
        let tz = Content.StarterFMSchedule.timezoneShort
        return "\(p): \(slot.title) · \(slot.timeRange) (\(tz))"
    }

    func playbackStateDidChange(_ playbackState: FRadioPlayer.PlaybackState) {
        isPlayingDidChange(player.isPlaying)
        if playbackState == .playing, player.state == .loading {
            albumArtworkView.setBuffering(true)
        }
    }

    func playerStateDidChange(_ state: FRadioPlayer.State) {
        switch state {
        case .loading where player.playbackState != .stopped:
            albumArtworkView.setBuffering(true)
        case .readyToPlay, .loadingFinished:
            albumArtworkView.setBuffering(false)
            playbackStateDidChange(player.playbackState)
        default:
            albumArtworkView.setBuffering(false)
        }
    }

    // MARK: - Setup Methods

    private func setupViews() {
        // Dynamic blurred background
        view.addSubview(backgroundImageView)
        view.addSubview(backgroundBlurView)
        view.addSubview(backgroundDimView)

        NSLayoutConstraint.activate([
            backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundBlurView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backgroundDimView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        controlsCardView.contentView.addSubview(controlsView)
        controlsView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            controlsView.topAnchor.constraint(equalTo: controlsCardView.contentView.topAnchor, constant: 20),
            controlsView.leadingAnchor.constraint(equalTo: controlsCardView.contentView.leadingAnchor, constant: 18),
            controlsView.trailingAnchor.constraint(equalTo: controlsCardView.contentView.trailingAnchor, constant: -18),
            controlsView.bottomAnchor.constraint(equalTo: controlsCardView.contentView.bottomAnchor, constant: -18),
        ])

        let mainStackView = UIStackView(arrangedSubviews: [albumArtworkView, controlsCardView])
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        mainStackView.distribution = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        controlsView.playingAction = { [unowned self] in
            if player.isPlaying, player.duration == 0 {
                player.stop()
            } else {
                player.togglePlaying()
            }
        }

        controlsView.nextAction = { [unowned self] in
            manager.setNext()
        }

        controlsView.previousAction = { [unowned self] in
            manager.setPrevious()
        }

        controlsView.moreAction = { [unowned self] in
            handleMoreMenu()
        }

        controlsView.onAirScheduleTapAction = { [weak self] in
            guard let self else { return }
            self.delegate?.nowPlayingViewControllerDidRequestStarterFMSchedule(self)
        }

        controlsView.timeAction = { [unowned self] slider, event in
            handleTimeSlider(slider: slider, event: event)
        }

        view.addSubview(mainStackView)

        topConstraint = mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)

        let artworkHeight = albumArtworkView.heightAnchor.constraint(equalTo: mainStackView.heightAnchor, multiplier: 0.55)
        artworkHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topConstraint!,
            mainStackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            mainStackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            mainStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            artworkHeight,
        ])
    }

    // MARK: - Dynamic Background

    private func updateBackground(with image: UIImage?) {
        UIView.transition(
            with: backgroundImageView,
            duration: 0.5,
            options: .transitionCrossDissolve
        ) {
            self.backgroundImageView.image = image
        }
    }

    func updateTrackArtwork() {
        getTrackArtwork { [weak self] image in
            DispatchQueue.main.async {
                self?.albumArtworkView.setImage(image, animated: true)
                self?.updateBackground(with: image)
                self?.updatePopupBarImage(image)
            }
        }
    }

    private func getTrackArtwork(completion: @escaping (UIImage?) -> Void) {
        guard let artworkURL = player.currentArtworkURL else {
            manager.currentStation?.getImage { image in
                completion(image)
            }
            return
        }

        UIImage.image(from: artworkURL) { image in
            completion(image)
        }
    }

    func handleMoreMenu() {
        guard let station = manager.currentStation else { return }
        let bottomSheet = BottomSheetViewController(station: station)
        bottomSheet.delegate = self
        present(bottomSheet, animated: true)
    }

    private func handleTimeSlider(slider: UISlider, event: UIControl.Event) {

        guard player.duration != 0 else { return }

        let seekTime =  TimeInterval(slider.value) * player.duration

        switch event {
        case .valueChanged:
            controlsView.setCurrentTime(seekTime)
            controlsView.setTotalTime(player.duration - seekTime)
        case .touchUpInside:
            player.seek(to: seekTime) { [weak self] in
                self?.controlsView.isSliderSliding = false
            }
        default:
            break
        }
    }

    // MARK: - Popup Bar

    private func updatePopupBarMetadata() {
        guard let station = manager.currentStation else {
            popupItem.title = nil
            popupItem.subtitle = nil
            return
        }
        let onAirSummary = starterFMPopupOnAirSummary()
        if let line = displayedSongLine() {
            popupItem.title = [line.song, line.artist].compactMap { $0 }.joined(separator: " — ")
            if let onAirSummary {
                popupItem.subtitle = [station.name, onAirSummary].joined(separator: " · ")
            } else {
                popupItem.subtitle = station.name
            }
        } else {
            popupItem.title = station.name
            if let onAirSummary {
                popupItem.subtitle = onAirSummary
            } else {
                popupItem.subtitle = station.desc
            }
        }
    }

    private func updatePopupBarImage(_ image: UIImage?) {
        popupItem.image = image
        DispatchQueue.main.async {
            self.popupPresentationContainer?.popupBar.imageView.contentMode = .scaleAspectFill
            self.popupPresentationContainer?.popupBar.imageView.clipsToBounds = true
        }
    }

    private func updatePopupBarPlayPauseButton(isPlaying: Bool) {
        let isLive = player.duration == 0
        let imageName = isPlaying ? (isLive ? "stop.fill" : "pause.fill") : "play.fill"
        playPauseButton.image = UIImage(systemName: imageName)
    }

    @objc private func popupBarPlayPauseTapped() {
        if player.isPlaying, player.duration == 0 {
            player.stop()
        } else {
            player.togglePlaying()
        }
    }
}

extension NowPlayingViewController: FRadioPlayerObserver {

    func radioPlayer(_ player: FRadioPlayer, playerStateDidChange state: FRadioPlayer.State) {
        playerStateDidChange(state)
    }

    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
        playbackStateDidChange(state)
    }

    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        updateLabels()
        updatePopupBarMetadata()
    }

    func radioPlayer(_ player: FRadioPlayer, artworkDidChange artworkURL: URL?) {
        updateTrackArtwork()
    }

    func radioPlayer(_ player: FRadioPlayer, durationDidChange duration: TimeInterval) {
        controlsView.setLive(player.duration == 0)
        refreshStreamQualityStatus()
    }

    func radioPlayer(_ player: FRadioPlayer, itemDidChange url: URL?) {
        StreamBitrateTracker.shared.resetMeasuredBitrate()
        syncBitrateTracking()
        refreshStreamQualityStatus()
    }

    func radioPlayer(_ player: FRadioPlayer, playTimeDidChange currentTime: TimeInterval, duration: TimeInterval) {
        guard !controlsView.isSliderSliding, player.duration != 0 else { return }

        // Update timer labels
        controlsView.setCurrentTime(currentTime)
        controlsView.setTotalTime(duration - currentTime)
        controlsView.setTimeSilder(value: Float(currentTime / duration))

        // Update popup bar progress
        popupItem.progress = Float(currentTime / duration)
    }
}

extension NowPlayingViewController: StationsManagerObserver {

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        stationDidChange()
    }
}

extension NowPlayingViewController: BottomSheetViewControllerDelegate {

    func bottomSheet(_ controller: BottomSheetViewController, didSelect option: BottomSheetViewController.Option) {
        if case .share = option {
            getTrackArtwork { [weak self] image in
                guard let self = self else { return }
                self.delegate?.didSelectBottomSheetOption(.share(image), from: self)
            }
        } else if case .openInMusic = option {
            delegate?.didSelectBottomSheetOption(.openInMusic(manager.currentStation?.musicSearchURL), from: self)
        } else {
            delegate?.didSelectBottomSheetOption(option, from: self)
        }
    }
}

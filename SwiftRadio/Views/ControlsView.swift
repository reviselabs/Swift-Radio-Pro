//
//  ControlsView.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2024-01-14.
//  Copyright © 2024 matthewfecher.com. All rights reserved.
//

import UIKit
import AVKit
import MarqueeLabel

class ControlsView: UIView {

    var timeAction: ((UISlider, UIControl.Event) -> Void)?

    var playingAction: (() -> Void)?
    var nextAction: (() -> Void)?
    var previousAction: (() -> Void)?

    var moreAction: (() -> Void)?

    /// Starter FM: tap the on-air row to open the full schedule (same as “Show schedule” in the menu).
    var onAirScheduleTapAction: (() -> Void)?

    var isSliderSliding = false

    private var isLive = true

    private var contentSizeCategoryObserver: NSObjectProtocol?

    enum OnAirScheduleState: Equatable {
        case hidden
        case slot(title: String, timeRange: String)
        case unavailable(message: String)
    }

    /// Status text updates often (bitrate); the chevron uses a **separate** button + `UIMenu` so `UIButton.Configuration` title updates cannot strip the menu.
    private let streamQualityContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let streamQualityLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = UIColor.white.withAlphaComponent(0.82)
        label.numberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.isAccessibilityElement = false
        label.isUserInteractionEnabled = true
        return label
    }()

    private let streamQualityMenuButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()

    // Row 1: song — artist (or station name when no metadata)
    private let titleLabel: MarqueeLabel = {
        let label = MarqueeLabel(frame: .zero, rate: 30, fadeLength: 10)
        label.textAlignment = .center
        label.textColor = .white
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.trailingBuffer = 30
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    // Row 2: station name (or station desc when no metadata)
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white.withAlphaComponent(0.8)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.alpha = 1
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 2
        return label
    }()

    /// Starter FM: tappable area with marquee title + time (Sydney), or unavailable message.
    private let onAirContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        v.layer.cornerRadius = 10
        v.clipsToBounds = true
        v.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        return v
    }()

    private let onAirStack: UIStackView = {
        let s = UIStackView()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.axis = .vertical
        s.spacing = 3
        s.alignment = .fill
        return s
    }()

    private let onAirTitleMarquee: MarqueeLabel = {
        let label = MarqueeLabel(frame: .zero, rate: 26, fadeLength: 8)
        label.textAlignment = .center
        label.textColor = UIColor.white.withAlphaComponent(0.92)
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()

    private let onAirTimeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.white.withAlphaComponent(0.68)
        label.numberOfLines = 2
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()

    private let onAirUnavailableLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        label.isAccessibilityElement = false
        return label
    }()

    private let timeSlider: ThinSlider = {
        let slider = ThinSlider()
        slider.value = 0.0
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = Config.tintColor
        slider.maximumTrackTintColor = Config.tintColor.withAlphaComponent(0.3)
        return slider
    }()

    private let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.textAlignment = .left
        label.alpha = 0.8
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let totalTimeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00"
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.textAlignment = .right
        label.alpha = 0.8
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private let liveBadge: UIView = {
        let container = UIView()
        container.isHidden = true

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
        blur.layer.cornerRadius = 6
        blur.clipsToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = Content.Player.liveBadge
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        blur.contentView.addSubview(label)
        container.addSubview(blur)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: blur.contentView.topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor, constant: -4),
            label.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor, constant: -12),
            blur.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            blur.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }()

    private let playPauseButton: UIButton = {
        let button = UIButton()
        button.tintColor = UIColor(red: 20 / 255, green: 28 / 255, blue: 45 / 255, alpha: 1)
        button.backgroundColor = Config.tintColor
        button.layer.cornerRadius = 32
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 64),
            button.heightAnchor.constraint(equalToConstant: 64),
        ])
        return button
    }()

    private let nextButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        button.setImage(UIImage(systemName: "forward.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48),
        ])
        return button
    }()

    private let previousButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        button.setImage(UIImage(systemName: "backward.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48),
        ])
        return button
    }()

    private let airPlayButton: AVRoutePickerView = {
        let button = AVRoutePickerView()
        button.activeTintColor = Config.tintColor
        button.tintColor = .white.withAlphaComponent(0.85)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return button
    }()

    private let moreButton: UIButton = {
        let button = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "ellipsis", withConfiguration: config), for: .normal)
        button.tintColor = .white.withAlphaComponent(0.85)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyDynamicTypeFonts()
        setupViews()
        contentSizeCategoryObserver = NotificationCenter.default.addObserver(
            forName: UIContentSizeCategory.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyDynamicTypeFonts()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let contentSizeCategoryObserver {
            NotificationCenter.default.removeObserver(contentSizeCategoryObserver)
        }
    }

    private func applyDynamicTypeFonts() {
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: UIFont.systemFont(ofSize: 22, weight: .bold))
        subtitleLabel.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: UIFont.systemFont(ofSize: 16, weight: .medium))
        onAirTitleMarquee.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: UIFont.systemFont(ofSize: 14, weight: .semibold))
        onAirTimeLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: UIFont.systemFont(ofSize: 12, weight: .medium))
        onAirUnavailableLabel.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: UIFont.systemFont(ofSize: 13, weight: .medium))
        currentTimeLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .medium))
        totalTimeLabel.font = UIFontMetrics(forTextStyle: .caption2).scaledFont(for: UIFont.systemFont(ofSize: 10, weight: .medium))
        streamQualityLabel.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: UIFont.systemFont(ofSize: 12, weight: .semibold))
        titleLabel.restartLabel()
        onAirTitleMarquee.restartLabel()
    }

    /// Pauses MarqueeLabel animations (e.g. while the LNPopup mini bar is showing) to avoid main-thread stalls during interactive transitions.
    func setMarqueeScrollingPaused(_ paused: Bool) {
        titleLabel.holdScrolling = paused
        onAirTitleMarquee.holdScrolling = paused
    }

    func setPlaying(_ isPlaying: Bool) {
        playPauseButton.isSelected = isPlaying
    }

    func setLive(_ isLive: Bool) {
        self.isLive = isLive
        timeSlider.isEnabled = !isLive
        timeSlider.showThumb = !isLive
        currentTimeLabel.isHidden = isLive
        totalTimeLabel.isHidden = isLive
        liveBadge.isHidden = !isLive
        updatePlayPauseImages()
    }

    func setCurrentTime(_ secounds: TimeInterval) {
        currentTimeLabel.text = formatSecondsToString(secounds)
    }

    func setTotalTime(_ secounds: TimeInterval) {
        totalTimeLabel.text = "-" + formatSecondsToString(secounds)
    }

    func setTimeSilder(value: Float) {
        timeSlider.value = value
    }

    /// Update the two-row labels, mirroring the popup bar layout.
    /// - When metadata exists: row 1 = "Song — Artist", row 2 = station name
    /// - When no metadata: row 1 = station name, row 2 = station description
    func updateNowPlaying(song: String?, artist: String?, stationName: String?, stationDesc: String?) {
        if let song {
            titleLabel.text = [song, artist].compactMap { $0 }.joined(separator: " — ")
            subtitleLabel.text = stationName
        } else {
            titleLabel.text = stationName
            subtitleLabel.text = stationDesc
        }
        titleLabel.restartLabel()
    }

    func setOnAirSchedule(_ state: OnAirScheduleState) {
        switch state {
        case .hidden:
            onAirContainer.isHidden = true
            onAirContainer.isUserInteractionEnabled = false
            onAirContainer.accessibilityTraits = .staticText
            onAirContainer.accessibilityHint = nil
            onAirTitleMarquee.text = nil
            onAirTimeLabel.text = nil
            onAirUnavailableLabel.text = nil
            onAirTitleMarquee.isHidden = true
            onAirTimeLabel.isHidden = true
            onAirUnavailableLabel.isHidden = true

        case .slot(let title, let timeRange):
            onAirContainer.isHidden = false
            onAirContainer.isUserInteractionEnabled = true
            onAirTitleMarquee.isHidden = false
            onAirTimeLabel.isHidden = false
            onAirUnavailableLabel.isHidden = true
            let prefix = Content.Player.starterFMOnAirPrefix
            onAirTitleMarquee.text = "\(prefix): \(title)"
            let tz = Content.StarterFMSchedule.timezoneShort
            onAirTimeLabel.text = "\(timeRange) · \(tz)"
            onAirTitleMarquee.restartLabel()
            onAirContainer.accessibilityLabel = "\(prefix). \(title). \(timeRange). \(Content.StarterFMSchedule.timezoneFooter)"
            onAirContainer.accessibilityTraits = .button
            onAirContainer.accessibilityHint = Content.Accessibility.starterFMOnAirHint

        case .unavailable(let message):
            onAirContainer.isHidden = false
            onAirContainer.isUserInteractionEnabled = true
            onAirTitleMarquee.isHidden = true
            onAirTimeLabel.isHidden = true
            onAirUnavailableLabel.isHidden = false
            onAirUnavailableLabel.text = message
            onAirContainer.accessibilityLabel = "\(message). \(Content.StarterFMSchedule.timezoneFooter)"
            onAirContainer.accessibilityTraits = .button
            onAirContainer.accessibilityHint = Content.Accessibility.starterFMOnAirHint
        }
    }

    @objc private func onAirContainerTapped() {
        onAirScheduleTapAction?()
    }

    @objc private func streamQualityLabelTapped() {
        guard streamQualityMenuButton.menu != nil else { return }
        // `showsMenuAsPrimaryAction` is driven by primary action, not always `touchUpInside`.
        streamQualityMenuButton.sendActions(for: .primaryActionTriggered)
    }

    /// - Parameter menu: Pass `nil` to keep the existing menu when only the status line changed. Pass a new menu when mode/station changes.
    func setStreamQuality(text: String, menu: UIMenu?, isHidden: Bool) {
        streamQualityContainer.isHidden = isHidden
        if isHidden {
            streamQualityMenuButton.menu = nil
            streamQualityLabel.text = nil
            return
        }

        streamQualityLabel.text = text
        if let menu {
            streamQualityMenuButton.menu = menu
        }
        streamQualityMenuButton.showsMenuAsPrimaryAction = (streamQualityMenuButton.menu != nil)
        let summary = Content.Player.streamQualityMenuTitle
        streamQualityMenuButton.accessibilityLabel = "\(summary). \(text)"
    }

    private func applyStreamQualityMenuButtonChrome() {
        var cfg = UIButton.Configuration.plain()
        let sym = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        cfg.image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: sym)
        cfg.preferredSymbolConfigurationForImage = sym
        cfg.baseForegroundColor = UIColor.white.withAlphaComponent(0.82)
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        streamQualityMenuButton.configuration = cfg
    }

    // MARK: - Private

    private func updatePlayPauseImages() {
        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        let selectedName = isLive ? "stop.fill" : "pause.fill"
        playPauseButton.setImage(UIImage(systemName: selectedName, withConfiguration: config), for: .selected)
    }

    private func formatSecondsToString(_ secounds: TimeInterval) -> String {
        guard secounds != 0 else { return "00:00" }
        let min = Int(secounds / 60)
        let sec = Int(secounds.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", min, sec)
    }

    private func setupViews() {
        onAirStack.isAccessibilityElement = false
        onAirStack.addArrangedSubview(onAirTitleMarquee)
        onAirStack.addArrangedSubview(onAirTimeLabel)
        onAirStack.addArrangedSubview(onAirUnavailableLabel)
        onAirContainer.addSubview(onAirStack)

        NSLayoutConstraint.activate([
            onAirStack.topAnchor.constraint(equalTo: onAirContainer.topAnchor, constant: 8),
            onAirStack.leadingAnchor.constraint(equalTo: onAirContainer.leadingAnchor, constant: 10),
            onAirStack.trailingAnchor.constraint(equalTo: onAirContainer.trailingAnchor, constant: -10),
            onAirStack.bottomAnchor.constraint(equalTo: onAirContainer.bottomAnchor, constant: -8),
        ])

        let onAirTap = UITapGestureRecognizer(target: self, action: #selector(onAirContainerTapped))
        onAirContainer.addGestureRecognizer(onAirTap)
        onAirContainer.isAccessibilityElement = true

        let streamQualityInner = UIStackView(arrangedSubviews: [streamQualityLabel, streamQualityMenuButton])
        streamQualityInner.axis = .horizontal
        streamQualityInner.alignment = .center
        streamQualityInner.spacing = 6
        streamQualityInner.translatesAutoresizingMaskIntoConstraints = false

        streamQualityContainer.addSubview(streamQualityInner)
        NSLayoutConstraint.activate([
            streamQualityInner.centerXAnchor.constraint(equalTo: streamQualityContainer.centerXAnchor),
            streamQualityInner.topAnchor.constraint(equalTo: streamQualityContainer.topAnchor),
            streamQualityInner.bottomAnchor.constraint(equalTo: streamQualityContainer.bottomAnchor),
            streamQualityInner.leadingAnchor.constraint(greaterThanOrEqualTo: streamQualityContainer.leadingAnchor),
            streamQualityInner.trailingAnchor.constraint(lessThanOrEqualTo: streamQualityContainer.trailingAnchor),
        ])
        applyStreamQualityMenuButtonChrome()
        let labelTap = UITapGestureRecognizer(target: self, action: #selector(streamQualityLabelTapped))
        streamQualityLabel.addGestureRecognizer(labelTap)

        let mainStackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, onAirContainer, streamQualityContainer, sliderContainerView, buttonsStackView, menuStackView])
        mainStackView.axis = .vertical
        mainStackView.spacing = 8
        mainStackView.alignment = .fill

        mainStackView.setCustomSpacing(4, after: titleLabel)
        mainStackView.setCustomSpacing(10, after: subtitleLabel)
        mainStackView.setCustomSpacing(6, after: onAirContainer)
        mainStackView.setCustomSpacing(14, after: streamQualityContainer)

        mainStackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(mainStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - StackViews

    /// Slider with LIVE badge overlaid above it, and time labels below.
    private var sliderContainerView: UIView {
        let spacer1 = UIView()
        spacer1.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let spacer2 = UIView()
        spacer2.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let timeLabelsStackView = UIStackView(arrangedSubviews: [currentTimeLabel, spacer1, spacer2, totalTimeLabel])
        timeLabelsStackView.axis = .horizontal
        timeLabelsStackView.distribution = .fillEqually
        timeLabelsStackView.alignment = .fill

        let vStackView = UIStackView(arrangedSubviews: [timeSlider, timeLabelsStackView])
        vStackView.axis = .vertical
        vStackView.distribution = .fill
        vStackView.alignment = .fill
        vStackView.spacing = 4

        // Wrap in a container so we can overlay the LIVE badge
        let container = UIView()
        vStackView.translatesAutoresizingMaskIntoConstraints = false
        liveBadge.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(vStackView)
        container.addSubview(liveBadge)

        NSLayoutConstraint.activate([
            vStackView.topAnchor.constraint(equalTo: container.topAnchor),
            vStackView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            vStackView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            vStackView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            liveBadge.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            liveBadge.centerYAnchor.constraint(equalTo: timeSlider.centerYAnchor),
        ])

        return container
    }

    private var buttonsStackView: UIStackView {
        let hStackView = UIStackView(arrangedSubviews: [previousButton, playPauseButton, nextButton])
        hStackView.axis = .horizontal
        hStackView.spacing = 28
        hStackView.alignment = .center

        playPauseButton.addTarget(self, action: #selector(playingPressed), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextPressed), for: .touchUpInside)
        previousButton.addTarget(self, action: #selector(previousPressed), for: .touchUpInside)

        nextButton.isHidden = Config.hideNextPreviousButtons
        previousButton.isHidden = Config.hideNextPreviousButtons

        let vStackView = UIStackView(arrangedSubviews: [hStackView])
        vStackView.axis = .vertical
        vStackView.distribution = .fill
        vStackView.alignment = .center

        return vStackView
    }

    private var menuStackView: UIStackView {
        let stackView = UIStackView(arrangedSubviews: [airPlayButton, moreButton])
        stackView.axis = .horizontal
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.distribution = .fill

        moreButton.addTarget(self, action: #selector(morePressed), for: .touchUpInside)
        timeSlider.addTarget(self, action: #selector(timeSliderTouchBegan(sender:)), for: .touchDown)
        timeSlider.addTarget(self, action: #selector(timeSliderValueChanged(sender:)), for: .valueChanged)
        timeSlider.addTarget(self, action: #selector(timeSliderTouchEnded(sender:)), for: [.touchUpInside, .touchCancel, .touchUpOutside])

        let containerStack = UIStackView(arrangedSubviews: [stackView])
        containerStack.axis = .vertical
        containerStack.alignment = .center

        return containerStack
    }

    // MARK: - Actions

    @objc private func playingPressed(_ sender: Any) {
        playingAction?()
    }

    @objc private func nextPressed(_ sender: Any) {
        nextAction?()
    }

    @objc private func previousPressed(_ sender: Any) {
        previousAction?()
    }

    @objc private func morePressed(_ sender: Any) {
        moreAction?()
    }

    @objc private func timeSliderTouchBegan(sender: UISlider) {
        isSliderSliding = true
        timeAction?(sender, .touchDown)
    }

    @objc private func timeSliderValueChanged(sender: UISlider) {
        timeAction?(sender, .valueChanged)
    }

    @objc private func timeSliderTouchEnded(sender: UISlider) {
        timeAction?(sender, .touchUpInside)
    }
}

// MARK: - UIFont Extension

private extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}

// MARK: - ThinSlider

private class ThinSlider: UISlider {

    private let trackHeight: CGFloat = 2
    private let normalThumbSize: CGFloat = 10
    private let highlightedThumbSize: CGFloat = 16

    var showThumb: Bool = false {
        didSet { updateThumbImages() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        updateThumbImages()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let center = bounds.midY
        return CGRect(x: bounds.minX, y: center - trackHeight / 2, width: bounds.width, height: trackHeight)
    }

    private func updateThumbImages() {
        if showThumb {
            setThumbImage(makeThumbImage(size: normalThumbSize), for: .normal)
            setThumbImage(makeThumbImage(size: highlightedThumbSize), for: .highlighted)
        } else {
            setThumbImage(UIImage(), for: .normal)
            setThumbImage(UIImage(), for: .highlighted)
        }
    }

    private func makeThumbImage(size: CGFloat) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { context in
            Config.tintColor.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        }
    }
}

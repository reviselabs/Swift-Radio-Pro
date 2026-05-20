//
//  StationDetailViewController.swift
//  SwiftRadio
//

import UIKit
import FRadioPlayer
import SafariServices
import NVActivityIndicatorView

final class StationDetailViewController: BaseController {

    private let station: RadioStation
    private let playAction: (RadioStation) -> Void

    private let player = FRadioPlayer.shared
    private let manager = StationsManager.shared

    private var externalNowPlayingObserver: NSObjectProtocol?
    private var scheduleObserver: NSObjectProtocol?
    private var podcastModeObserver: NSObjectProtocol?
    private var favoritesObserver: NSObjectProtocol?

    private var todaySlots: [StarterFMShowSlot] = []
    private var nowPlayingWrapper: UIView?
    private var scheduleSection: UIView?

    // MARK: - Header UI

    private let logoImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 16
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 22, weight: .bold)
        lbl.textColor = .white
        lbl.numberOfLines = 2
        return lbl
    }()

    private let descLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = UIColor.white.withAlphaComponent(0.7)
        lbl.numberOfLines = 2
        return lbl
    }()

    private lazy var playCircleButton: UIButton = {
        let button = UIButton()
        let sym = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        button.setImage(UIImage(systemName: "play.fill", withConfiguration: sym), for: .normal)
        button.tintColor = UIColor(red: 20/255, green: 28/255, blue: 45/255, alpha: 1)
        button.backgroundColor = Config.tintColor
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        button.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var favoriteCircleButton: UIButton = {
        let button = UIButton()
        let sym = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        button.setImage(UIImage(systemName: "star", withConfiguration: sym), for: .normal)
        button.tintColor = Config.tintColor
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        button.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        return button
    }()

    private lazy var shareCircleButton: UIButton = {
        let button = UIButton()
        let sym = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        button.setImage(UIImage(systemName: "square.and.arrow.up", withConfiguration: sym), for: .normal)
        button.tintColor = UIColor.white.withAlphaComponent(0.85)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 22
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
        ])
        button.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Now Playing card

    private let nowPlayingEqualizerView: NVActivityIndicatorView = {
        let v = NVActivityIndicatorView(frame: .zero, type: .audioEqualizer, color: Config.tintColor, padding: nil)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nowPlayingCard: UIView = {
        let v = UIView()
        v.backgroundColor = Config.tintColor.withAlphaComponent(0.15)
        v.layer.cornerRadius = 14
        v.layer.borderWidth = 1
        v.layer.borderColor = Config.tintColor.withAlphaComponent(0.3).cgColor
        v.clipsToBounds = true
        return v
    }()

    private let nowPlayingHeaderLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "NOW PLAYING"
        lbl.font = .systemFont(ofSize: 10, weight: .semibold)
        lbl.textColor = Config.tintColor
        return lbl
    }()

    private let nowPlayingTrackLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 15, weight: .medium)
        lbl.textColor = .white
        lbl.numberOfLines = 2
        return lbl
    }()

    // MARK: - Schedule

    private let scheduleTitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Today's Schedule"
        lbl.font = .systemFont(ofSize: 17, weight: .bold)
        lbl.textColor = .white
        return lbl
    }()

    private let scheduleDateLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13)
        lbl.textColor = UIColor.white.withAlphaComponent(0.55)
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        lbl.setContentCompressionResistancePriority(.required, for: .horizontal)
        return lbl
    }()

    private let scheduleSlotsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        return s
    }()

    // MARK: - Info

    private let longDescLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = UIColor.white.withAlphaComponent(0.85)
        lbl.numberOfLines = 0
        return lbl
    }()

    private lazy var websiteButton: UIButton = {
        var config = UIButton.Configuration.plain()
        var attr = AttributedString(Content.StationDetail.visitWebsite)
        attr.font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: .init(legibilityWeight: .bold))
        config.attributedTitle = attr
        config.image = UIImage(systemName: "safari")
        config.baseForegroundColor = .white
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        let btn = UIButton(configuration: config)
        btn.contentHorizontalAlignment = .leading
        btn.addTarget(self, action: #selector(websiteTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Scroll

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Init

    init(station: RadioStation, playAction: @escaping (RadioStation) -> Void) {
        self.station = station
        self.playAction = playAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = station.name
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.backButtonDisplayMode = .minimal

        buildLayout()
        populateStaticContent()
        loadImage()
        updatePlayButton()
        updateFavoriteButton()
        updateNowPlayingSection()
        if station.showsStarterFMShowSchedule {
            reloadScheduleData()
        }
        setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePlayButton()
        updateFavoriteButton()
        updateNowPlayingSection()
        if station.showsStarterFMShowSchedule {
            reloadScheduleData()
        }
    }

    deinit {
        [externalNowPlayingObserver, scheduleObserver, podcastModeObserver, favoritesObserver]
            .compactMap { $0 }.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - View setup

    override func setupViews() {
        super.setupViews()
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Layout construction

    private func buildLayout() {
        let header = buildHeader()
        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(16, after: header)

        buildNowPlayingCardContent()
        let npWrapper = makeHorizontallyPadded(nowPlayingCard)
        nowPlayingWrapper = npWrapper
        npWrapper.isHidden = true
        contentStack.addArrangedSubview(npWrapper)
        contentStack.setCustomSpacing(20, after: npWrapper)

        if station.showsStarterFMShowSchedule {
            let sched = buildScheduleSection()
            scheduleSection = sched
            sched.isHidden = true
            contentStack.addArrangedSubview(sched)
            contentStack.setCustomSpacing(8, after: sched)
        }

        contentStack.addArrangedSubview(makeSeparator())

        longDescLabel.translatesAutoresizingMaskIntoConstraints = false
        let descContainer = UIView()
        descContainer.addSubview(longDescLabel)
        NSLayoutConstraint.activate([
            longDescLabel.topAnchor.constraint(equalTo: descContainer.topAnchor, constant: 16),
            longDescLabel.leadingAnchor.constraint(equalTo: descContainer.leadingAnchor, constant: 20),
            longDescLabel.trailingAnchor.constraint(equalTo: descContainer.trailingAnchor, constant: -20),
            longDescLabel.bottomAnchor.constraint(equalTo: descContainer.bottomAnchor, constant: -16),
        ])
        contentStack.addArrangedSubview(descContainer)

        if station.hasValidWebsite {
            contentStack.addArrangedSubview(makeSeparator())
            contentStack.addArrangedSubview(makeWebsiteRow())
        }

        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        contentStack.addArrangedSubview(spacer)
    }

    private func buildHeader() -> UIView {
        let buttonRow = UIStackView(arrangedSubviews: [playCircleButton, favoriteCircleButton, shareCircleButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 12

        let textStack = UIStackView(arrangedSubviews: [nameLabel, descLabel, buttonRow])
        textStack.axis = .vertical
        textStack.spacing = 5
        textStack.setCustomSpacing(14, after: descLabel)
        textStack.alignment = .leading

        let row = UIStackView(arrangedSubviews: [logoImageView, textStack])
        row.axis = .horizontal
        row.spacing = 16
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(row)
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])
        return container
    }

    private func buildNowPlayingCardContent() {
        let textStack = UIStackView(arrangedSubviews: [nowPlayingHeaderLabel, nowPlayingTrackLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [nowPlayingEqualizerView, textStack])
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        nowPlayingCard.addSubview(row)

        NSLayoutConstraint.activate([
            nowPlayingEqualizerView.widthAnchor.constraint(equalToConstant: 24),
            nowPlayingEqualizerView.heightAnchor.constraint(equalToConstant: 24),
            row.topAnchor.constraint(equalTo: nowPlayingCard.topAnchor, constant: 14),
            row.leadingAnchor.constraint(equalTo: nowPlayingCard.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: nowPlayingCard.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: nowPlayingCard.bottomAnchor, constant: -14),
        ])
    }

    private func buildScheduleSection() -> UIView {
        let container = UIView()

        scheduleTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        scheduleDateLabel.translatesAutoresizingMaskIntoConstraints = false
        scheduleSlotsStack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView(arrangedSubviews: [scheduleTitleLabel, scheduleDateLabel])
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center
        headerRow.translatesAutoresizingMaskIntoConstraints = false

        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true

        container.addSubview(headerRow)
        container.addSubview(sep)
        container.addSubview(scheduleSlotsStack)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            headerRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            headerRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            sep.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 12),
            sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            scheduleSlotsStack.topAnchor.constraint(equalTo: sep.bottomAnchor),
            scheduleSlotsStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scheduleSlotsStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scheduleSlotsStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // MARK: - Data

    private func populateStaticContent() {
        nameLabel.text = station.name
        descLabel.text = station.desc
        longDescLabel.text = station.longDesc.isEmpty
            ? Content.StationDetail.defaultDescription
            : station.longDesc

        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        df.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        scheduleDateLabel.text = df.string(from: Date())
    }

    private func loadImage() {
        station.getImage { [weak self] image in
            self?.logoImageView.image = image
        }
    }

    // MARK: - Dynamic state

    private func updatePlayButton() {
        let isThisStation = !PodcastPlaybackService.shared.isPodcastMode
            && station == manager.currentStation
        let sym = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        if isThisStation && player.isPlaying {
            playCircleButton.setImage(UIImage(systemName: "waveform", withConfiguration: sym), for: .normal)
        } else {
            playCircleButton.setImage(UIImage(systemName: "play.fill", withConfiguration: sym), for: .normal)
        }
    }

    private func updateFavoriteButton() {
        let isFav = FavoriteStationsStore.shared.isFavorite(station)
        let sym = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        favoriteCircleButton.setImage(
            UIImage(systemName: isFav ? "star.fill" : "star", withConfiguration: sym),
            for: .normal
        )
    }

    private func updateNowPlayingSection() {
        let isThisStation = !PodcastPlaybackService.shared.isPodcastMode
            && station == manager.currentStation
        let hasICY = player.currentMetadata?.isEmpty == false
        let hasExternal = station.nowPlayingURL != nil
            && StationNowPlayingService.shared.hasExternalMetadata(for: station)

        guard isThisStation, hasICY || hasExternal else {
            nowPlayingWrapper?.isHidden = true
            nowPlayingEqualizerView.stopAnimating()
            return
        }
        nowPlayingTrackLabel.text = "\(station.trackName) — \(station.artistName)"
        nowPlayingWrapper?.isHidden = false
        if player.isPlaying {
            nowPlayingEqualizerView.startAnimating()
        } else {
            nowPlayingEqualizerView.stopAnimating()
        }
    }

    // MARK: - Schedule

    private func reloadScheduleData() {
        guard let doc = StarterFMScheduleStore.shared.scheduleDocument() else {
            scheduleSection?.isHidden = true
            return
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        let key = StarterFMScheduleEngine.dayKey(for: Date(), calendar: cal)
        todaySlots = doc.days.first { $0.dayKey == key }?.slots ?? []
        scheduleSection?.isHidden = todaySlots.isEmpty
        rebuildSlotRows()
    }

    private enum SlotDisplayState { case past, live, next, upcoming }

    private func slotDisplayState(
        for slot: StarterFMShowSlot,
        currentSlot: StarterFMShowSlot?,
        nextSlot: StarterFMShowSlot?
    ) -> SlotDisplayState {
        if slot == currentSlot { return .live }
        if slot == nextSlot { return .next }
        guard let endMin = StarterFMScheduleEngine.minutes(fromHHmm: slot.end),
              let startMin = StarterFMScheduleEngine.minutes(fromHHmm: slot.start) else { return .upcoming }
        // Skip past-check for midnight-crossing slots to avoid false positives
        guard endMin > startMin else { return .upcoming }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        let now = Date()
        let nowMinutes = Int(now.timeIntervalSince(cal.startOfDay(for: now)) / 60)
        return endMin <= nowMinutes ? .past : .upcoming
    }

    private func findNextSlot(after currentSlot: StarterFMShowSlot?) -> StarterFMShowSlot? {
        if let current = currentSlot {
            guard let idx = todaySlots.firstIndex(of: current), idx + 1 < todaySlots.count else { return nil }
            return todaySlots[idx + 1]
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney") ?? .current
        let now = Date()
        let nowMinutes = Int(now.timeIntervalSince(cal.startOfDay(for: now)) / 60)
        return todaySlots.first {
            guard let start = StarterFMScheduleEngine.minutes(fromHHmm: $0.start) else { return false }
            return start > nowMinutes
        }
    }

    private func rebuildSlotRows() {
        scheduleSlotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let currentSlot = StarterFMScheduleStore.shared.currentSlotNow()
        let nextSlot = findNextSlot(after: currentSlot)
        for (i, slot) in todaySlots.enumerated() {
            let state = slotDisplayState(for: slot, currentSlot: currentSlot, nextSlot: nextSlot)
            scheduleSlotsStack.addArrangedSubview(makeSlotRow(slot, state: state, addSeparator: i > 0))
        }
    }

    private func makeSlotRow(_ slot: StarterFMShowSlot, state: SlotDisplayState, addSeparator: Bool) -> UIView {
        let container = UIView()

        if addSeparator {
            let sep = UIView()
            sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            sep.translatesAutoresizingMaskIntoConstraints = false
            sep.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
            container.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.topAnchor.constraint(equalTo: container.topAnchor),
                sep.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            ])
        }

        let isPast = state == .past
        let startTime = slot.timeRange.components(separatedBy: " - ").first ?? slot.timeRange

        let timeLabel = UILabel()
        timeLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        timeLabel.text = startTime
        timeLabel.textColor = state == .live
            ? Config.tintColor
            : UIColor.white.withAlphaComponent(isPast ? 0.3 : 0.55)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.widthAnchor.constraint(equalToConstant: 76).isActive = true

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 14, weight: state == .live ? .semibold : .regular)
        titleLabel.textColor = UIColor.white.withAlphaComponent(isPast ? 0.35 : 1.0)
        titleLabel.text = slot.title
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail

        var middleViews: [UIView] = [titleLabel]
        if !slot.description.isEmpty {
            let hostLabel = UILabel()
            hostLabel.font = .systemFont(ofSize: 12)
            hostLabel.textColor = UIColor.white.withAlphaComponent(isPast ? 0.25 : 0.55)
            hostLabel.text = slot.description
            hostLabel.numberOfLines = 1
            middleViews.append(hostLabel)
        }
        let titleStack = UIStackView(arrangedSubviews: middleViews)
        titleStack.axis = .vertical
        titleStack.spacing = 2

        var rowViews: [UIView] = [timeLabel, titleStack]
        if let badge = makeSlotBadge(for: state) { rowViews.append(badge) }

        let rowStack = UIStackView(arrangedSubviews: rowViews)
        rowStack.axis = .horizontal
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            rowStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            rowStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),
        ])
        return container
    }

    private func makeSlotBadge(for state: SlotDisplayState) -> UIView? {
        switch state {
        case .past:
            return nil

        case .live:
            let dot = UIView()
            dot.backgroundColor = .systemGreen
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true

            let label = UILabel()
            label.text = "LIVE"
            label.font = .systemFont(ofSize: 11, weight: .bold)
            label.textColor = .systemGreen

            let stack = UIStackView(arrangedSubviews: [dot, label])
            stack.axis = .horizontal
            stack.spacing = 5
            stack.alignment = .center
            stack.setContentHuggingPriority(.required, for: .horizontal)
            stack.setContentCompressionResistancePriority(.required, for: .horizontal)
            return stack

        case .next:
            let label = UILabel()
            label.text = "NEXT"
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = UIColor.white.withAlphaComponent(0.55)
            label.setContentHuggingPriority(.required, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            return label

        case .upcoming:
            let sym = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let iv = UIImageView(image: UIImage(systemName: "clock", withConfiguration: sym))
            iv.tintColor = UIColor.white.withAlphaComponent(0.3)
            iv.contentMode = .scaleAspectFit
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.widthAnchor.constraint(equalToConstant: 16).isActive = true
            iv.heightAnchor.constraint(equalToConstant: 16).isActive = true
            return iv
        }
    }

    // MARK: - Observers

    private func setupObservers() {
        player.addObserver(self)
        manager.addObserver(self)

        externalNowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .externalNowPlayingMetadataDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in self?.updateNowPlayingSection() }

        podcastModeObserver = NotificationCenter.default.addObserver(
            forName: .podcastPlaybackDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.updatePlayButton()
            self?.updateNowPlayingSection()
        }

        favoritesObserver = NotificationCenter.default.addObserver(
            forName: .favoriteStationsDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.updateFavoriteButton() }

        if station.showsStarterFMShowSchedule {
            scheduleObserver = NotificationCenter.default.addObserver(
                forName: .starterFMScheduleCurrentShowDidChange, object: nil, queue: .main
            ) { [weak self] _ in self?.reloadScheduleData() }
        }
    }

    // MARK: - Actions

    @objc private func playButtonTapped() {
        playAction(station)
    }

    @objc private func favoriteTapped() {
        FavoriteStationsStore.shared.toggleFavorite(station)
        updateFavoriteButton()
    }

    @objc private func shareTapped() {
        station.getImage { [weak self] image in
            guard let self else { return }
            ShareActivity.activityController(image: image, station: self.station, sourceView: self.shareCircleButton) { [weak self] vc in
                self?.present(vc, animated: true)
            }
        }
    }

    @objc private func websiteTapped() {
        guard station.hasValidWebsite, let website = station.website, let url = URL(string: website) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: - Layout helpers

    private func makeHorizontallyPadded(_ child: UIView, inset: CGFloat = 20) -> UIView {
        child.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: container.topAnchor),
            child.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            child.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            child.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
        ])
        return container
    }

    private func makeSeparator() -> UIView {
        let line = UIView()
        line.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        let container = UIView()
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])
        return container
    }

    private func makeWebsiteRow() -> UIView {
        websiteButton.translatesAutoresizingMaskIntoConstraints = false
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Config.tintColor.withAlphaComponent(0.3)
        chevron.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(websiteButton)
        container.addSubview(chevron)
        NSLayoutConstraint.activate([
            websiteButton.topAnchor.constraint(equalTo: container.topAnchor),
            websiteButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            websiteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            websiteButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            chevron.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        ])
        return container
    }
}

// MARK: - FRadioPlayerObserver

extension StationDetailViewController: FRadioPlayerObserver {
    func radioPlayer(_ player: FRadioPlayer, playerStateDidChange state: FRadioPlayer.State) {
        updatePlayButton()
        updateNowPlayingSection()
    }
    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
        updatePlayButton()
        updateNowPlayingSection()
    }
    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        updateNowPlayingSection()
    }
}

// MARK: - StationsManagerObserver

extension StationDetailViewController: StationsManagerObserver {
    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        updatePlayButton()
        updateNowPlayingSection()
    }
}

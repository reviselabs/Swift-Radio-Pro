//
//  PodcastEpisodeDetailViewController.swift
//  SwiftRadio
//

import UIKit
import FRadioPlayer

final class PodcastEpisodeDetailViewController: BaseController {
    private let podcast: Podcast
    private let episode: PodcastEpisode

    private var artworkLoadTask: Task<Void, Never>?
    private var playbackObserver: NSObjectProtocol?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let artworkImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 20, weight: .semibold)
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.textColor = .label
        return lbl
    }()

    private let metaLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = .secondaryLabel
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        return lbl
    }()

    private lazy var playButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = Config.tintColor
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.imagePlacement = .leading
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        return btn
    }()

    private let descriptionLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 15)
        lbl.textColor = .label
        lbl.numberOfLines = 0
        lbl.textAlignment = .natural
        return lbl
    }()

    // MARK: - Init

    init(podcast: Podcast, episode: PodcastEpisode) {
        self.podcast = podcast
        self.episode = episode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Content.PodcastEpisodeDetail.title
        navigationItem.backButtonDisplayMode = .minimal

        configureContent()
        loadArtwork()
        updatePlayButton()

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .podcastPlaybackDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updatePlayButton()
        }
    }

    deinit {
        artworkLoadTask?.cancel()
        if let obs = playbackObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    override func setupViews() {
        super.setupViews()

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        // Artwork
        contentStack.addArrangedSubview(artworkImageView)
        // Title + meta in a left-aligned substack
        let infoStack = UIStackView(arrangedSubviews: [titleLabel, metaLabel])
        infoStack.axis = .vertical
        infoStack.alignment = .center
        infoStack.spacing = 6
        contentStack.addArrangedSubview(infoStack)
        contentStack.addArrangedSubview(playButton)

        // Description in a full-width container
        let descContainer = UIView()
        descContainer.translatesAutoresizingMaskIntoConstraints = false
        descContainer.addSubview(descriptionLabel)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            descriptionLabel.topAnchor.constraint(equalTo: descContainer.topAnchor),
            descriptionLabel.bottomAnchor.constraint(equalTo: descContainer.bottomAnchor),
            descriptionLabel.leadingAnchor.constraint(equalTo: descContainer.leadingAnchor),
            descriptionLabel.trailingAnchor.constraint(equalTo: descContainer.trailingAnchor),
        ])
        contentStack.addArrangedSubview(descContainer)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            artworkImageView.widthAnchor.constraint(equalToConstant: 200),
            artworkImageView.heightAnchor.constraint(equalToConstant: 200),

            playButton.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            descContainer.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
        ])
    }

    // MARK: - Configuration

    private func configureContent() {
        titleLabel.text = episode.title

        var metaParts: [String] = []
        if let date = episode.pubDate {
            metaParts.append(Self.dateFormatter.string(from: date))
        } else if let raw = episode.pubDateRaw, !raw.isEmpty {
            metaParts.append(raw)
        }
        if let duration = episode.duration {
            metaParts.append(duration)
        }
        metaLabel.text = metaParts.joined(separator: " · ")
        metaLabel.isHidden = metaParts.isEmpty

        if let desc = episode.description, !desc.isEmpty {
            descriptionLabel.text = desc
        } else {
            descriptionLabel.text = Content.PodcastEpisodeDetail.noDescription
            descriptionLabel.textColor = .secondaryLabel
        }
    }

    private func loadArtwork() {
        let artworkURL = episode.artworkURL ?? PodcastsStore.shared.cachedArtworkURL(for: podcast.id)
        guard let url = artworkURL else { return }
        artworkLoadTask = Task { [weak self] in
            guard let self else { return }
            guard let image = await NetworkService.fetchImage(from: url) else { return }
            await MainActor.run { self.artworkImageView.image = image }
        }
    }

    private func updatePlayButton() {
        let service = PodcastPlaybackService.shared
        let isThisEpisodePlaying = service.isPodcastMode &&
            service.currentEpisode?.audioURL == episode.audioURL

        var config = playButton.configuration ?? .filled()
        if isThisEpisodePlaying {
            let player = FRadioPlayer.shared
            let isPaused = !player.isPlaying
            config.title = isPaused ? Content.PodcastEpisodeDetail.resumeEpisode : Content.PodcastEpisodeDetail.pauseEpisode
            config.image = UIImage(systemName: isPaused ? "play.fill" : "pause.fill")
        } else {
            config.title = Content.PodcastEpisodeDetail.playEpisode
            config.image = UIImage(systemName: "play.fill")
        }
        config.baseBackgroundColor = Config.tintColor
        config.baseForegroundColor = .white
        playButton.configuration = config

        playButton.isEnabled = episode.audioURL != nil
    }

    // MARK: - Actions

    @objc private func playButtonTapped() {
        let service = PodcastPlaybackService.shared
        let isThisEpisodePlaying = service.isPodcastMode &&
            service.currentEpisode?.audioURL == episode.audioURL

        if isThisEpisodePlaying {
            FRadioPlayer.shared.togglePlaying()
            updatePlayButton()
        } else {
            guard let audioURL = episode.audioURL else { return }
            ListenedEpisodesStore.shared.markListened(episode.id)
            service.playEpisode(
                audioURL: audioURL,
                title: episode.title,
                artist: podcast.title,
                artworkURL: episode.artworkURL ?? PodcastsStore.shared.cachedArtworkURL(for: podcast.id),
                sourceURL: episode.linkURL
            )
        }
    }
}

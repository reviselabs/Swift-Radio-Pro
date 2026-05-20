//
//  PodcastEpisodesViewController.swift
//  SwiftRadio
//

import UIKit
import SafariServices
import LNPopupController

final class PodcastEpisodesViewController: BaseController {
    private let podcast: Podcast

    private var episodes: [PodcastEpisode] = []
    private var isLoading = false
    private var loadFailed = false
    private var loadTask: Task<Void, Never>?
    private var playbackObserver: NSObjectProtocol?

    private static let episodeDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return control
    }()

    private let spinner = UIActivityIndicatorView(style: .large)

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EpisodeCell")
        let nothingFoundNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tableView.register(nothingFoundNib, forCellReuseIdentifier: "NothingFound")
        tableView.refreshControl = refreshControl
        return tableView
    }()

    init(podcast: Podcast) {
        self.podcast = podcast
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = podcast.title
        navigationController?.navigationBar.prefersLargeTitles = true

        spinner.hidesWhenStopped = true
        tableView.backgroundView = spinner

        playbackObserver = NotificationCenter.default.addObserver(
            forName: .podcastPlaybackDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.tableView.reloadData() }

        updateAddToHomeButton()
        loadEpisodes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateAddToHomeButton()
        tableView.reloadData()
    }

    deinit {
        loadTask?.cancel()
        if let obs = playbackObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    override func setupViews() {
        super.setupViews()
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }

    // MARK: - Add to Home

    private func updateAddToHomeButton() {
        let isAdded = HomeStore.shared.isAdded(podcast)
        let image = UIImage(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: image,
            style: .plain,
            target: self,
            action: #selector(addToHomeTapped)
        )
    }

    @objc private func addToHomeTapped() {
        let isAdded = HomeStore.shared.isAdded(podcast)
        if isAdded {
            let alert = UIAlertController(
                title: nil,
                message: Content.Podcasts.removeFromHomeMessage(podcast.title),
                preferredStyle: .actionSheet
            )
            alert.addAction(UIAlertAction(title: Content.Podcasts.removeFromHome, style: .destructive) { [weak self] _ in
                guard let self else { return }
                HomeStore.shared.setAdded(self.podcast, added: false)
                self.updateAddToHomeButton()
            })
            alert.addAction(UIAlertAction(title: Content.Common.ok, style: .cancel))
            if let popover = alert.popoverPresentationController {
                popover.barButtonItem = navigationItem.rightBarButtonItem
            }
            present(alert, animated: true)
        } else {
            HomeStore.shared.setAdded(podcast, added: true)
            updateAddToHomeButton()
        }
    }

    // MARK: - Load

    @objc private func refresh() {
        loadEpisodes()
    }

    private func loadEpisodes() {
        loadTask?.cancel()
        isLoading = true
        loadFailed = false
        episodes = []
        spinner.startAnimating()
        refreshControl.beginRefreshing()
        tableView.reloadData()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await PodcastRSSService.fetchEpisodes(for: podcast)
                await MainActor.run {
                    // Cache channel artwork so PodcastsViewController can display it.
                    PodcastsStore.shared.updateChannelArtwork(result.channelArtworkURL, for: self.podcast.id)
                    self.episodes = result.episodes
                    self.isLoading = false
                    self.spinner.stopAnimating()
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.loadFailed = true
                    self.isLoading = false
                    self.spinner.stopAnimating()
                    self.refreshControl.endRefreshing()
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - Episode State Helpers

    private func isCurrentlyPlaying(_ episode: PodcastEpisode) -> Bool {
        let service = PodcastPlaybackService.shared
        return service.isPodcastMode && service.currentEpisode?.audioURL == episode.audioURL
    }

    private func episodeAccessoryView(playing: Bool, listened: Bool) -> UIView? {
        let symbolName: String
        let color: UIColor
        if playing {
            symbolName = "speaker.wave.2.fill"
            color = Config.tintColor
        } else if listened {
            symbolName = "checkmark.circle.fill"
            color = .tertiaryLabel
        } else {
            return nil
        }
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        return UIImageView(image: image)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension PodcastEpisodesViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isLoading || episodes.isEmpty { return 1 }
        return episodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading || episodes.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            if let label = cell.contentView.viewWithTag(100) as? UILabel {
                if isLoading {
                    label.text = Content.Podcasts.loading
                } else if loadFailed {
                    label.text = Content.Podcasts.loadError
                } else {
                    label.text = Content.Podcasts.noEpisodes
                }
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeCell", for: indexPath)
        cell.selectionStyle = .default
        cell.backgroundColor = .clear

        let episode = episodes[indexPath.row]
        let playing = isCurrentlyPlaying(episode)
        let listened = ListenedEpisodesStore.shared.isListened(episode.id)

        let accessory = episodeAccessoryView(playing: playing, listened: listened)
        cell.accessoryView = accessory
        cell.accessoryType = accessory == nil ? .disclosureIndicator : .none

        let titleColor: UIColor = playing ? Config.tintColor : (listened ? .secondaryLabel : .label)

        var content = cell.defaultContentConfiguration()
        content.text = episode.title
        content.textProperties.color = titleColor
        if let pubDate = episode.pubDate {
            content.secondaryText = Self.episodeDateFormatter.string(from: pubDate)
        } else if let pubDateRaw = episode.pubDateRaw, !pubDateRaw.isEmpty {
            content.secondaryText = pubDateRaw
        } else {
            content.secondaryText = nil
        }

        // Episode artwork
        if let artURL = episode.artworkURL {
            content.image = nil
            content.imageProperties.maximumSize = CGSize(width: 50, height: 50)
            content.imageProperties.cornerRadius = 6
            cell.contentConfiguration = content

            // Load artwork asynchronously into the image view after configuration.
            Task { [weak cell] in
                guard let image = await NetworkService.fetchImage(from: artURL), let cell else { return }
                var updated = cell.defaultContentConfiguration()
                updated.text = episode.title
                updated.textProperties.color = titleColor
                if let pubDate = episode.pubDate {
                    updated.secondaryText = Self.episodeDateFormatter.string(from: pubDate)
                } else if let raw = episode.pubDateRaw, !raw.isEmpty {
                    updated.secondaryText = raw
                }
                updated.image = image
                updated.imageProperties.maximumSize = CGSize(width: 50, height: 50)
                updated.imageProperties.cornerRadius = 6
                cell.contentConfiguration = updated
            }
        } else {
            cell.contentConfiguration = content
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !episodes.isEmpty, indexPath.row < episodes.count else { return }

        let episode = episodes[indexPath.row]
        let detailVC = PodcastEpisodeDetailViewController(podcast: podcast, episode: episode)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

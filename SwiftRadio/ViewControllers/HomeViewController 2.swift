//
//  HomeViewController.swift
//  SwiftRadio
//

import UIKit
import FRadioPlayer
import NVActivityIndicatorView

protocol HomeViewControllerDelegate: AnyObject {
    func homeViewController(_ vc: HomeViewController, didSelectStation station: RadioStation)
    func homeViewControllerPresentAbout(_ vc: HomeViewController)
}

final class HomeViewController: BaseController {

    weak var delegate: HomeViewControllerDelegate?

    private let player = FRadioPlayer.shared
    private let manager = StationsManager.shared
    private var favoritesObserver: NSObjectProtocol?
    private var homeObserver: NSObjectProtocol?
    private var isBuffering = false

    private enum Section: Int, CaseIterable {
        case favorites = 0
        case podcasts = 1
    }

    private var favoriteStations: [RadioStation] {
        FavoriteStationsStore.shared.stationsFavoritesOnly(from: manager.stations)
    }

    private var addedPodcasts: [Podcast] {
        HomeStore.shared.addedPodcasts(from: PodcastsStore.shared.podcasts)
    }

    // MARK: - UI

    private let equalizerView: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: .zero, type: .audioEqualizer, color: Config.tintColor, padding: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let bufferingView: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: .zero, type: .ballPulse, color: Config.tintColor, padding: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var nowPlayingBarButton: UIBarButtonItem = {
        let container = UIView()
        container.addSubview(equalizerView)
        container.addSubview(bufferingView)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 30),
            container.heightAnchor.constraint(equalToConstant: 20),
            equalizerView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            equalizerView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            equalizerView.widthAnchor.constraint(equalTo: container.widthAnchor),
            equalizerView.heightAnchor.constraint(equalTo: container.heightAnchor),
            bufferingView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            bufferingView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            bufferingView.widthAnchor.constraint(equalTo: container.widthAnchor),
            bufferingView.heightAnchor.constraint(equalTo: container.heightAnchor),
        ])
        let barButton = UIBarButtonItem(customView: container)
        let tap = UITapGestureRecognizer(target: self, action: #selector(nowPlayingTapped))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        return barButton
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(StationTableViewCell.self)
        let nothingNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tv.register(nothingNib, forCellReuseIdentifier: "NothingFound")
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "PodcastCell")
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Content.Tabs.home
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal"),
            style: .plain,
            target: self,
            action: #selector(menuTapped)
        )

        player.addObserver(self)
        manager.addObserver(self)

        favoritesObserver = NotificationCenter.default.addObserver(
            forName: .favoriteStationsDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.tableView.reloadData() }

        homeObserver = NotificationCenter.default.addObserver(
            forName: .homeStoreDidChange, object: nil, queue: .main
        ) { [weak self] _ in self?.tableView.reloadData() }

        updateNowPlayingBarButton(station: manager.currentStation)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resyncBufferingState()
    }

    private func resyncBufferingState() {
        switch player.state {
        case .loading where player.playbackState != .stopped:
            isBuffering = true
        default:
            isBuffering = false
        }
        updateNowPlayingAnimation()
        updateVisibleStationCells()
    }

    deinit {
        [favoritesObserver, homeObserver].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
    }

    override func setupViews() {
        super.setupViews()
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
        ])
    }

    // MARK: - Now Playing Button

    private func updateNowPlayingBarButton(station: RadioStation?) {
        guard station != nil || PodcastPlaybackService.shared.isPodcastMode else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        updateNowPlayingAnimation()
    }

    private func updateNowPlayingAnimation() {
        if isBuffering {
            equalizerView.stopAnimating()
            bufferingView.startAnimating()
            navigationItem.rightBarButtonItem = nowPlayingBarButton
        } else if player.isPlaying {
            bufferingView.stopAnimating()
            equalizerView.startAnimating()
            navigationItem.rightBarButtonItem = nowPlayingBarButton
        } else {
            equalizerView.stopAnimating()
            bufferingView.stopAnimating()
            navigationItem.rightBarButtonItem = nil
        }
    }

    private func updateVisibleStationCells() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.updateVisibleStationCells() }
            return
        }
        for case let cell as StationTableViewCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell),
                  indexPath.section == Section.favorites.rawValue else { continue }
            let stations = favoriteStations
            guard indexPath.row < stations.count else { continue }
            let station = stations[indexPath.row]
            let isCurrent = station == manager.currentStation && !PodcastPlaybackService.shared.isPodcastMode
            cell.setNowPlaying(isPlaying: player.isPlaying, isBuffering: isBuffering, isCurrentStation: isCurrent)
        }
    }

    // MARK: - Actions

    @objc private func nowPlayingTapped() {
        // Pop popup bar open via tabBarController (coordinator owns this)
        tabBarController?.openPopup(animated: true)
    }

    @objc private func menuTapped() {
        delegate?.homeViewControllerPresentAbout(self)
    }
}

// MARK: - UITableViewDataSource

extension HomeViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .favorites:
            return max(1, favoriteStations.count)
        case .podcasts:
            return max(1, addedPodcasts.count)
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .favorites: return Content.Home.favoritesSection
        case .podcasts:  return Content.Home.podcastsSection
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .favorites: return favoriteStations.isEmpty ? UITableView.automaticDimension : 104
        case .podcasts:  return UITableView.automaticDimension
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .favorites:
            let stations = favoriteStations
            if stations.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                if let label = cell.contentView.viewWithTag(100) as? UILabel {
                    label.text = Content.Home.emptyFavorites
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(for: indexPath) as StationTableViewCell
            let station = stations[indexPath.row]
            let isFav = FavoriteStationsStore.shared.isFavorite(station)
            cell.configureStationCell(station: station, isFavorite: isFav) { [weak self] in
                FavoriteStationsStore.shared.toggleFavorite(station)
                self?.tableView.reloadRows(at: [indexPath], with: .none)
            }
            let isCurrent = station == manager.currentStation && !PodcastPlaybackService.shared.isPodcastMode
            cell.setNowPlaying(isPlaying: player.isPlaying, isBuffering: isBuffering, isCurrentStation: isCurrent)
            return cell

        case .podcasts:
            let podcasts = addedPodcasts
            if podcasts.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                if let label = cell.contentView.viewWithTag(100) as? UILabel {
                    label.text = Content.Home.emptyPodcasts
                }
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "PodcastCell", for: indexPath)
            let podcast = podcasts[indexPath.row]
            var config = cell.defaultContentConfiguration()
            config.text = podcast.title
            config.secondaryText = Content.Podcasts.openEpisodes
            if let artURL = PodcastsStore.shared.cachedArtworkURL(for: podcast.id) {
                cell.imageView?.load(url: artURL)
            }
            cell.contentConfiguration = config
            cell.accessoryType = .disclosureIndicator
            cell.backgroundColor = .clear
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension HomeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch Section(rawValue: indexPath.section)! {
        case .favorites:
            let stations = favoriteStations
            guard !stations.isEmpty, indexPath.row < stations.count else { return }
            let station = stations[indexPath.row]
            let detailVC = StationDetailViewController(station: station) { [weak self] s in
                guard let self else { return }
                self.delegate?.homeViewController(self, didSelectStation: s)
            }
            navigationController?.pushViewController(detailVC, animated: true)

        case .podcasts:
            let podcasts = addedPodcasts
            guard !podcasts.isEmpty, indexPath.row < podcasts.count else { return }
            let episodesVC = PodcastEpisodesViewController(podcast: podcasts[indexPath.row])
            navigationController?.pushViewController(episodesVC, animated: true)
        }
    }
}

// MARK: - FRadioPlayerObserver

extension HomeViewController: FRadioPlayerObserver {

    func radioPlayer(_ player: FRadioPlayer, playerStateDidChange state: FRadioPlayer.State) {
        switch state {
        case .loading where player.playbackState != .stopped:
            isBuffering = true
        default:
            isBuffering = false
        }
        updateNowPlayingAnimation()
        updateVisibleStationCells()
    }

    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
        if state == .playing, player.state == .loading {
            isBuffering = true
        }
        updateNowPlayingAnimation()
        updateVisibleStationCells()
    }

    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {}
}

// MARK: - StationsManagerObserver

extension HomeViewController: StationsManagerObserver {

    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        tableView.reloadData()
    }

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        updateVisibleStationCells()
        updateNowPlayingBarButton(station: station)
    }
}

//
//  StationsViewController.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2023-06-24.
//  Copyright © 2023 matthewfecher.com. All rights reserved.
//

import UIKit
import FRadioPlayer
import NVActivityIndicatorView

protocol StationsViewControllerDelegate: AnyObject {
    func didSelectStation(_ station: RadioStation, from stationsViewController: StationsViewController)
    func didTapNowPlaying(_ stationsViewController: StationsViewController)
    func presentAbout(_ stationsViewController: StationsViewController)
}

enum StationsListKind {
    /// Full list with favorites pinned to the top.
    case allStations
    /// Only favorited stations.
    case favoritesOnly
}

class StationsViewController: BaseController, Handoffable {

    // MARK: - Delegate
    weak var delegate: StationsViewControllerDelegate?

    private let listKind: StationsListKind

    // MARK: - Properties
    private let player = FRadioPlayer.shared
    private let manager = StationsManager.shared
    private var favoritesObserver: NSObjectProtocol?
    private var externalNowPlayingObserver: NSObjectProtocol?

    /// Stations shown when search is inactive (favorites-first on the All tab).
    private var displayStations: [RadioStation] {
        switch listKind {
        case .allStations:
            return FavoriteStationsStore.shared.stationsAllTabOrdering(manager.stations)
        case .favoritesOnly:
            return FavoriteStationsStore.shared.stationsFavoritesOnly(from: manager.stations)
        }
    }

    init(listKind: StationsListKind) {
        self.listKind = listKind
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - UI

    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        return refreshControl
    }()

    private let searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: nil)
        controller.obscuresBackgroundDuringPresentation = false
        controller.hidesNavigationBarDuringPresentation = true
        return controller
    }()

    private var isBuffering = false

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
        let barButton = UIBarButtonItem(customView: nowPlayingIndicator)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(nowPlayingBarButtonPressed))
        nowPlayingIndicator.addGestureRecognizer(tapGesture)
        nowPlayingIndicator.isUserInteractionEnabled = true
        return barButton
    }()

    private lazy var nowPlayingIndicator: UIView = {
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
        return container
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.backgroundView = nil
        tableView.separatorStyle = .none
        let cellNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tableView.register(cellNib, forCellReuseIdentifier: "NothingFound")
        tableView.register(StationTableViewCell.self)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override func loadView() {
        super.loadView()
        setupViews()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.backButtonDisplayMode = .minimal

        // NavigationBar items
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal"), style: .plain, target: self, action: #selector(handleMenuTap))

        // Setup Player
        player.addObserver(self)
        manager.addObserver(self)

        // Setup Handoff User Activity
        setupHandoffUserActivity()

        // Setup Search Bar
        setupSearchController()

        favoritesObserver = NotificationCenter.default.addObserver(
            forName: .favoriteStationsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.tableView.reloadData()
        }

        externalNowPlayingObserver = NotificationCenter.default.addObserver(
            forName: .externalNowPlayingMetadataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.updateHandoffUserActivity(self.userActivity, station: self.manager.currentStation)
        }

        // Set defaults station if the app started from CarPlay
        updateNowPlayingBarButton(station: manager.currentStation)
        updateHandoffUserActivity(userActivity, station: manager.currentStation)
    }

    deinit {
        if let favoritesObserver {
            NotificationCenter.default.removeObserver(favoritesObserver)
        }
        if let externalNowPlayingObserver {
            NotificationCenter.default.removeObserver(externalNowPlayingObserver)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch listKind {
        case .allStations:
            title = Content.Stations.title
        case .favoritesOnly:
            title = Content.Tabs.favorites
        }
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
        updateVisibleCellsNowPlaying()
    }

    @objc func refresh(sender: AnyObject) {
        // Pull to Refresh
        manager.fetch()

        // Wait 2 seconds then refresh screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.refreshControl.endRefreshing()
            self?.view.setNeedsDisplay()
        }
    }

    private func updateNowPlayingBarButton(station: RadioStation?) {
        guard station != nil else {
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

    private func updateVisibleCellsNowPlaying() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.updateVisibleCellsNowPlaying()
            }
            return
        }

        for case let cell as StationTableViewCell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell) else { continue }
            guard let station = station(at: indexPath) else { continue }
            let isCurrentStation = station == manager.currentStation && !PodcastPlaybackService.shared.isPodcastMode
            cell.setNowPlaying(isPlaying: player.isPlaying, isBuffering: isBuffering, isCurrentStation: isCurrentStation)
        }
    }

    private func station(at indexPath: IndexPath) -> RadioStation? {
        if searchController.isActive, listKind == .allStations {
            guard indexPath.row < manager.searchedStations.count else { return nil }
            return manager.searchedStations[indexPath.row]
        }
        let list = displayStations
        guard indexPath.row < list.count else { return nil }
        return list[indexPath.row]
    }

    @objc private func nowPlayingBarButtonPressed() {
        delegate?.didTapNowPlaying(self)
    }

    @objc func handleMenuTap() {
        delegate?.presentAbout(self)
    }

    private func selectStation(_ station: RadioStation) {
        delegate?.didSelectStation(station, from: self)
    }

    override func setupViews() {
        super.setupViews()

        tableView.addSubview(refreshControl)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ])
    }
}

// MARK: - TableViewDataSource

extension StationsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        104.0
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchController.isActive, listKind == .allStations {
            return manager.searchedStations.count
        }
        if manager.stations.isEmpty {
            return 1
        }
        if listKind == .favoritesOnly, displayStations.isEmpty {
            return 1
        }
        return displayStations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if manager.stations.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            if let label = cell.contentView.viewWithTag(100) as? UILabel {
                label.text = Content.Stations.loadingMessage
            }
            return cell
        }

        if listKind == .favoritesOnly, displayStations.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            if let label = cell.contentView.viewWithTag(100) as? UILabel {
                label.text = Content.Stations.emptyFavorites
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(for: indexPath) as StationTableViewCell

        guard let station = station(at: indexPath) else {
            return cell
        }
        let favorite = FavoriteStationsStore.shared.isFavorite(station)
        cell.configureStationCell(station: station, isFavorite: favorite) { [weak self] in
            FavoriteStationsStore.shared.toggleFavorite(station)
            self?.tableView.reloadRows(at: [indexPath], with: .none)
        }
        let isCurrentStation = station == manager.currentStation && !PodcastPlaybackService.shared.isPodcastMode
        cell.setNowPlaying(isPlaying: player.isPlaying, isBuffering: isBuffering, isCurrentStation: isCurrentStation)
        return cell
    }
}

// MARK: - TableViewDelegate

extension StationsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard manager.stations.isEmpty == false else { return }
        if listKind == .favoritesOnly, displayStations.isEmpty { return }
        guard let station = station(at: indexPath) else { return }

        let detailVC = StationDetailViewController(station: station) { [weak self] s in
            self?.selectStation(s)
        }
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UISearchControllerDelegate / Setup

extension StationsViewController: UISearchResultsUpdating {

    func setupSearchController() {
        guard Config.searchable, listKind == .allStations else { return }

        searchController.searchResultsUpdater = self
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.preferredSearchBarPlacement = .stacked
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let filter = searchController.searchBar.text else { return }
        let base = FavoriteStationsStore.shared.stationsAllTabOrdering(manager.stations)
        manager.searchedStations = base.filter { $0.name.range(of: filter, options: [.caseInsensitive]) != nil }
        tableView.reloadData()
    }
}

// MARK: - FRadioPlayerObserver

extension StationsViewController: FRadioPlayerObserver {

    func radioPlayer(_ player: FRadioPlayer, playerStateDidChange state: FRadioPlayer.State) {
        switch state {
        case .loading where player.playbackState != .stopped:
            isBuffering = true
        default:
            isBuffering = false
        }
        updateNowPlayingAnimation()
        updateVisibleCellsNowPlaying()
    }

    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
        if state == .playing, player.state == .loading {
            isBuffering = true
        }
        updateNowPlayingAnimation()
        updateVisibleCellsNowPlaying()
    }

    func radioPlayer(_ player: FRadioPlayer, metadataDidChange metadata: FRadioPlayer.Metadata?) {
        updateHandoffUserActivity(userActivity, station: manager.currentStation)
    }
}

extension StationsViewController: StationsManagerObserver {

    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        tableView.reloadData()
    }

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        updateVisibleCellsNowPlaying()
        updateNowPlayingBarButton(station: station)
    }
}

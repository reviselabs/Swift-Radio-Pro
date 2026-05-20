//
//  PodcastsViewController.swift
//  SwiftRadio
//

import UIKit

final class PodcastsViewController: BaseController {

    private let podcasts: [Podcast] = PodcastsStore.shared.podcasts
    private var artworkObserver: NSObjectProtocol?

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PodcastCell")
        let nothingFoundNib = UINib(nibName: "NothingFoundCell", bundle: nil)
        tableView.register(nothingFoundNib, forCellReuseIdentifier: "NothingFound")
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Content.Tabs.podcasts
        navigationController?.navigationBar.prefersLargeTitles = true

        artworkObserver = NotificationCenter.default.addObserver(
            forName: .podcastStoreArtworkDidUpdate, object: nil, queue: .main
        ) { [weak self] _ in self?.tableView.reloadData() }

        // Kick off background artwork fetch for all podcasts.
        PodcastsStore.shared.prefetchChannelArtworkIfNeeded(for: podcasts)
    }

    deinit {
        if let obs = artworkObserver {
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
}

// MARK: - UITableViewDataSource / Delegate

extension PodcastsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        podcasts.isEmpty ? 1 : podcasts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if podcasts.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NothingFound", for: indexPath)
            cell.backgroundColor = .clear
            cell.selectionStyle = .none
            if let label = cell.contentView.viewWithTag(100) as? UILabel {
                label.text = Content.Podcasts.noEpisodes
            }
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "PodcastCell", for: indexPath)
        let podcast = podcasts[indexPath.row]

        var content = cell.defaultContentConfiguration()
        content.text = podcast.title
        content.secondaryText = Content.Podcasts.openEpisodes

        if let artURL = PodcastsStore.shared.cachedArtworkURL(for: podcast.id) {
            content.imageProperties.maximumSize = CGSize(width: 50, height: 50)
            content.imageProperties.cornerRadius = 8
            cell.contentConfiguration = content
            Task { [weak cell] in
                guard let image = await NetworkService.fetchImage(from: artURL), let cell else { return }
                var updated = cell.defaultContentConfiguration()
                updated.text = podcast.title
                updated.secondaryText = Content.Podcasts.openEpisodes
                updated.image = image
                updated.imageProperties.maximumSize = CGSize(width: 50, height: 50)
                updated.imageProperties.cornerRadius = 8
                cell.contentConfiguration = updated
            }
        } else {
            cell.contentConfiguration = content
        }

        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !podcasts.isEmpty else { return }
        let podcast = podcasts[indexPath.row]
        let episodesVC = PodcastEpisodesViewController(podcast: podcast)
        navigationController?.pushViewController(episodesVC, animated: true)
    }
}

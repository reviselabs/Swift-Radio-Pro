//
//  PlaybackSettingsViewController.swift
//  SwiftRadio
//

import UIKit

final class PlaybackSettingsViewController: UITableViewController {

    private let modes = StreamQualityMode.allCases

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Content.Settings.playbackTitle
        navigationItem.largeTitleDisplayMode = .never
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        modes.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Content.Settings.streamQualityFooter
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let mode = modes[indexPath.row]
        var config = cell.defaultContentConfiguration()
        config.text = title(for: mode)
        cell.contentConfiguration = config
        cell.accessoryType = mode == PlaybackPreferences.shared.streamQualityMode ? .checkmark : .none
        cell.selectionStyle = .default
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let mode = modes[indexPath.row]
        PlaybackPreferences.shared.streamQualityMode = mode
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    private func title(for mode: StreamQualityMode) -> String {
        switch mode {
        case .auto: return Content.Settings.qualityAuto
        case .low: return Content.Settings.qualityLow
        case .medium: return Content.Settings.qualityMedium
        case .high: return Content.Settings.qualityHigh
        }
    }
}

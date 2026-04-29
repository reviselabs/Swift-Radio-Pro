//
//  StarterFMScheduleViewController.swift
//  SwiftRadio
//

import UIKit
import SafariServices

/// Full weekly grid for Starter FM (bundled JSON). Days are ordered **today first** (Sydney).
final class StarterFMScheduleViewController: UITableViewController {

    private var displayDays: [StarterFMDay] = []

    /// Avoids reassigning `tableFooterView` every layout pass (that can thrash layout and freeze the UI).
    private var lastTableFooterLayoutSize: CGSize = .zero

    init() {
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Content.StarterFMSchedule.screenTitle
        navigationItem.largeTitleDisplayMode = .always
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "slot")
        tableView.cellLayoutMarginsFollowReadableWidth = true
        reloadScheduleData()
        installTableFooter()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadScheduleData()
        tableView.reloadData()
        scrollToTodayIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sizeTableFooterToFit()
    }

    private func reloadScheduleData() {
        if let doc = StarterFMScheduleStore.shared.scheduleDocument() {
            displayDays = StarterFMScheduleEngine.daysOrderedFromToday(doc)
        } else {
            displayDays = []
        }
    }

    private func installTableFooter() {
        let footer = UIView()
        let label = UILabel()
        label.text = Content.StarterFMSchedule.timezoneFooter
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: footer.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -16),
        ])
        tableView.tableFooterView = footer
        sizeTableFooterToFit()
    }

    private func sizeTableFooterToFit() {
        guard let footer = tableView.tableFooterView else { return }
        let width = tableView.bounds.width
        guard width > 0 else { return }
        footer.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        footer.setNeedsLayout()
        footer.layoutIfNeeded()
        let height = footer.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let target = CGSize(width: width, height: height)
        let delta = abs(target.width - lastTableFooterLayoutSize.width) + abs(target.height - lastTableFooterLayoutSize.height)
        guard delta > 0.5 else { return }
        lastTableFooterLayoutSize = target
        footer.frame = CGRect(origin: .zero, size: target)
        tableView.tableFooterView = footer
    }

    private func scrollToTodayIfNeeded() {
        guard !displayDays.isEmpty else { return }
        tableView.layoutIfNeeded()
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
    }
}

extension StarterFMScheduleViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        max(displayDays.count, 1)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !displayDays.isEmpty else { return 1 }
        return displayDays[section].slots.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !displayDays.isEmpty else { return nil }
        let day = displayDays[section]
        if section == 0 {
            return "\(day.day) — \(Content.StarterFMSchedule.todaySectionSuffix)"
        }
        return day.day
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "slot", for: indexPath)
        guard !displayDays.isEmpty else {
            var config = UIListContentConfiguration.cell()
            config.text = Content.Player.starterFMScheduleUnavailable
            config.secondaryText = Content.StarterFMSchedule.timezoneFooter
            config.textProperties.color = .secondaryLabel
            config.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
            config.secondaryTextProperties.color = .tertiaryLabel
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            cell.accessoryType = .none
            return cell
        }
        let day = displayDays[indexPath.section]
        guard indexPath.row < day.slots.count else {
            return cell
        }
        let slot = day.slots[indexPath.row]
        var config = UIListContentConfiguration.subtitleCell()
        config.text = slot.title
        config.secondaryText = slot.timeRange
        config.textProperties.font = .preferredFont(forTextStyle: .body)
        config.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        config.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = config
        let url = URL(string: slot.showUrl.trimmingCharacters(in: .whitespacesAndNewlines))
        let canOpen = url.map { $0.scheme?.hasPrefix("http") == true } ?? false
        cell.accessoryType = canOpen ? .disclosureIndicator : .none
        cell.selectionStyle = canOpen ? .default : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !displayDays.isEmpty else { return }
        let slot = displayDays[indexPath.section].slots[indexPath.row]
        let trimmed = slot.showUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else { return }
        let safari = SFSafariViewController(url: url)
        safari.dismissButtonStyle = .close
        present(safari, animated: true)
    }
}

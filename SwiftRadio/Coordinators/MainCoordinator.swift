//
//  MainCoordinator.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2022-11-23.
//  Copyright © 2022 matthewfecher.com. All rights reserved.
//

import UIKit
import MessageUI
import SafariServices
import LNPopupController
import FRadioPlayer

class MainCoordinator: NavigationCoordinator {
    var childCoordinators: [Coordinator] = []

    /// Window reference so we can swap loader → tab bar root.
    private weak var window: UIWindow?

    /// Shown until stations finish loading (SceneDelegate assigns this as the initial root).
    let loaderNavigationController = UINavigationController()

    /// Tab bar hosts All Stations + Favorites; popup bar is attached here so it stays visible when switching tabs.
    let tabBarController = UITabBarController()

    private let stationsNavAll = UINavigationController()
    private let stationsNavFavorites = UINavigationController()

    /// LNPopup / pushes use the currently selected tab’s navigation stack.
    var navigationController: UINavigationController {
        (tabBarController.selectedViewController as? UINavigationController) ?? stationsNavAll
    }

    private lazy var nowPlayingViewController: NowPlayingViewController = {
        let vc = NowPlayingViewController()
        vc.delegate = self
        return vc
    }()

    private let player = FRadioPlayer.shared
    private var isPopupBarPresented = false

    /// After pushing a detail screen from the player (with popup closed), re-open the mini/full player when the user pops back to the stations root.
    private var reopenPlayerAfterPoppingToStationsRoot = false
    /// Avoids reopening the player when another tab’s nav stack shows its root `StationsViewController`.
    private weak var navigationControllerAwaitingPlayerReopen: UINavigationController?

    private let popupReopenNavigationDelegate = PopupReopenNavigationDelegate()

    init(window: UIWindow) {
        self.window = window
        popupReopenNavigationDelegate.coordinator = self
    }

    func start() {
        StarterFMScheduleStore.shared.ensurePollingStarted()
        let loaderVC = LoaderController()
        loaderVC.delegate = self
        loaderNavigationController.setViewControllers([loaderVC], animated: false)
        window?.rootViewController = loaderNavigationController
    }

    // MARK: - Popup Bar

    func presentPopupBarIfNeeded() {
        guard !isPopupBarPresented else { return }
        tabBarController.popupBar.barStyle = .prominent
        tabBarController.popupBar.tintColor = Config.tintColor
        tabBarController.popupBar.progressViewStyle = .bottom
        tabBarController.popupContentView.popupCloseButtonStyle = .chevron
        tabBarController.presentPopupBar(with: nowPlayingViewController, animated: true)
        isPopupBarPresented = true
    }

    // MARK: - Shared

    func openEmail(to email: String, from coordinator: AboutCoordinator) {
        guard let aboutVC = coordinator.navigationController.viewControllers.first as? AboutViewController else { return }
        guard MFMailComposeViewController.canSendMail() else {
            aboutVC.showSendMailErrorAlert()
            return
        }

        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = coordinator
        mailComposer.setToRecipients([email])
        mailComposer.setSubject(Config.emailSubject)
        mailComposer.setMessageBody("", isHTML: false)
        aboutVC.present(mailComposer, animated: true)
    }

    func openAbout() {
        let modalNav = UINavigationController()
        let aboutCoordinator = AboutCoordinator(navigationController: modalNav)
        aboutCoordinator.parentCoordinator = self
        aboutCoordinator.start()
        childCoordinators.append(aboutCoordinator)
        tabBarController.present(modalNav, animated: true)
    }

    func share(_ text: String, from viewController: UIViewController) {
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        viewController.present(activityViewController, animated: true)
    }
}

// MARK: - LoaderControllerDelegate

extension MainCoordinator: LoaderControllerDelegate {
    func didFinishLoading(_ controller: LoaderController, stations: [RadioStation]) {
        let allVC = StationsViewController(listKind: .allStations)
        let favVC = StationsViewController(listKind: .favoritesOnly)
        allVC.delegate = self
        favVC.delegate = self

        stationsNavAll.setViewControllers([allVC], animated: false)
        stationsNavFavorites.setViewControllers([favVC], animated: false)
        stationsNavAll.delegate = popupReopenNavigationDelegate
        stationsNavFavorites.delegate = popupReopenNavigationDelegate

        stationsNavAll.tabBarItem = UITabBarItem(
            title: Content.Tabs.allStations,
            image: UIImage(systemName: "radio"),
            selectedImage: nil
        )
        stationsNavFavorites.tabBarItem = UITabBarItem(
            title: Content.Tabs.favorites,
            image: UIImage(systemName: "star.fill"),
            selectedImage: nil
        )

        tabBarController.viewControllers = [stationsNavAll, stationsNavFavorites]
        tabBarController.tabBar.tintColor = Config.tintColor

        window?.rootViewController = tabBarController
    }
}

// MARK: - StationsViewControllerDelegate

extension MainCoordinator: StationsViewControllerDelegate {

    func didSelectStation(_ station: RadioStation, from stationsViewController: StationsViewController) {
        let isNewStation = station != StationsManager.shared.currentStation
        if isNewStation {
            StationsManager.shared.set(station: station)
            presentPopupBarIfNeeded()
        } else if player.isPlaying {
            tabBarController.openPopup(animated: true)
        } else {
            player.togglePlaying()
        }
    }

    func didTapNowPlaying(_ stationsViewController: StationsViewController) {
        tabBarController.openPopup(animated: true)
    }

    func presentAbout(_ stationsViewController: StationsViewController) {
        openAbout()
    }
}

// MARK: - NowPlayingViewControllerDelegate

extension MainCoordinator: NowPlayingViewControllerDelegate {

    func didSelectBottomSheetOption(_ option: BottomSheetViewController.Option, from controller: NowPlayingViewController) {
        guard let station = StationsManager.shared.currentStation else { return }

        switch option {
        case .info:
            let nav = navigationController
            reopenPlayerAfterPoppingToStationsRoot = true
            navigationControllerAwaitingPlayerReopen = nav
            let infoController = InfoDetailViewController(station: station)
            tabBarController.closePopup(animated: true) { [weak self] in
                self?.navigationController.pushViewController(infoController, animated: true)
            }
        case .website:
            if let website = station.website, let url = URL(string: website) {
                let safariVC = SFSafariViewController(url: url)
                tabBarController.closePopup(animated: true, completion: { [weak self] in
                    self?.navigationController.present(safariVC, animated: true)
                })
            }

        case .starterFMSchedule:
            pushStarterFMScheduleFromPlayer()

        default:
            BottomSheetHandler.handle(option, station: station, from: controller)
        }
    }

    func didTapCompanyButton(_ nowPlayingViewController: NowPlayingViewController) {
        openAbout()
    }

    func nowPlayingViewControllerDidRequestStarterFMSchedule(_ controller: NowPlayingViewController) {
        pushStarterFMScheduleFromPlayer()
    }

    private func pushStarterFMScheduleFromPlayer() {
        guard StationsManager.shared.currentStation?.showsStarterFMShowSchedule == true else { return }
        let nav = navigationController
        reopenPlayerAfterPoppingToStationsRoot = true
        navigationControllerAwaitingPlayerReopen = nav
        tabBarController.closePopup(animated: true) { [weak self] in
            guard let self else { return }
            let scheduleVC = StarterFMScheduleViewController()
            // Defer push to the next run loop so LNPopup teardown/layout is finished (avoids main-thread stalls).
            DispatchQueue.main.async {
                self.navigationController.pushViewController(scheduleVC, animated: true)
            }
        }
    }
}

// MARK: - Navigation (re-open player after subpages)

extension MainCoordinator {
    fileprivate func handleNavigationDidShowRootStations(_ viewController: UIViewController, in navigationController: UINavigationController) {
        guard reopenPlayerAfterPoppingToStationsRoot else { return }
        guard navigationController === navigationControllerAwaitingPlayerReopen,
              navigationController.viewControllers.count == 1,
              viewController is StationsViewController,
              StationsManager.shared.currentStation != nil else { return }
        reopenPlayerAfterPoppingToStationsRoot = false
        navigationControllerAwaitingPlayerReopen = nil
        tabBarController.openPopup(animated: true)
    }
}

private final class PopupReopenNavigationDelegate: NSObject, UINavigationControllerDelegate {
    weak var coordinator: MainCoordinator?

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        coordinator?.handleNavigationDidShowRootStations(viewController, in: navigationController)
    }
}

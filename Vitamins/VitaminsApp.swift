//
//  VitaminsApp.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import SwiftUI
import ComposableArchitecture
import UIKit
import CoreText
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ReminderNotificationScheduler.shared.registerCategories()
        AnalyticsService.shared.start()
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        AnalyticsService.shared.handleApplicationWillEnterForeground()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        var backgroundTaskID = UIBackgroundTaskIdentifier.invalid
        backgroundTaskID = application.beginBackgroundTask(withName: "FlushAnalytics") {
            application.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        Task {
            await AnalyticsService.shared.handleApplicationDidEnterBackground()

            if backgroundTaskID != .invalid {
                application.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Task {
            await AnalyticsService.shared.handleApplicationWillTerminate()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task {
            await ReminderNotificationResponseHandler.shared.handle(response: response)
            completionHandler()
        }
    }
}

@main
struct VitaminsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            let welcomeStorage = WelcomeStorage()
            let initialState: RootFeature.State = {
                if TokenStorage.isAuthenticated {
                    return .home
                }
                if welcomeStorage.shouldShowWelcome {
                    return .welcome
                }
                return .auth(.signUp)
            }()
            
            RootView(
                store: Store(
                    initialState: initialState
                ) {
                    RootFeature()
                }
            )
        }
    }
}

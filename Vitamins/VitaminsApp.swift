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

@main
struct VitaminsApp: App {

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

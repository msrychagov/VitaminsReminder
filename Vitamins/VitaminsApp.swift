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
            RootView(
                store: Store(
                    initialState: TokenStorage.isAuthenticated ? .home : .auth(.signUp)
                ) {
                    RootFeature()
                }
            )
        }
    }
}

//
//  VitaminsApp.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import SwiftUI
import ComposableArchitecture

@main
struct VitaminsApp: App {
    var body: some Scene {
        WindowGroup {
            let store = Store(initialState: .signIn) {
                AuthFeature()
            }
            
            AuthView(viewStore: store)
        }
    }
}

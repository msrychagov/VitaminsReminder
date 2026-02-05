//
//  NetworkClient+Dependency.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation
import ComposableArchitecture

extension NetworkClient: DependencyKey {
    static let liveValue = NetworkClient()
}

extension DependencyValues {
    var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}







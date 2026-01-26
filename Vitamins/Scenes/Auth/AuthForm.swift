//
//  AuthForm.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import ComposableArchitecture


import ComposableArchitecture

struct AuthForm: Reducer {
    
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
    }

    enum Action: Equatable {
        case didEmailChange(String)
        case didPasswordChange(String)
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
            switch action {
            case let .didEmailChange(email):
                state.email = email
                return .none

            case let .didPasswordChange(password):
                state.password = password
                return .none
            }
        }
}


//
//  Reducer.swift.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import ComposableArchitecture

struct AuthFeature: Reducer {
    
    struct State: Equatable {
        let mode: Mode
        let ui: AuthScreenConfig
        var form: AuthForm.State
        var viewState: ViewState
        
        init(mode: Mode) {
            self.mode = mode
            self.ui = AuthScreenConfig.make(for: mode)
            self.form = AuthForm.State()
            self.viewState = .data
        }
    }
    
    enum Action: Equatable {
        case form(AuthForm.Action)
        case primaryButtonTapped
        case secondaryButtonTapped
    }
    
    enum Mode {
        case signIn
        case signUp
        case passwordReset
    }
    
    enum ViewState: Equatable {
        case data
        case error(wrongEmail: Bool, wrongPassword: Bool)
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
            
        case let .form(formAction):
            _ = AuthForm().reduce(into: &state.form, action: formAction)
            return .none
            
        case .primaryButtonTapped:
            return .none
            
        case .secondaryButtonTapped:
            return .none
        }
    }
}

extension AuthFeature.State {
    static var signIn: Self { .init(mode: .signIn) }
    static var signUp: Self { .init(mode: .signUp) }
}


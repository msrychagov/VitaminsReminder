//
//  RootFeature.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import ComposableArchitecture
import SwiftUI

struct RootFeature: Reducer {
    
    enum State: Equatable {
        case auth(AuthFeature.State)
        case home
    }
    
    enum Action: Equatable {
        case auth(AuthFeature.Action)
        case checkAuthStatus
        case logoutTapped
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .checkAuthStatus:
            if TokenStorage.isAuthenticated {
                state = .home
            } else {
                // Сохраняем текущий режим авторизации, если он уже установлен
                if case .auth(let authState) = state {
                    // Оставляем текущий режим (signIn, signUp, passwordReset)
                    return .none
                } else {
                    // Если нет состояния авторизации, показываем регистрацию по умолчанию
                    state = .auth(.signUp)
                }
            }
            return .none
            
        case .auth(let authAction):
            guard case .auth(var authState) = state else {
                return .none
            }
            
            // Обрабатываем действие в дочернем reducer
            let effect = AuthFeature().reduce(into: &authState, action: authAction)
            
            // Обработка навигации и переходов
            switch authAction {
            case .proceedToHome:
                state = .home
            default:
                state = .auth(authState)
            }
            return effect.map(Action.auth)
            
        case .logoutTapped:
            TokenStorage.clear()
            UserProfileStorage().clear()
            state = .auth(.signUp)
            return .none
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            Group {
                switch viewStore.state {
                case .auth:
                    IfLetStore(
                        store.scope(
                            state: {
                                if case .auth(let authState) = $0 {
                                    return authState
                                }
                                return nil
                            },
                            action: { .auth($0) }
                        )
                ) { authStore in
                    AuthView(viewStore: authStore)
                }
            case .home:
                HomeView(onLogout: {
                    viewStore.send(.logoutTapped)
                })
            }
        }
        .task {
            // Проверяем статус авторизации только если пользователь авторизован
            // Не перезаписываем начальное состояние auth
                if TokenStorage.isAuthenticated {
                    store.send(.checkAuthStatus)
                }
            }
        }
    }
}

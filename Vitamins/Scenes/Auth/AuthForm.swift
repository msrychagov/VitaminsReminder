//
//  AuthForm.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import ComposableArchitecture
import Foundation

struct AuthForm: Reducer {
    
    struct State: Equatable {
        var email: String = ""
        var password: String = ""
        var repeatPassword: String = ""
        var codeDigits: [String] = Array(repeating: "", count: 6)
        var codeError: String?
        var codeValidation: CodeValidation = .idle
        
        // Ошибки валидации полей
        var emailError: String?
        var passwordError: String?
        var repeatPasswordError: String?
    }

    enum CodeValidation: Equatable {
        case idle
        case success
        case error
    }

    enum Action: Equatable {
        case didEmailChange(String)
        case didPasswordChange(String)
        case didRepeatPasswordChange(String)
        case validate(mode: AuthFeature.Mode)
        case clearErrors
    }

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .didEmailChange(email):
            state.email = email
            // Очищаем ошибку при вводе
            state.emailError = nil
            return .none

        case let .didPasswordChange(password):
            state.password = password
            // Очищаем ошибку при вводе
            state.passwordError = nil
            // Очищаем ошибку повторного пароля, если пароли совпадают
            if state.repeatPassword == password {
                state.repeatPasswordError = nil
            }
            return .none
            
        case let .didRepeatPasswordChange(repeatPassword):
            state.repeatPassword = repeatPassword
            // Очищаем ошибку при вводе
            state.repeatPasswordError = nil
            return .none
            
        case let .validate(mode):
            // Валидация email (для входа, регистрации и запроса восстановления)
            if mode == .signIn || mode == .signUp || mode == .passwordResetRequest {
                state.emailError = state.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Введите e-mail"
                    : nil
            }
            
            // Валидация пароля
            if mode == .signIn || mode == .signUp || mode == .passwordReset {
                state.passwordError = state.password.isEmpty
                    ? "Введите пароль"
                    : nil
            }
            
            // Валидация повторного пароля (для регистрации и восстановления)
            if mode == .signUp || mode == .passwordReset {
                if state.repeatPassword.isEmpty {
                    state.repeatPasswordError = "Повторите пароль"
                } else if state.password != state.repeatPassword {
                    state.repeatPasswordError = "Пароли не совпадают"
                } else {
                    state.repeatPasswordError = nil
                }
            }
            
            return .none
            
        case .clearErrors:
            state.emailError = nil
            state.passwordError = nil
            state.repeatPasswordError = nil
            return .none
        }
    }
}

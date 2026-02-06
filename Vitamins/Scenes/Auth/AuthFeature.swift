//
//  Reducer.swift.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import ComposableArchitecture
import Foundation

struct AuthFeature: Reducer {
    
    // NetworkClient через dependency
    @Dependency(\.networkClient) var networkClient
    
    struct State: Equatable {
        var rootMode: Mode
        var navigationPath: [Mode] = []
        var forms: [Mode: AuthForm.State]
        var isLoading: Bool = false
        var resetEmail: String = ""
        var codeResendSeconds: Int = 60
        
        init(mode: Mode) {
            self.rootMode = mode
            self.forms = [mode: AuthForm.State()]
        }
        
        var currentMode: Mode { navigationPath.last ?? rootMode }
    }
    
    enum Action: Equatable {
        case form(AuthForm.Action)
        case primaryButtonTapped
        case secondaryButtonTapped
        case backButtonTapped
        case navigationPathUpdated([Mode])
        case authResponse(TaskResult<AuthResponse?>)
        case passwordResetRequestResponse(TaskResult<EmptyResponse?>)
        case verifyCodeResponse(TaskResult<EmptyResponse?>)
        case startCodeTimer
        case codeTimerTicked
        case resendCodeTapped
    }
    
    enum Mode: Hashable {
        case signIn
        case signUp
        case passwordResetRequest
        case passwordResetCode
        case passwordReset
    }
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
            
        case let .form(formAction):
            var form = state.forms[state.currentMode] ?? AuthForm.State()
            let effect = AuthForm().reduce(into: &form, action: formAction)
            state.forms[state.currentMode] = form
            
            if state.currentMode == .passwordResetCode {
                switch formAction {
                case .didChangeCodeDigit:
                    let codeFilled = form.codeDigits.allSatisfy { $0.count == 1 }
                    guard codeFilled, !state.resetEmail.isEmpty else {
                        return effect.map(Action.form)
                    }
                    
                    state.isLoading = true
                    let request = PasswordResetVerifyRequest(
                        email: state.resetEmail,
                        code: form.codeDigits.joined()
                    )
                    
                    return .merge(
                        effect.map(Action.form),
                        .run { send in
                            await send(
                                .verifyCodeResponse(
                                    TaskResult {
                                        try await networkClient.request(
                                            body: request,
                                            endpoint: AuthEndpoint.passwordResetVerify
                                        )
                                    }
                                )
                            )
                        }
                        .cancellable(id: CancelID.verifyCode, cancelInFlight: true)
                    )
                    
                default:
                    break
                }
            }
            
            return effect.map(Action.form)
            
        case .primaryButtonTapped:
            // Валидация формы
            var form = state.forms[state.currentMode] ?? AuthForm.State()
            let validationEffect = AuthForm().reduce(into: &form, action: .validate(mode: state.currentMode))
                .map(Action.form)
            state.forms[state.currentMode] = form
            
            // Проверяем, есть ли ошибки валидации
            let hasErrors = form.emailError != nil || 
                          form.passwordError != nil || 
                          form.repeatPasswordError != nil
            
            guard !hasErrors else {
                return validationEffect
            }
            
            switch state.currentMode {
            case .signIn, .signUp:
                // Если валидация прошла, делаем запрос
                state.isLoading = true
                let request = AuthRequest(
                    email: form.email,
                    password: form.password
                )
                let endpoint: AuthEndpoint = state.currentMode == .signIn ? .login : .register
                
                return .run { send in
                    await send(.authResponse(
                        TaskResult {
                            try await networkClient.request(
                                body: request,
                                endpoint: endpoint
                            )
                        }
                    ))
                }
            
            case .passwordResetRequest:
                state.isLoading = true
                let email = form.email.trimmingCharacters(in: .whitespacesAndNewlines)
                state.resetEmail = email
                let request = PasswordResetEmailRequest(email: email)
                
                return .run { send in
                    await send(
                        .passwordResetRequestResponse(
                            TaskResult {
                                try await networkClient.request(
                                    body: request,
                                    endpoint: AuthEndpoint.passwordResetRequest
                                )
                            }
                        )
                    )
                }
                .cancellable(id: CancelID.resendCode, cancelInFlight: true)
                
            case .passwordResetCode:
                // Ввод кода обрабатывается по мере ввода цифр
                return .none
                
            case .passwordReset:
                // TODO: отправить новый пароль, когда бекенд будет готов
                return .none
            }

        case let .navigationPathUpdated(path):
            let oldPath = state.navigationPath
            state.navigationPath = path
            
            let isPop = path.count < oldPath.count
            if isPop {
                // Возвращаемся к предыдущему экрану, поля остаются сохраненными
                state.isLoading = false
            }
            return .none
            
        case let .authResponse(.success(response)):
            state.isLoading = false
            
            // Сохраняем токены при успешной авторизации/регистрации
            if let response = response {
                TokenStorage.save(
                    accessToken: response.accessToken,
                    refreshToken: response.refreshToken
                )
                print("Tokens saved successfully")
            }
            
            let currentForm = form(for: state.currentMode, in: state)
            let emailToStore = response?.user?.email ?? currentForm.email
            if !emailToStore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserProfileStorage().upsert(email: emailToStore)
            }
            
            // Переход на главный экран происходит через RootFeature
            return .none
            
        case let .authResponse(.failure(error)):
            state.isLoading = false
            // Обработка ошибок API
            handleAPIError(error, in: &state)
            return .none

        case .passwordResetRequestResponse(.success):
            state.isLoading = false
            let email = form(for: .passwordResetRequest, in: state).email.trimmingCharacters(in: .whitespacesAndNewlines)
            state.resetEmail = email
            if state.currentMode != .passwordResetCode {
                push(&state, to: .passwordResetCode)
            }
            state.codeResendSeconds = 60
            return startCodeTimerEffect()

        case let .passwordResetRequestResponse(.failure(error)):
            state.isLoading = false
            handleAPIError(error, in: &state)
            return .none
            
        case .verifyCodeResponse(.success):
            state.isLoading = false
            updateForm(&state, for: .passwordResetCode) { form in
                form.codeValidation = .success
                form.codeError = nil
            }
            push(&state, to: .passwordReset)
            return .none
            
        case let .verifyCodeResponse(.failure(error)):
            state.isLoading = false
            print("Verify code error: \(error)")
            updateForm(&state, for: .passwordResetCode) { form in
                form.codeValidation = .error
                form.codeError = "Неверный код"
                form.codeDigits = Array(repeating: "", count: 6)
            }
            return .none
            
        case .startCodeTimer:
            state.codeResendSeconds = 60
            return startCodeTimerEffect()
            
        case .codeTimerTicked:
            if state.codeResendSeconds > 0 {
                state.codeResendSeconds -= 1
            }
            return .none
            
        case .resendCodeTapped:
            guard !state.resetEmail.isEmpty else { return .none }
            state.isLoading = true
            let request = PasswordResetEmailRequest(email: state.resetEmail)
            
            return .run { send in
                await send(
                    .passwordResetRequestResponse(
                        TaskResult {
                            try await networkClient.request(
                                body: request,
                                endpoint: AuthEndpoint.passwordResetRequest
                            )
                        }
                    )
                )
            }
            .cancellable(id: CancelID.resendCode, cancelInFlight: true)
            
        case .secondaryButtonTapped:
            // Переключение между режимами без NavigationStack
            switch state.currentMode {
            case .signIn:
                push(&state, to: .passwordResetRequest)
                return .none
            case .signUp:
                push(&state, to: .signIn)
                return .none
            case .passwordResetRequest:
                return .none
            case .passwordResetCode:
                return .none
            case .passwordReset:
                return .none
            }
            
        case .backButtonTapped:
            // Возврат на предыдущий экран авторизации
            pop(&state)
            return .none
        }
    }
    
    // Обработка ошибок API и маппинг в ошибки полей
    private func handleAPIError(_ error: Error, in state: inout State) {
        let authError = AuthError.from(error)
        let mode = state.currentMode
        
        switch authError {
        case .conflict:
            // Пользователь уже зарегистрирован
            if mode == .signUp {
                updateForm(&state, for: mode) { form in
                    form.emailError = "Пользователь с таким e-mail уже зарегистрирован"
                }
            }
        case .unauthorized:
            // Неверный email или пароль
            if mode == .signIn {
                updateForm(&state, for: mode) { form in
                    form.emailError = "Неверный e-mail или пароль"
                    form.passwordError = "Неверный e-mail или пароль"
                }
            }
        case .badRequest, .unprocessableEntity:
            updateForm(&state, for: mode) { form in
                form.emailError = "Проверьте правильность введенных данных"
            }
        case .networkError:
            updateForm(&state, for: mode) { form in
                form.emailError = "Ошибка соединения. Проверьте интернет"
            }
        case .serverError:
            updateForm(&state, for: mode) { form in
                form.emailError = "Ошибка сервера. Попробуйте позже"
            }
        case .unknown:
            updateForm(&state, for: mode) { form in
                form.emailError = "Произошла ошибка. Попробуйте позже"
            }
        }
    }
    
    private func push(_ state: inout State, to mode: Mode) {
        state.navigationPath.append(mode)
        ensureForm(&state, for: mode)
    }
    
    private func pop(_ state: inout State) {
        guard !state.navigationPath.isEmpty else {
            return
        }
        state.navigationPath.removeLast()
        state.isLoading = false
    }
    
    private func ensureForm(_ state: inout State, for mode: Mode) {
        if state.forms[mode] == nil {
            state.forms[mode] = AuthForm.State()
        }
    }
    
    private func updateForm(_ state: inout State, for mode: Mode, _ update: (inout AuthForm.State) -> Void) {
        ensureForm(&state, for: mode)
        var form = state.forms[mode] ?? AuthForm.State()
        update(&form)
        state.forms[mode] = form
    }
    
    private func form(for mode: Mode, in state: State) -> AuthForm.State {
        state.forms[mode] ?? AuthForm.State()
    }
    
    private func startCodeTimerEffect() -> Effect<Action> {
        .run { send in
            for _ in 0..<60 {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                await send(.codeTimerTicked)
            }
        }
        .cancellable(id: CancelID.codeTimer, cancelInFlight: true)
    }
}

extension AuthFeature.State {
    static var signIn: Self { .init(mode: .signIn) }
    static var signUp: Self { .init(mode: .signUp) }
}

private enum CancelID {
    static let codeTimer = "codeTimer"
    static let verifyCode = "verifyCode"
    static let resendCode = "resendCode"
}

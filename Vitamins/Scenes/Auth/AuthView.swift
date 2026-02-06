//
//  Untitled.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import SwiftUI
import ComposableArchitecture

struct AuthView: View {
    
    let viewStore: StoreOf<AuthFeature>
    @FocusState private var focusedCodeIndex: Int?
    
    var body: some View {
        WithViewStore(self.viewStore, observe: { $0 }) { viewStore in
            NavigationStack(
                path: viewStore.binding(
                    get: \.navigationPath,
                    send: AuthFeature.Action.navigationPathUpdated
                )
            ) {
                authContent(viewStore, mode: viewStore.rootMode)
                    .navigationDestination(for: AuthFeature.Mode.self) { mode in
                        authContent(viewStore, mode: mode)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func authContent(_ viewStore: ViewStoreOf<AuthFeature>, mode: AuthFeature.Mode) -> some View {
        let ui = AuthScreenConfig.make(for: mode)
        let form = viewStore.forms[mode] ?? AuthForm.State()
        let showBack = mode != viewStore.rootMode
        let contentPadding: CGFloat = mode == .passwordResetRequest ? 16 : 27
        
        if mode == .passwordResetCode {
            codeInputView(viewStore: viewStore)
                .padding(.horizontal, contentPadding)
                .padding(.top, 100)
                .onAppear {
                    focusedCodeIndex = 0
                    viewStore.send(.startCodeTimer)
                }
                .customBackButton(
                    show: showBack,
                    action: { viewStore.send(.backButtonTapped) }
                )
        } else {
            VStack(alignment: .center, spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    titleLabel(ui)
                    
                    if let subtitle = ui.subtitle {
                        subtitleLabel(subtitle, mode: mode)
                    }
                    
                    if mode != .passwordReset {
                        emailTextField(viewStore, mode: mode, form: form)
                            .padding(.top, 24)
                    }
                    
                    if mode != .passwordResetRequest {
                        passwordTextField(viewStore, mode: mode, form: form)
                            .padding(.top, mode == .passwordReset ? 24 : 9)
                    }
                    
                    if mode == .signUp || mode == .passwordReset {
                        repeatPasswordTextField(viewStore, mode: mode, form: form)
                            .padding(.top, 9)
                    }
                    
                    if mode == .signIn {
                        HStack {
                            Spacer()
                            secondaryButton(viewStore, ui: ui, mode: mode)
                        }
                        .padding(.top, 8)
                    }
                    
                    primaryButton(viewStore, ui: ui)
                        .padding(.top, 22)
                    
                    if mode == .passwordResetRequest {
                        infoLabel("Письмо с кодом приходит в течение нескольких минут")
                            .padding(.top, 16)
                    }
                    
                    if mode == .signUp {
                        secondaryButton(viewStore, ui: ui, mode: mode)
                            .padding(.top, 20)
                    }
                }
                .padding(.top, 100)
                .padding(.horizontal, contentPadding)
                
                Spacer()
            }
            .customBackButton(
                show: showBack,
                action: { viewStore.send(.backButtonTapped) }
            )
        }
    }
    
    private func titleLabel(_ ui: AuthScreenConfig) -> some View {
        Text(ui.title)
            .font(.custom("Commissioner-ExtraBold", size: 32))
            .foregroundStyle(Color.authTitle)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func subtitleLabel(_ subtitle: String, mode: AuthFeature.Mode) -> some View {
        Text(subtitle)
            .font(.custom("Commissioner-Regular", size: 15))
            .foregroundStyle(Color.authSubtitle)
            .padding(.top, 8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: mode == .passwordResetRequest ? 320 : .infinity)
            .fixedSize(horizontal: false, vertical: mode == .passwordResetRequest)
    }
    

    private func infoLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("Commissioner-Regular", size: 15).italic())
            .foregroundStyle(Color.authInfo)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 48)
    }
    
    private func emailTextField(_ viewStore: ViewStoreOf<AuthFeature>, mode: AuthFeature.Mode, form: AuthForm.State) -> some View {
        TextField(
            "E-mail",
            text: viewStore.binding(
                get: { state in state.forms[mode]?.email ?? "" },
                send: { .form(.didEmailChange($0)) }
            )
        )
        .autocapitalization(.none)
        .keyboardType(.emailAddress)
        .inputFieldStyle(
            isError: form.emailError != nil,
            errorMessage: form.emailError ?? ""
        )
    }
    
    private func passwordTextField(_ viewStore: ViewStoreOf<AuthFeature>, mode: AuthFeature.Mode, form: AuthForm.State) -> some View {
        SecureField(
            mode == .passwordReset ? "Новый пароль" : "Пароль",
            text: viewStore.binding(
                get: { state in state.forms[mode]?.password ?? "" },
                send: { .form(.didPasswordChange($0)) }
            )
        )
        .inputFieldStyle(
            isError: form.passwordError != nil,
            errorMessage: form.passwordError ?? ""
        )
    }
    
    private func repeatPasswordTextField(_ viewStore: ViewStoreOf<AuthFeature>, mode: AuthFeature.Mode, form: AuthForm.State) -> some View {
        SecureField(
            "Повторите пароль",
            text: viewStore.binding(
                get: { state in state.forms[mode]?.repeatPassword ?? "" },
                send: { .form(.didRepeatPasswordChange($0)) }
            )
        )
        .inputFieldStyle(
            isError: form.repeatPasswordError != nil,
            errorMessage: form.repeatPasswordError ?? ""
        )
    }
    
    private func primaryButton(_ viewStore: ViewStoreOf<AuthFeature>, ui: AuthScreenConfig) -> some View {
        Button{
            viewStore.send(.primaryButtonTapped)
        } label: {
            Text(ui.primaryButtonTitle)
                .foregroundColor(.white)
                .font(.custom("Commissioner-SemiBold", size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color.authPrimaryButton
                )
                .clipShape(Capsule())
                .shadow(
                    color: Color.authPrimaryButton.opacity(0.3),
                    radius: 12, y: 4
                )
        }
        .padding(.top, 22)
        .disabled(viewStore.isLoading)
        .opacity(viewStore.isLoading ? 0.6 : 1.0)
    }
    
    private func secondaryButton(_ viewStore: ViewStoreOf<AuthFeature>, ui: AuthScreenConfig, mode: AuthFeature.Mode) -> some View {
        HStack(spacing: 4) {
            Text(ui.secondaryPrefix ?? "")
                .foregroundColor(.black)
                .underline()

            Button {
                viewStore.send(.secondaryButtonTapped)
            } label: {
                Text(ui.secondaryAction ?? "")
                    .foregroundColor(Color.authSecondaryButton)
                .underline()
            }
        }
        .font(.custom("Commissioner-Regular", size: 14))
        .padding(.top, mode == .signIn ? 2 : 16)
    }
    
    @ViewBuilder
    private func codeInputView(viewStore: ViewStoreOf<AuthFeature>) -> some View {
        let codeState = viewStore.forms[.passwordResetCode] ?? AuthForm.State()
        let codeValidation = codeState.codeValidation
        let codeErrorText = codeState.codeError ?? (codeValidation == .error ? "Неверный код" : nil)
        let isCodeError = codeValidation == .error
        let emailText = viewStore.resetEmail.isEmpty ? "указанную почту" : viewStore.resetEmail
        
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Введите код из e-mail")
                    .font(.custom("Commissioner-ExtraBold", size: 32))
                    .foregroundStyle(Color.authTitle)
                    .multilineTextAlignment(.center)
                
                Text("Отправили его на \(emailText)")
                    .font(.custom("Commissioner-Regular", size: 15))
                    .foregroundStyle(Color.authSubtitle)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    codeDigitField(
                        index: index,
                        codeValidation: codeValidation,
                        viewStore: viewStore
                    )
                }
            }
            .padding(.top, 6)
            
            if isCodeError, let error = codeErrorText {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.custom("Commissioner-Regular", size: 9).italic())
                        .foregroundColor(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
            
            Text("Получить код ещё раз через \(viewStore.codeResendSeconds) сек.")
                .font(.custom("Commissioner-Regular", size: 15))
                .foregroundStyle(Color.authSubtitle)
                .padding(.top, 4)
                .opacity(viewStore.codeResendSeconds > 0 ? 1 : 0)
            
            if viewStore.codeResendSeconds == 0 {
                Button {
                    viewStore.send(.resendCodeTapped)
                } label: {
                    Text("Получить код ещё раз")
                        .font(.custom("Commissioner-Regular", size: 15))
                        .foregroundStyle(Color(hex: "0773F1"))
                }
                .padding(.top, -6)
                .disabled(viewStore.isLoading)
                .opacity(viewStore.isLoading ? 0.6 : 1.0)
            }
            
            Spacer()
        }
        .onChange(of: viewStore.forms[.passwordResetCode]?.codeValidation ?? .idle) { validation in
            if validation == .error {
                focusedCodeIndex = 0
            }
        }
    }
    
    private func codeDigitField(
        index: Int,
        codeValidation: AuthForm.CodeValidation,
        viewStore: ViewStoreOf<AuthFeature>
    ) -> some View {
        let isError = codeValidation == .error
        let isSuccess = codeValidation == .success
        let textBinding = viewStore.binding(
            get: { state in
                guard let digits = state.forms[.passwordResetCode]?.codeDigits,
                      digits.indices.contains(index)
                else { return "" }
                return digits[index]
            },
            send: { .form(.didChangeCodeDigit(index: index, value: $0)) }
        )
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        
        let borderColor: Color = {
            if isError {
                if focusedCodeIndex == index {
                    return Color.authCodeBorderFocus
                }
                return .red
            }
            if focusedCodeIndex == index {
                return Color.authCodeBorderFocus
            }
            if isSuccess {
                return Color.authCodeBorderSuccess
            }
            return Color.authSubtitle
        }()
        
        return TextField("", text: Binding(
            get: { textBinding.wrappedValue },
            set: { newValue in
                let filtered = newValue.filter { $0.isNumber }
                let digit = filtered.last.map(String.init) ?? ""
                let previous = textBinding.wrappedValue
                textBinding.wrappedValue = digit
                
                if digit.count == 1 {
                    if index < 5 {
                        focusedCodeIndex = index + 1
                    } else {
                        focusedCodeIndex = nil
                    }
                } else if previous.count == 1 && digit.isEmpty && index > 0 {
                    focusedCodeIndex = index - 1
                }
            }
        ))
        .keyboardType(.numberPad)
        .textContentType(.oneTimeCode)
        .multilineTextAlignment(.center)
        .tint(.clear) // скрываем курсор, фокус только рамкой
        .focused($focusedCodeIndex, equals: index)
        .frame(width: 50, height: 75)
        .background(shape.fill(Color.authCodeBackground))
        .overlay(shape.stroke(borderColor, lineWidth: 2))
        .clipShape(shape)
        .shadow(color: Color.black.opacity(0.16), radius: 4, x: 0, y: 4)
        .font(.system(size: 28, weight: .medium))
        .onTapGesture {
            focusedCodeIndex = index
        }
        .overlay {
            if textBinding.wrappedValue.isEmpty {
                Text("0")
                    .foregroundColor(Color.authSubtitle.opacity(0.4))
                    .font(.system(size: 28, weight: .medium))
            }
        }
    }
}

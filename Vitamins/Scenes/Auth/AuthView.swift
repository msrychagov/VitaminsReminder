//
//  Untitled.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

import SwiftUI
import ComposableArchitecture
import Combine

struct AuthView: View {
    
    let viewStore: StoreOf<AuthFeature>
    
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
            VStack(spacing: 16) {
                Text("Код отправлен на \(viewStore.resetEmail)")
                    .font(.custom("Commissioner-ExtraBold", size: 24))
                    .foregroundStyle(Color.authTitle)
                    .multilineTextAlignment(.center)
                    .padding(.top, 120)
                    .padding(.horizontal, contentPadding)
                
                Text("Экран ввода кода временно недоступен.")
                    .font(.custom("Commissioner-Regular", size: 15))
                    .foregroundStyle(Color.authSubtitle)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, contentPadding)
                
                Spacer()
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
}

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
    
    var body: some View {
        WithViewStore(self.viewStore, observe: { $0 }) {viewStore in
            VStack(alignment: .center) {
                titleLabel(viewStore)
                emailTextField(viewStore)
                passwordTextField(viewStore)
                if viewStore.mode == .signIn {
                    HStack {
                        Spacer()
                        secondaryButton(viewStore)
                    }
                }
                primaryButton(viewStore)
                if viewStore.mode == .signUp {
                    secondaryButton(viewStore)
                }
                Spacer()
            }
            .padding(.top, 134)
            .padding(.horizontal, 27)
        }
    }
    
    private func titleLabel(_ viewStore: ViewStoreOf<AuthFeature>) -> some View {
        Text(viewStore.ui.title)
            .font(.system(size: 32, weight: .bold))
            .foregroundStyle(Color.blue)
    }
    
    private func textField(textFieldModel: ) {
        TextField(
            ,
            
        )
    }
    
    private func emailTextField(_ viewStore: ViewStoreOf<AuthFeature>) -> some View {
        TextField(
            "E-mail",
            text: viewStore.binding(
                get: { $0.form.email },
                send: { .form(.didEmailChange($0)) }
            )
        )
        .inputFieldStyle(isError: viewStore.viewState == .data, errorMessage: "Введите e-mail")
    }
    
    private func passwordTextField(_ viewStore: ViewStoreOf<AuthFeature>) -> some View {
        TextField(
            "Пароль",
            text: viewStore.binding(
                get: { $0.form.password },
                send: { .form(.didEmailChange($0)) }
            )
        )
        .inputFieldStyle(isError: viewStore.viewState != .data, errorMessage: "Введите пароль")
        .padding(.top, viewStore.viewState != .data ? 22 : 0)
    }
    
    private func primaryButton(_ viewStore: ViewStoreOf<AuthFeature>) -> some View {
        Button{
            viewStore.send(.primaryButtonTapped)
        } label: {
            Text(viewStore.ui.primaryButtonTitle)
                .foregroundColor(.white)
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Color.blue
                )
                .clipShape(Capsule())
                .shadow(
                    color: Color.blue.opacity(0.3),
                    radius: 12, y: 4
                )
        }
        .padding(.top, viewStore.viewState == .data ? 22 : 0)
    }
    
    private func secondaryButton(_ viewStore: ViewStoreOf<AuthFeature>) -> some View {
        HStack(spacing: 4) {
            Text(viewStore.ui.secondaryPrefix)
                .foregroundColor(.black)
                .underline()

            Button {
                viewStore.send(.secondaryButtonTapped)
            } label: {
                Text(viewStore.ui.secondaryAction)
                    .foregroundColor(Color.blue)
                    .fontWeight(.light)
                    .underline()
            }
        }
        .font(.system(size: 14))
        .padding(.top, viewStore.mode == .signIn ? 2 : 20)
    }

}

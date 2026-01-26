//
//  AuthScreenConfig.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 30.11.2025.
//

struct AuthScreenConfig: Equatable {
    let title: String
    var subtitle: String? = nil
    let primaryButtonTitle: String
    var secondaryPrefix: String? = nil
    var secondaryAction: String? = nil

    // сюда потом можно добавить:
    // let iconName: String
    // let accentColor: Color
    // let description: String
}

struct AuthTextFieldModel {
    let placeholder: String
    let errorMessage: String
}


extension AuthScreenConfig {
    static func make(for mode: AuthFeature.Mode) -> AuthScreenConfig {
        switch mode {
        case .signIn:
            return AuthScreenConfig(
                title: "Войдите в аккаунт",
                primaryButtonTitle: "Войти",
                secondaryAction: "Забыли пароль?"
            )

        case .signUp:
            return AuthScreenConfig(
                title: "Создайте аккаунт",
                primaryButtonTitle: "Зарегистрироваться",
                secondaryPrefix: "Уже есть аккаунт?",
                secondaryAction: "Войти"
            )
        case .passwordReset:
            return AuthScreenConfig(
                title: "Восстановление пароля",
                subtitle: "Придумайте новый пароль",
                primaryButtonTitle: "Продолжить",
            )
        }
    }
}

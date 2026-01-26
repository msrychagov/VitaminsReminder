//
//  TextFieldModelFactory.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

struct AuthTextFieldModelFactory {
    static func makeEmailField() -> AuthTextFieldModel {
        AuthTextFieldModel(
            placeholder: "Email",
            errorMessage: <#T##String#>
        )
    }
}

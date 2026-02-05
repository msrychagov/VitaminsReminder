//
//  AuthError.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation

enum AuthError: Error, Equatable {
    case conflict // Пользователь уже зарегистрирован
    case unauthorized // Неверный email или пароль
    case badRequest // Некорректный запрос
    case unprocessableEntity // Ошибка валидации
    case serverError(code: Int) // Ошибка сервера
    case networkError // Сетевая ошибка
    case unknown // Неизвестная ошибка
    
    static func from(_ error: Error) -> AuthError {
        if let apiError = error as? APIError {
            switch apiError {
            case .conflict:
                return .conflict
            case .unauthorized:
                return .unauthorized
            case .badRequest:
                return .badRequest
            case .unprocessableEntity:
                return .unprocessableEntity
            case .serverError(let code):
                return .serverError(code: code)
            default:
                return .unknown
            }
        } else if error is NetworkClientErrors {
            return .networkError
        } else {
            return .unknown
        }
    }
}







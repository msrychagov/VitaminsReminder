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
    case notFound // Пользователь не найден
    case tooManyRequests // Слишком много попыток
    case badRequest // Некорректный запрос
    case unprocessableEntity // Ошибка валидации
    case emailRequired // Email обязателен
    case invalidEmailFormat // Некорректный формат email
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
            case .badRequest(let data):
                return mapValidationError(from: data, fallback: .badRequest)
            case .unprocessableEntity(let data):
                return mapValidationError(from: data, fallback: .unprocessableEntity)
            case .notFound:
                return .notFound
            case .tooManyRequests:
                return .tooManyRequests
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

private extension AuthError {
    struct BackendErrorPayload: Decodable {
        let code: String?
        let message: String?
    }

    static func mapValidationError(from data: Data?, fallback: AuthError) -> AuthError {
        guard
            let data,
            !data.isEmpty,
            let payload = try? JSONDecoder().decode(BackendErrorPayload.self, from: data),
            let code = payload.code?.uppercased()
        else {
            return fallback
        }

        switch code {
        case "EMAIL_REQUIRED":
            return .emailRequired
        case "INVALID_EMAIL_FORMAT":
            return .invalidEmailFormat
        default:
            return fallback
        }
    }
}











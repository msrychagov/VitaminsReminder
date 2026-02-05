//
//  TokenStorage.swift
//  Vitamins
//
//  Created by Михаил Рычагов on 26.01.2026.
//

import Foundation
import Security

struct TokenStorage {
    private static let accessTokenKey = "com.vitamins.accessToken"
    private static let refreshTokenKey = "com.vitamins.refreshToken"
    private static let service = "com.vitamins.tokens"
    
    // MARK: - Access Token
    
    static var accessToken: String? {
        get {
            getToken(key: accessTokenKey)
        }
        set {
            if let token = newValue {
                saveToken(token, key: accessTokenKey)
            } else {
                deleteToken(key: accessTokenKey)
            }
        }
    }
    
    // MARK: - Refresh Token
    
    static var refreshToken: String? {
        get {
            getToken(key: refreshTokenKey)
        }
        set {
            if let token = newValue {
                saveToken(token, key: refreshTokenKey)
            } else {
                deleteToken(key: refreshTokenKey)
            }
        }
    }
    
    // MARK: - Public Methods
    
    static func save(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
    
    static func clear() {
        accessToken = nil
        refreshToken = nil
    }
    
    static var isAuthenticated: Bool {
        accessToken != nil
    }
    
    // MARK: - Private Keychain Methods
    
    private static func saveToken(_ token: String, key: String) {
        guard let data = token.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Удаляем старый токен, если есть
        SecItemDelete(query as CFDictionary)
        
        // Сохраняем новый токен
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save token to Keychain: \(status)")
        }
    }
    
    private static func getToken(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    private static func deleteToken(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}






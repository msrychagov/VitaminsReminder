//
//  AccountCreationStatusView.swift
//  Vitamins
//
//  Created by Codex on 09.02.2026.
//

import SwiftUI

struct AccountCreationStatusView: View {
    let status: AuthFeature.RegistrationStatus
    var onPrimaryAction: () -> Void
    
    @State private var animateLoader = false
    @State private var animateSuccess = false
    
    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                    .padding(.top, 72)
                
                Spacer()
                
                statusGraphic
                    .frame(height: 260)
                    .padding(.top, status == .creating ? 20 : 0)
                
                Spacer()
                
                if status == .success {
                    primaryButton
                        .padding(.horizontal, 24)
                        .padding(.bottom, 52)
                } else {
                    Spacer(minLength: 80)
                }
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            syncAnimations(with: status)
        }
        .onChange(of: status) { newValue in
            syncAnimations(with: newValue)
        }
    }
    
    private var background: some View {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: Color(hex: "DEFFCE"), location: 0.02),
                .init(color: Color(hex: "6F95FC"), location: 0.55),
                .init(color: Color(hex: "0773F1"), location: 0.99)
            ],
            startPoint: UnitPoint(x: 0.48, y: 1.08),
            endPoint: UnitPoint(x: 0.52, y: -0.08)
        )
    }
    
    @ViewBuilder
    private var header: some View {
        VStack(spacing: status == .creating ? 12 : 10) {
            Text(status == .creating ? "Создаём аккаунт..." : "Аккаунт создан!")
                .font(.custom("Commissioner-ExtraBold", size: 32))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            
            if status == .success {
                Text("Теперь вы можете перейти\nв свою аптечку.")
                    .font(.custom("Commissioner-Regular", size: 16))
                    .foregroundStyle(Color.white.opacity(0.86))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private var statusGraphic: some View {
        if status == .creating {
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(animateLoader ? 360 : 0))
                .animation(
                    .linear(duration: 1.05)
                        .repeatForever(autoreverses: false),
                    value: animateLoader
                )
        } else {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .frame(width: 240, height: 240)
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 2)
                    .frame(width: 190, height: 190)
                Circle()
                    .stroke(Color.white.opacity(0.24), lineWidth: 2)
                    .frame(width: 145, height: 145)
                
                Circle()
                    .stroke(Color.white, lineWidth: 10)
                    .frame(width: 138, height: 138)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(animateSuccess ? 1.0 : 0.8)
            .opacity(animateSuccess ? 1.0 : 0.4)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.78),
                value: animateSuccess
            )
        }
    }
    
    private var primaryButton: some View {
        Button(action: onPrimaryAction) {
            Text("Перейти в аптечку")
                .font(.custom("Commissioner-SemiBold", size: 17))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: 6)
        }
    }
    
    private func syncAnimations(with status: AuthFeature.RegistrationStatus) {
        animateLoader = status == .creating
        if status == .success {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                animateSuccess = true
            }
        } else {
            animateSuccess = false
        }
    }
}

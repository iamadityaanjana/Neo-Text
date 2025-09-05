//
//  WelcomeView.swift
//  Neo
//
//  Created by Aditya Anjana on 05/09/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var userName = ""
    @State private var isAnimating = false
    @AppStorage("userName") private var storedUserName = ""
    @AppStorage("isFirstLaunch") private var isFirstLaunch = true
    
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.86)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: 20) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.black.opacity(0.8))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(), value: isAnimating)
                    
                    Text("Welcome to Neo")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Your minimalist text editor")
                        .font(.system(size: 18))
                        .foregroundColor(.black.opacity(0.7))
                }
                
                VStack(spacing: 20) {
                    Text("What's your name?")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.black)
                    
                    TextField("Enter your name", text: $userName)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color.white.opacity(0.8))
                                .shadow(radius: 2)
                        )
                        .foregroundColor(.black)
                        .font(.system(size: 18))
                        .frame(width: 300)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        if !userName.trimmingCharacters(in: .whitespaces).isEmpty {
                            storedUserName = userName.trimmingCharacters(in: .whitespaces)
                            isFirstLaunch = false
                        }
                    }) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 24)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(25)
                    }
                    .disabled(userName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity(userName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
                }
                
                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

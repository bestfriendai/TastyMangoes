//  SignInView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 16:30 (America/Los_Angeles - Pacific Time)
//  Notes: Sign in screen for user authentication - matches app design patterns

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSignUp = false
    @State private var showPassword = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        // Logo/Header Section
                        VStack(spacing: 16) {
                            // Mango Logo
                            MangoLogoIcon(size: 64, color: Color(hex: "#FFA500"))
                            
                            Text("Welcome Back")
                                .font(.custom("Nunito-Bold", size: 28))
                                .foregroundColor(Color(hex: "#1a1a1a"))
                            
                            Text("Sign in to continue")
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                        
                        // Form Section
                        VStack(spacing: 20) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.custom("Inter-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#333333"))
                                
                                TextField("Enter your email", text: $email)
                                    .font(.custom("Inter-Regular", size: 16))
                                    .foregroundColor(Color(hex: "#333333"))
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 12)
                                    .background(Color(hex: "#f3f3f3"))
                                    .cornerRadius(8)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.custom("Inter-SemiBold", size: 14))
                                    .foregroundColor(Color(hex: "#333333"))
                                
                                HStack {
                                    if showPassword {
                                        TextField("Enter your password", text: $password)
                                            .font(.custom("Inter-Regular", size: 16))
                                            .foregroundColor(Color(hex: "#333333"))
                                    } else {
                                        SecureField("Enter your password", text: $password)
                                            .font(.custom("Inter-Regular", size: 16))
                                            .foregroundColor(Color(hex: "#333333"))
                                    }
                                    
                                    Button(action: {
                                        showPassword.toggle()
                                    }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(Color(hex: "#666666"))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#f3f3f3"))
                                .cornerRadius(8)
                            }
                            
                            // Error Message
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(.custom("Inter-Regular", size: 14))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                            }
                            
                            // Sign In Button
                            Button(action: {
                                signIn()
                            }) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .font(.custom("Nunito-Bold", size: 16))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#FFC966"), Color(hex: "#FFA500")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                            .disabled(isLoading || email.isEmpty || password.isEmpty)
                            .opacity((isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                            
                            // Sign Up Link
                            HStack(spacing: 4) {
                                Text("Don't have an account?")
                                    .font(.custom("Inter-Regular", size: 14))
                                    .foregroundColor(Color(hex: "#666666"))
                                
                                Button(action: {
                                    showingSignUp = true
                                }) {
                                    Text("Sign Up")
                                        .font(.custom("Inter-SemiBold", size: 14))
                                        .foregroundColor(Color(hex: "#FEA500"))
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
            .background(Color(hex: "#fdfdfd"))
            .navigationDestination(isPresented: $showingSignUp) {
                SignUpView()
                    .environmentObject(authManager)
            }
        }
    }
    
    private func signIn() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signIn(email: email, password: password)
                await AnalyticsService.shared.logSignIn()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthManager.shared)
}


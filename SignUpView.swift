//  SignUpView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 16:30 (America/Los_Angeles - Pacific Time)
//  Notes: Sign up screen for user registration - matches app design patterns

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header Section
                    VStack(spacing: 16) {
                        // Mango Logo
                        MangoLogoIcon(size: 64, color: Color(hex: "#FFA500"))
                        
                        Text("Create Account")
                            .font(.custom("Nunito-Bold", size: 28))
                            .foregroundColor(Color(hex: "#1a1a1a"))
                        
                        Text("Join TastyMangoes today")
                            .font(.custom("Inter-Regular", size: 16))
                            .foregroundColor(Color(hex: "#666666"))
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                    
                    // Form Section
                    VStack(spacing: 20) {
                        // Username Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            TextField("Choose a username", text: $username)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#333333"))
                                .autocapitalization(.none)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#f3f3f3"))
                                .cornerRadius(8)
                        }
                        
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
                            
                            SecureField("Create a password", text: $password)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#333333"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#f3f3f3"))
                                .cornerRadius(8)
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.custom("Inter-SemiBold", size: 14))
                                .foregroundColor(Color(hex: "#333333"))
                            
                            SecureField("Confirm your password", text: $confirmPassword)
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#333333"))
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
                        
                        // Sign Up Button
                        Button(action: {
                            signUp()
                        }) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign Up")
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
                        .disabled(isLoading || !isFormValid)
                        .opacity((isLoading || !isFormValid) ? 0.6 : 1.0)
                        
                        // Sign In Link
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Color(hex: "#666666"))
                            
                            Button(action: {
                                dismiss()
                            }) {
                                Text("Sign In")
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
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var isFormValid: Bool {
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func signUp() {
        guard isFormValid else {
            if password != confirmPassword {
                errorMessage = "Passwords do not match"
            } else if password.count < 6 {
                errorMessage = "Password must be at least 6 characters"
            } else {
                errorMessage = "Please fill in all fields"
            }
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authManager.signUp(email: email, password: password, username: username)
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(AuthManager.shared)
    }
}


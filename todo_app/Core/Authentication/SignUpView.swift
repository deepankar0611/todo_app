//  SignUpView.swift
//  todo_app
//
//  Created by Deepankar Singh on 15/03/25.
//

import SwiftUI
import FirebaseAuth

struct SignUpView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isSignedUp = false // Renamed for clarity

    var body: some View {
        NavigationStack {
            VStack {
                // Image
                Image("pngwing.com")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 120)
                    .padding(.vertical, 32)

                // Form Fields
                VStack(spacing: 24) {
                    InputView(text: $fullName, title: "Full Name", placeholder: "Enter your full name")
                    InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
                    InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                    InputView(text: $confirmPassword, title: "Confirm Password", placeholder: "Re-enter your password", isSecureField: true)
                }
                .padding(.horizontal)

                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 8)
                }

                // Sign Up Button
                Button(action: signUp) {
                    if isLoading {
                        ProgressView()
                    } else {
                        HStack {
                            Text("Sign Up").fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.green)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Spacer()

                // Navigation to Login Page
                NavigationLink("Already have an account? Sign In", destination: LoginView())
                    .foregroundColor(.blue)
                    .padding(.bottom, 32)
            }
            .navigationBarBackButtonHidden(true)
            // Modern navigation to TodoView
            .navigationDestination(isPresented: $isSignedUp) {
                TodoView()
            }
        }
    }

    // MARK: - Firebase Sign-Up Function
    private func signUp() {
        guard !fullName.isEmpty, !email.isEmpty, !password.isEmpty, password == confirmPassword else {
            errorMessage = "Please fill in all fields correctly and ensure passwords match."
            return
        }

        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                return
            }
            
            isSignedUp = true
        }
    }
}

#Preview {
    SignUpView()
}



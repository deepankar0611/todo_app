// LoginView.swift
import SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var isLoggedIn = false

    var body: some View {
        NavigationStack {
            VStack {
                Image("pngwing.com")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 120)
                    .padding(.vertical, 32)

                VStack(spacing: 24) {
                    InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
                    InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                }
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 8)
                }

                Button(action: login) {
                    if isLoading {
                        ProgressView()
                    } else {
                        HStack {
                            Text("Sign In").fontWeight(.semibold)
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .cornerRadius(12)
                .padding(.horizontal, 32)
                .padding(.top, 16)

                Spacer()

                NavigationLink(destination: SignUpView()) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
                .padding(.bottom, 32)
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $isLoggedIn) {
                TodoView()
            }
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            return
        }

        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    errorMessage = error.localizedDescription
                    return
                }
                
                // Check if email is verified
                if let user = Auth.auth().currentUser {
                    if user.isEmailVerified {
                        isLoggedIn = true
                    } else {
                        errorMessage = "Please verify your email before logging in."
                        // Optionally sign out the unverified user
                        try? Auth.auth().signOut()
                    }
                }
            }
        }
    }
}

#Preview {
    LoginView()
}

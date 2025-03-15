// SignUpView.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore  // Add Firestore import

struct SignUpView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showSnackbar = false
    @State private var navigateToLogin = false
    
    private let db = Firestore.firestore()  // Firestore reference
    
    var body: some View {
        NavigationStack {
            VStack {
                Image("pngwing.com")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 120)
                    .padding(.vertical, 32)

                VStack(spacing: 24) {
                    InputView(text: $fullName, title: "Full Name", placeholder: "Enter your full name")
                    InputView(text: $email, title: "Email Address", placeholder: "name@example.com")
                    InputView(text: $password, title: "Password", placeholder: "Enter your password", isSecureField: true)
                    InputView(text: $confirmPassword, title: "Confirm Password", placeholder: "Re-enter your password", isSecureField: true)
                }
                .padding(.horizontal)

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.top, 8)
                }

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

                NavigationLink("Already have an account? Sign In", destination: LoginView())
                    .foregroundColor(.blue)
                    .padding(.bottom, 32)
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToLogin) {
                LoginView()
            }
            .overlay(alignment: .bottom) {
                if showSnackbar {
                    Text("Please check your email to verify your account")
                        .padding()
                        .background(Color.gray.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .bottom))
                        .padding(.bottom, 20)
                }
            }
        }
    }

    private func signUp() {
        guard !fullName.isEmpty, !email.isEmpty, !password.isEmpty, password == confirmPassword else {
            errorMessage = "Please fill in all fields correctly and ensure passwords match."
            return
        }

        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let user = authResult?.user else { return }
            
            // Prepare user data for Firestore
            let userData: [String: Any] = [
                "fullName": fullName,
                "email": email,
                "createdAt": Timestamp(),
                "isEmailVerified": false
            ]
            
            // Save to Firestore
            db.collection("users").document(user.uid).setData(userData) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        self.errorMessage = "Failed to save user data: \(error.localizedDescription)"
                        isLoading = false
                        return
                    }
                    
                    // Send verification email
                    user.sendEmailVerification { error in
                        DispatchQueue.main.async {
                            isLoading = false
                            if let error = error {
                                self.errorMessage = error.localizedDescription
                                return
                            }
                            
                            withAnimation {
                                showSnackbar = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    showSnackbar = false
                                }
                                navigateToLogin = true
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView()
}

import SwiftUI

struct LoginFormView: View {
    @Binding var username: String
    @Binding var password: String
    @Binding var loginResult: String
    let login: () -> Void
    
    @State private var isSecured: Bool = true
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 20) {
                    Spacer()
                    
                    Text("MARCHKOV")
                        .font(.custom("Futura", size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 20) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                            TextField("学号/职工号/手机号", text: $username)
                                .autocapitalization(.none)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        HStack {
                            Image(systemName: isSecured ? "lock.fill" : "lock.open.fill")
                                .foregroundColor(.gray)
                            Group {
                                if isSecured {
                                    SecureField("密码", text: $password)
                                } else {
                                    TextField("密码", text: $password)
                                }
                            }
                            Button(action: {
                                isSecured.toggle()
                            }) {
                                Image(systemName: isSecured ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    Button(action: login) {
                        Text("登录")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(username.isEmpty || password.isEmpty)
                    .opacity(username.isEmpty || password.isEmpty ? 0.6 : 1)
                    .padding(.horizontal)
                    
                    if !loginResult.isEmpty {
                        Text(loginResult)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .frame(minHeight: geometry.size.height)
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

import SwiftUI

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    
    var body: some View {
        TabView(selection: $currentTab) {
            ReservationResultView(isLoading: $isLoading, errorMessage: $errorMessage, reservationResult: $reservationResult)
                .tabItem {
                    Label("预约结果", systemImage: "ticket.fill")
                }
                .tag(0)

            SettingsView(logout: logout, themeMode: $themeMode)
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(1)
        }
        .accentColor(.blue)
    }
}

struct ReservationResultView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    @State private var showLogs: Bool = false
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        if isLoading {
                            ProgressView("加载中...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(1.5)
                                .padding(.top, 50)
                        } else if !errorMessage.isEmpty {
                            ErrorView(errorMessage: errorMessage, isDeveloperMode: isDeveloperMode, showLogs: $showLogs)
                        } else if let result = reservationResult {
                            SuccessView(result: result, isDeveloperMode: isDeveloperMode, showLogs: $showLogs, reservationResult: $reservationResult)
                        } else {
                            Text("暂无预约结果")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding()
                            
                            if isDeveloperMode {
                                LogButton(showLogs: $showLogs)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("预约结果")
            .sheet(isPresented: $showLogs) {
                LogView()
            }
        }
    }
}

struct SuccessView: View {
    let result: ReservationResult
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    @State private var isReverseReserving: Bool = false
    @State private var showReverseReservationError: Bool = false
    @Binding var reservationResult: ReservationResult?
    
    var body: some View {
        VStack(spacing: 10) {
            Text("欢迎，\(result.username)")
            
            VStack(alignment: .leading, spacing: 15) {
                InfoRow(title: "乘车类型", value: result.isPastBus ? "临时码" : "乘车码")
                InfoRow(title: "班车名称", value: result.name)
                InfoRow(title: "发车时间", value: result.yaxis)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            
            QRCodeView(qrCode: result.qrCode)
                .frame(width: 200, height: 200)
                .padding()
            
            Button(action: {
                reverseReservation()
            }) {
                if isReverseReserving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("预约反向班车")
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(isReverseReserving)
            
            if isDeveloperMode {
                LogButton(showLogs: $showLogs)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 10)
        .alert(isPresented: $showReverseReservationError) {
            Alert(title: Text("反向预约失败"), message: Text("反向无车可坐"), dismissButton: .default(Text("确定")))
        }
    }
    
    private func reverseReservation() {
        isReverseReserving = true
        LoginService.shared.reverseReservation(currentResult: result) { result in
            DispatchQueue.main.async {
                isReverseReserving = false
                switch result {
                case .success(let newReservation):
                    reservationResult = newReservation
                case .failure:
                    showReverseReservationError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showReverseReservationError = false
                    }
                }
            }
        }
    }
}

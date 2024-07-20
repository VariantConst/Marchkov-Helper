import SwiftUI

struct UserInfoCard: View {
    let userInfo: UserInfo
    let logout: () -> Void
    @Binding var showLogoutConfirmation: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color(red: 0.2, green: 0.5, blue: 0.8)
    }

    private var gradientBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 25/255, green: 25/255, blue: 30/255), Color(red: 75/255, green: 75/255, blue: 85/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 245/255, green: 245/255, blue: 250/255), Color(red: 200/255, green: 200/255, blue: 210/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            Divider().background(Color.gray.opacity(0.2)).padding(.horizontal)
            bottomSection
        }
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(gradientBackground, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
    }

    private var topSection: some View {
        HStack(spacing: 20) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(accentColor)
                .font(.system(size: 40))

            Text(userInfo.fullName)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showLogoutConfirmation = true }) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
    }

    private var bottomSection: some View {
        HStack(alignment: .center, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: "building.2.fill")
                    .foregroundColor(accentColor)
                    .font(.system(size: 18))
                Text(userInfo.department)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
            }
            
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundColor(accentColor)
                    .font(.system(size: 18))
                Text(userInfo.studentId)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical)
    }
}

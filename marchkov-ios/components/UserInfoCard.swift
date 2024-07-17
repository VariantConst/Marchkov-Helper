import SwiftUI

struct UserInfoCard: View {
    let userInfo: UserInfo
    let logout: () -> Void
    @Binding var showLogoutConfirmation: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }

    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }

    var body: some View {
        VStack(spacing: 0) {
            topSection
            Divider().background(Color.gray.opacity(0.2)).padding(.horizontal)
            bottomSection
        }
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
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
                    .foregroundColor(.secondary)
            }
            
            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundColor(accentColor)
                    .font(.system(size: 18))
                Text(userInfo.studentId)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical)
    }
}

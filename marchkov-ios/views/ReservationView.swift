import SwiftUI

struct BusInfo: Identifiable {
    let id = UUID()
    let time: String
    let direction: String
    let margin: Int
    let resourceName: String
}

struct ReservationView: View {
    @Binding var availableBuses: [String: [BusInfo]]
    @Environment(\.colorScheme) private var colorScheme
    var refreshAction: () -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(["去燕园", "去昌平"], id: \.self) { direction in
                    Section(header: Text(direction)) {
                        ForEach(availableBuses[direction] ?? [], id: \.id) { busInfo in
                            BusButton(busInfo: busInfo)
                        }
                    }
                }
            }
            .navigationTitle("今日可预约班车")
            .background(gradientBackground(colorScheme: colorScheme).edgesIgnoringSafeArea(.all))
            .refreshable {
                refreshAction()
            }
        }
    }
}

struct BusButton: View {
    let busInfo: BusInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            // 这里可以添加预约逻辑
            print("预约 \(busInfo.direction) \(busInfo.time)")
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(busInfo.time)
                        .font(.headline)
                    Spacer()
                    Text(getBusRoute(for: busInfo.direction))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(busInfo.resourceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("余票: \(busInfo.margin)")
                    .font(.caption)
                    .foregroundColor(busInfo.margin > 5 ? .green : .orange)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(BusButtonStyle(colorScheme: colorScheme))
    }

    private func getBusRoute(for direction: String) -> String {
        switch direction {
        case "去燕园":
            return "昌平 → 燕园"
        case "去昌平":
            return "燕园 → 昌平"
        default:
            return ""
        }
    }
}

struct BusButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// 如果需要,可以将gradientBackground扩展移到这里
// extension View {
//     func gradientBackground(colorScheme: ColorScheme) -> LinearGradient {
//         // ... 实现 ...
//     }
// }
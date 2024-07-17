import Foundation

enum BusDirection {
    case toYanyuan
    case toChangping
}

struct ReservationResult {
    let isPastBus: Bool
    let name: String
    let yaxis: String
    let qrCode: String
    let username: String
    let busId: Int
    let appointmentId: Int?
    let appAppointmentId: Int?
}

struct DatedBusInfo: Codable {
    let date: Date
    let resources: [LoginService.Resource]
}

struct UserInfo {
    let fullName: String
    let studentId: String
    let department: String
}

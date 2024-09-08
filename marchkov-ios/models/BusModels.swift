import Foundation

enum BusDirection {
    case toYanyuan
    case toChangping
}

struct ReservationResult: Equatable {
    let isPastBus: Bool
    let name: String
    let yaxis: String
    let qrCode: String
    let username: String
    let busId: Int
    let appointmentId: Int?
    let appAppointmentId: Int?
    
    static func == (lhs: ReservationResult, rhs: ReservationResult) -> Bool {
        return lhs.isPastBus == rhs.isPastBus &&
               lhs.name == rhs.name &&
               lhs.yaxis == rhs.yaxis &&
               lhs.qrCode == rhs.qrCode &&
               lhs.username == rhs.username &&
               lhs.busId == rhs.busId &&
               lhs.appointmentId == rhs.appointmentId &&
               lhs.appAppointmentId == rhs.appAppointmentId
    }
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

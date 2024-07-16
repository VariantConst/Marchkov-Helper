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
}

struct DatedBusInfo: Codable {
    let date: Date
    let resources: [LoginService.Resource]
}

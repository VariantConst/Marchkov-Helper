import Foundation

struct BusReservationService {
    static func getReservationResult(resources: [LoginService.Resource], completion: @escaping (Result<ReservationResult, Error>) -> Void) {
        let userDefaults = UserDefaults.standard
        let criticalTime = userDefaults.integer(forKey: "criticalTime")
        let flagMorningToYanyuan = userDefaults.bool(forKey: "flagMorningToYanyuan")
        let prevInterval = userDefaults.integer(forKey: "prevInterval")
        let nextInterval = userDefaults.integer(forKey: "nextInterval")
        
        let currentDate = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        
        let direction: BusDirection
        if currentHour < criticalTime {
            direction = flagMorningToYanyuan ? .toYanyuan : .toChangping
        } else {
            direction = flagMorningToYanyuan ? .toChangping : .toYanyuan
        }
        
        let filteredResources = resources.filter { resource in
            let resourceId = resource.id
            return (direction == .toYanyuan && (resourceId == 2 || resourceId == 4)) ||
                   (direction == .toChangping && (resourceId == 5 || resourceId == 6 || resourceId == 7))
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: currentDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: currentDate)
        
        for resource in filteredResources {
            for busInfo in resource.busInfos {
                if busInfo.date == today && busInfo.margin > 0 {
                    let busTime = busInfo.yaxis
                    if let timeDifference = getTimeDifference(currentTime: currentTime, busTime: busTime) {
                        if timeDifference >= -prevInterval && timeDifference <= nextInterval {
                            if timeDifference < 0 {
                                // Past bus
                                getTempCode(resourceId: resource.id, startTime: busTime) { result in
                                    switch result {
                                    case .success(let qrCode):
                                        let reservationResult = ReservationResult(isPastBus: true, name: resource.name, yaxis: busTime, qrCode: qrCode)
                                        completion(.success(reservationResult))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                            } else {
                                // Future bus
                                reserveBus(resourceId: resource.id, date: today, timeId: busInfo.timeId) { result in
                                    switch result {
                                    case .success(let qrCode):
                                        let reservationResult = ReservationResult(isPastBus: false, name: resource.name, yaxis: busTime, qrCode: qrCode)
                                        completion(.success(reservationResult))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
        
        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No suitable bus found"])))
    }
    
    private static func getTimeDifference(currentTime: String, busTime: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let current = formatter.date(from: currentTime),
              let bus = formatter.date(from: busTime) else {
            return nil
        }
        
        let difference = bus.timeIntervalSince(current) / 60
        return Int(difference)
    }
    
    private static func getTempCode(resourceId: Int, startTime: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id=\(resourceId)&text=\(startTime)")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let d = json["d"] as? [String: Any],
                   let code = d["code"] as? String {
                    completion(.success(code))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private static func reserveBus(resourceId: Int, date: String, timeId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/launch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyData = "resource_id=\(resourceId)&data=[{\"date\": \"\(date)\", \"period\": \(timeId), \"sub_resource_id\": 0}]"
        request.httpBody = bodyData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            getReservationQRCode(resourceId: resourceId, date: date, yaxis: "") { result in
                completion(result)
            }
        }.resume()
    }
    
    private static func getReservationQRCode(resourceId: Int, date: String, yaxis: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc")!
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let d = json["d"] as? [String: Any],
                   let apps = d["data"] as? [[String: Any]] {
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let today = dateFormatter.string(from: Date())
                    
                    for app in apps {
                        if let appResourceId = app["resource_id"] as? Int,
                           let appTime = app["appointment_time"] as? String,
                           let appId = app["id"] as? Int,
                           let appAppointmentId = app["hall_appointment_data_id"] as? Int,
                           appResourceId == resourceId,
                           appTime.starts(with: "\(today) \(yaxis)") {
                            
                            getQRCode(appId: appId, appAppointmentId: appAppointmentId) { result in
                                completion(result)
                            }
                            return
                        }
                    }
                    
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No matching reservation found"])))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private static func getQRCode(appId: Int, appAppointmentId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?id=\(appId)&type=0&hall_appointment_data_id=\(appAppointmentId)")!
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let d = json["d"] as? [String: Any],
                   let code = d["code"] as? String {
                    completion(.success(code))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

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

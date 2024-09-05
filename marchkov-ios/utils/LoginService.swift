import Foundation

struct LoginService {
    static let shared = LoginService()
    private init() {}
    
    private var token: String?
    private let session = URLSession.shared
    
    struct LoginResponse: Codable {
        let success: Bool
        let token: String?
    }
    
    struct BusInfo: Codable {
        let timeId: Int
        let yaxis: String
        let date: String
        let margin: Int
        
        enum CodingKeys: String, CodingKey {
            case timeId = "time_id"
            case yaxis
            case date
            case row
        }
        
        enum RowKeys: String, CodingKey {
            case margin
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            timeId = try container.decode(Int.self, forKey: .timeId)
            yaxis = try container.decode(String.self, forKey: .yaxis)
            date = try container.decode(String.self, forKey: .date)
            
            let rowContainer = try container.nestedContainer(keyedBy: RowKeys.self, forKey: .row)
            margin = try rowContainer.decode(Int.self, forKey: .margin)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(timeId, forKey: .timeId)
            try container.encode(yaxis, forKey: .yaxis)
            try container.encode(date, forKey: .date)
            
            var rowContainer = container.nestedContainer(keyedBy: RowKeys.self, forKey: .row)
            try rowContainer.encode(margin, forKey: .margin)
        }
    }
    
    struct Resource: Codable {
        let id: Int
        let name: String
        let busInfos: [BusInfo]
        
        enum CodingKeys: String, CodingKey {
            case id
            case name
            case table
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(Int.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            
            let tableContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .table)
            let tableKey = tableContainer.allKeys.first!
            busInfos = try tableContainer.decode([BusInfo].self, forKey: tableKey)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            
            var tableContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .table)
            try tableContainer.encode(busInfos, forKey: AnyCodingKey(stringValue: "1")!)
        }
    }
    
    private struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = String(intValue)
        }
    }
    
    func login(username: String, password: String, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        LogManager.shared.addLog("开始登录")
        let url = URL(string: "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyData = "appid=wproc&userName=\(encodedUsername)&password=\(encodedPassword)&redirUrl=https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/"

        request.httpBody = bodyData.data(using: .utf8)
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("登录失败：\(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                completion(.failure(error))
                return
            }
            
            do {
                let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                LogManager.shared.addLog("登录响应解码成功")
                if loginResponse.success, let token = loginResponse.token {
                    LogManager.shared.addLog("登录成功，开始跟随重定向")
                    self.followRedirect(token: token) { result in
                        switch result {
                        case .success:
                            LogManager.shared.addLog("重定向成功")
                            completion(.success(loginResponse))
                        case .failure(let error):
                            LogManager.shared.addLog("重定向失败：\(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                } else {
                    LogManager.shared.addLog("登录失败：响应表示失败")
                    completion(.success(loginResponse))
                }
            } catch {
                LogManager.shared.addLog("登录响应解码失败：\(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    private func followRedirect(token: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let redirectURL = URL(string: "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token=\(token)")!
        
        LogManager.shared.addLog("发送重定向请求 - URL: \(redirectURL.absoluteString)")
        let task = session.dataTask(with: redirectURL) { _, response, error in
            if let error = error {
                LogManager.shared.addLog("重定向失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("重定向成功: 状态码 \(httpResponse.statusCode)")
                completion(.success(()))
            } else {
                let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                LogManager.shared.addLog("重定向失败: 无效的响应")
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func getResources(token: String, completion: @escaping (Result<[Resource], Error>) -> Void) {
        if let cachedBusInfo = getCachedBusInfo(), Calendar.current.isDateInToday(cachedBusInfo.date) {
            LogManager.shared.addLog("使用缓存的班车信息")
            completion(.success(cachedBusInfo.resources))
            return
        }
        LogManager.shared.addLog("从网络获取班车信息")
        // Step 1: Follow redirect with token
        let redirectURL = URL(string: "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token=\(token)")!
        
        LogManager.shared.addLog("Step 1: 发送重定向请求 - URL: \(redirectURL.absoluteString)")
        let task1 = session.dataTask(with: redirectURL) { _, response, error in
            if let error = error {
                LogManager.shared.addLog("Step 1 失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("Step 1 成功: 状态码 \(httpResponse.statusCode)")
            }
            
            // Step 2: Get resources
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.string(from: Date())
            let resourcesURL = URL(string: "https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=\(date)&p=1&page_size=0")!
            
            LogManager.shared.addLog("Step 2: 获取资源 - URL: \(resourcesURL.absoluteString)")
            let task2 = self.session.dataTask(with: resourcesURL) { data, response, error in
                if let error = error {
                    LogManager.shared.addLog("Step 2 失败: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    LogManager.shared.addLog("Step 2 失败: 未收到数据")
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    LogManager.shared.addLog("Step 2 成功: 状态 \(httpResponse.statusCode)")
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    
                    let listData = try JSONSerialization.data(withJSONObject: (json?["d"] as? [String: Any])?["list"] ?? [], options: [])
                    let resources = try JSONDecoder().decode([Resource].self, from: listData)
                    LogManager.shared.addLog("成功解析资源: 共\(resources.count)个资源")
                    self.cacheBusInfo(DatedBusInfo(date: Date(), resources: resources))
                    completion(.success(resources))
                } catch {
                    LogManager.shared.addLog("解析资源失败: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
            task2.resume()
        }
        task1.resume()
    }
    
    private func getCachedBusInfo() -> DatedBusInfo? {
        guard let data = UserDefaults.standard.data(forKey: "cachedBusInfo") else {
            return nil
        }
        return try? JSONDecoder().decode(DatedBusInfo.self, from: data)
    }
    
    private func cacheBusInfo(_ busInfo: DatedBusInfo) {
        if let encoded = try? JSONEncoder().encode(busInfo) {
            UserDefaults.standard.set(encoded, forKey: "cachedBusInfo")
        }
    }
    
    func getReservationResult(resources: [Resource], forceDirection: BusDirection? = nil, isReverseAttempt: Bool = false, completion: @escaping (Result<ReservationResult, Error>) -> Void) {
        LogManager.shared.addLog("开始获取预约结果")
        let userDefaults = UserDefaults.standard
        let criticalTime = userDefaults.integer(forKey: "criticalTime")
        let flagMorningToYanyuan = userDefaults.bool(forKey: "flagMorningToYanyuan")
        let prevInterval = userDefaults.integer(forKey: "prevInterval")
        let nextInterval = userDefaults.integer(forKey: "nextInterval")
        
        LogManager.shared.addLog("设置参数: 临界时间 = \(criticalTime), 早上去燕园 = \(flagMorningToYanyuan), 过期班车追溯 = \(prevInterval), 未来班车预约 = \(nextInterval)")
        
        let currentDate = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: currentDate)
        let currentMinute = calendar.component(.minute, from: currentDate)
        let minutesSinceMidnight = currentHour * 60 + currentMinute
        
        let direction: BusDirection
        if let forcedDirection = forceDirection {
            direction = forcedDirection
            LogManager.shared.addLog("强制设置班车方向为 \(direction)")
        } else if minutesSinceMidnight < criticalTime {
            LogManager.shared.addLog("flagMorningToYanyuan \(flagMorningToYanyuan), minutesSinceMidnight \(minutesSinceMidnight), criticalTime \(criticalTime)")
            direction = flagMorningToYanyuan ? .toYanyuan : .toChangping
            LogManager.shared.addLog("自动设置班车方向为 \(direction)")
        } else {
            direction = flagMorningToYanyuan ? .toChangping : .toYanyuan
            LogManager.shared.addLog("自动设置班车方向为 \(direction)")
        }
        
        let formattedTime = String(format: "%02d:%02d", currentHour, currentMinute)
        LogManager.shared.addLog("当前时间: \(formattedTime), 班车方向: \(direction == .toYanyuan ? "去燕园" : "去昌平")")
        
        let filteredResources = resources.filter { resource in
            let resourceId = resource.id
            return (direction == .toYanyuan && (resourceId == 2 || resourceId == 4)) ||
            (direction == .toChangping && (resourceId == 5 || resourceId == 6 || resourceId == 7))
        }
        
        LogManager.shared.addLog("筛选后的资源数量: \(filteredResources.count)")
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: currentDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let currentTime = timeFormatter.string(from: currentDate)
        
        LogManager.shared.addLog("当前日期: \(today), 当前时间: \(currentTime)")
        
        for resource in filteredResources {
            LogManager.shared.addLog("检查资源: ID = \(resource.id), 名称 = \(resource.name)")
            for busInfo in resource.busInfos {
                if busInfo.date == today && busInfo.margin > 0 {
                    let busTime = busInfo.yaxis
                    LogManager.shared.addLog("正在检查班车：busTime \(busTime), currentTime \(currentTime)")
                    if let timeDifference = getTimeDifference(currentTime: currentTime, busTime: busTime) {
                        LogManager.shared.addLog("时间差 \(timeDifference), prevInterval \(prevInterval), nextInterval \(nextInterval)")
                        if timeDifference >= -prevInterval && timeDifference <= nextInterval {
                            if timeDifference <= 0 {
                                // Past bus
                                LogManager.shared.addLog("找到过期班车, 获取临时码")
                                getTempCode(resourceId: resource.id, startTime: busTime) { (result: Result<(code: String, name: String), Error>) in
                                    switch result {
                                    case .success(let (qrCode, name)):
                                        LogManager.shared.addLog("成功获取临时码")
                                        let reservationResult = ReservationResult(
                                            isPastBus: true,
                                            name: resource.name,
                                            yaxis: busTime,
                                            qrCode: qrCode,
                                            username: name,
                                            busId: resource.id,
                                            appointmentId: nil,
                                            appAppointmentId: nil
                                        )
                                        completion(.success(reservationResult))
                                    case .failure(let error):
                                        LogManager.shared.addLog("获取临时码失败: \(error.localizedDescription)")
                                        completion(.failure(error))
                                    }
                                }
                            } else {
                                // Future bus
                                LogManager.shared.addLog("找到未来班车 resourceId=\(resource.id), name=\(resource.name) yaxis=\(busTime), 开始预约")
                                reserveBus(resource: resource, date: today, timeId: busInfo.timeId, busTime: busTime) { result in
                                    completion(result)
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
        
        LogManager.shared.addLog("未找到合适的班车")
        if !isReverseAttempt && forceDirection == nil {
            LogManager.shared.addLog("尝试反向预约")
            let reverseDirection: BusDirection = direction == .toYanyuan ? .toChangping : .toYanyuan
            getReservationResult(resources: resources, forceDirection: reverseDirection, isReverseAttempt: true, completion: completion)
        } else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No suitable bus found"])))
        }
    }

    
    private func getTimeDifference(currentTime: String, busTime: String) -> Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let current = formatter.date(from: currentTime),
              let bus = formatter.date(from: busTime) else {
            return nil
        }
        
        let difference = bus.timeIntervalSince(current) / 60
        return Int(difference)
    }
    
    private func getTempCode(resourceId: Int, startTime: String, completion: @escaping (Result<(code: String, name: String), Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?type=1&resource_id=\(resourceId)&text=\(startTime)")!
        
        LogManager.shared.addLog("获取临时码 - URL: \(url.absoluteString)")
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("获取临时码失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("获临时码 - 状态码: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                LogManager.shared.addLog("获取临时码 - 未收到数据")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let d = json["d"] as? [String: Any],
                       let code = d["code"] as? String,
                       let rawName = d["name"] as? String {
                        let cleanedName = rawName.replacingOccurrences(of: "\r\n", with: "\n")
                        let components = cleanedName.components(separatedBy: "\n")
                            
                        // 提取姓名、学号和学院
                        let name = components.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let studentId = components.count > 1 ? components[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                        let department = components.count > 2 ? components[2].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                        
                        // 处理姓名字段，提取第一个非空的子字符串
                        let nameComponents = name.split { $0.isWhitespace }
                        let processedName = nameComponents.first.map(String.init) ?? ""
                        
                        // 更新用户信息
                        UserDataManager.shared.saveUserInfo(fullName: processedName, studentId: studentId, department: department)
                        
                        // 打印日志（可选）
                        LogManager.shared.addLog("更新用户信息：姓名 = \(processedName), 学号 = \(studentId), 学院 = \(department)")
                        
                       if let firstNonEmptyName = nameComponents.first {
                           let name = String(firstNonEmptyName)
                           LogManager.shared.addLog("获取临时码成功: \(code)")
                           completion(.success((code: code, name: name)))
                       } else {
                           LogManager.shared.addLog("获取临时码 - name 字段为空")
                           completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Name field is empty"])))
                       }
                    } else {
                        LogManager.shared.addLog("获取临时码 - 无效的响应格式")
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                }
            } catch {
                LogManager.shared.addLog("获取临时码 - JSON解析失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func reserveBus(resource: Resource, date: String, timeId: Int, busTime: String, completion: @escaping (Result<ReservationResult, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/launch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyData = "resource_id=\(resource.id)&data=[{\"date\": \"\(date)\", \"period\": \(timeId), \"sub_resource_id\": 0}]"
        request.httpBody = bodyData.data(using: .utf8)

        LogManager.shared.addLog("预约班车 - URL: \(url.absoluteString)")
        LogManager.shared.addLog("预约班车 - 请求体: \(bodyData)")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("预约班车失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("预约班车 - 状态码: \(httpResponse.statusCode)")
            }

            if let data = data, let responseString = String(data: data, encoding: .utf8) {
                LogManager.shared.addLog("预约班车 - 响应内容: \(responseString)")
            }

            LogManager.shared.addLog("预约班车成功, 开始获取预约二维码")
            self.getReservationQRCode(resource: resource, date: date, busTime: busTime) { result in
                completion(result)
            }
        }.resume()
    }
    
    func reverseReservation(currentResult: ReservationResult, completion: @escaping (Result<ReservationResult, Error>) -> Void) {
        LogManager.shared.addLog("开始反向预约")
        
        // 确定反向预约的方向
        LogManager.shared.addLog("现在预约的方向为 \(currentResult.name)")
        let yanYanyuanIds = [2, 4]
        let reverseDirection: BusDirection = yanYanyuanIds.contains(currentResult.busId) ? .toChangping : .toYanyuan
        
        // 获取资源
        self.getResources(token: token ?? "") { result in
            switch result {
            case .success(let resources):
                // 使用新的方向进行预约
                LogManager.shared.addLog("使用方向 \(reverseDirection) 进行反向预约")
                self.getReservationResult(resources: resources, forceDirection: reverseDirection) { result in
                    switch result {
                    case .success(let newResult):
                        if !currentResult.isPastBus {
                            guard let appointmentId = currentResult.appointmentId, let appAppointmentId = currentResult.appAppointmentId else {
                                LogManager.shared.addLog("取原有预约失败：缺少 appointmentId 或 appAppointmentId")
                                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing appointmentId or appAppointmentId"])))
                                return
                            }
                            
                            self.cancelReservation(appointmentId: appointmentId, appAppointmentId: appAppointmentId) { cancelResult in
                                switch cancelResult {
                                case .success:
                                    LogManager.shared.addLog("取消原有预约成功")
                                    completion(.success(newResult))
                                case .failure(let error):
                                    LogManager.shared.addLog("取消原有预约失败：\(error.localizedDescription)")
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(newResult))
                        }

                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                LogManager.shared.addLog("反向预约失败：获取资源出错 - \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }

    private func cancelReservation(appointmentId: Int, appAppointmentId: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/single-time-cancel")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyData = "appointment_id=\(appointmentId)&data_id[0]=\(appAppointmentId)"
        request.httpBody = bodyData.data(using: .utf8)

        LogManager.shared.addLog("取消预 - URL: \(url.absoluteString)")
        LogManager.shared.addLog("取消预约 - 请求体: \(bodyData)")

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("取消预约失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                LogManager.shared.addLog("取消预约 - 未收到数据")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let e = json["e"] as? Int, e == 0 {
                    LogManager.shared.addLog("取消预约成功")
                    completion(.success(()))
                } else {
                    let message = "预约取消失败"
                    LogManager.shared.addLog(message)
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: message])))
                }
            } catch {
                LogManager.shared.addLog("取消预约 - JSON解析失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }


    
    private func getReservationQRCode(resource: Resource, date: String, busTime: String, completion: @escaping (Result<ReservationResult, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=10&status=2&sort_time=true&sort=asc")!

        LogManager.shared.addLog("获取预约二维码 - URL: \(url.absoluteString)")

        session.dataTask(with: url) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("获取预约二维码失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("获取预约二维码 - 状态码: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                LogManager.shared.addLog("获取预约二维码 - 未收到数据")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    LogManager.shared.addLog("尝试获取预约二维码")
                    if let d = json["d"] as? [String: Any],
                       let apps = d["data"] as? [[String: Any]] {

                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        let today = dateFormatter.string(from: Date())
                        LogManager.shared.addLog("正在寻找具有 ID = \(resource.id), yaxis = \(today) \(busTime) 的预约信息")

                        for app in apps {
                            if let appResourceId = app["resource_id"] as? Int,
                               let appTime = (app["appointment_tim"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                               let appId = app["id"] as? Int,
                               let appAppointmentId = app["hall_appointment_data_id"] as? Int,
                               appResourceId == resource.id,
                               appTime.starts(with: "\(today) \(busTime)"),
                               let username = app["creator_name"] as? String,
                               let studentId = app["number"] as? String,
                               let department = app["creator_depart"] as? String {

                                LogManager.shared.addLog("到匹配的预约: ID = \(appId), AppointmentID = \(appAppointmentId), Username = \(username)")
                                
                                // 更新用户信息
                                UserDataManager.shared.saveUserInfo(fullName: username, studentId: studentId, department: department)
                                
                                self.getQRCode(appId: appId, appAppointmentId: appAppointmentId) { result in
                                    switch result {
                                    case .success(let qrCode):
                                        let reservationResult = ReservationResult(
                                            isPastBus: false,
                                            name: resource.name,
                                            yaxis: busTime,
                                            qrCode: qrCode,
                                            username: username,
                                            busId: resource.id,
                                            appointmentId: appId,
                                            appAppointmentId: appAppointmentId
                                        )
                                        completion(.success(reservationResult))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                                return
                            }
                        }
                        
                        LogManager.shared.addLog("未找到匹配的预约")
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No matching reservation found"])))
                    } else {
                        LogManager.shared.addLog("获取预约二维码 - 无效的响应格式")
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                }
            } catch {
                LogManager.shared.addLog("获取预约二维码 - JSON解析失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    
    private func getQRCode(appId: Int, appAppointmentId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/get-sign-qrcode?id=\(appId)&type=0&hall_appointment_data_id=\(appAppointmentId)")!
        
        LogManager.shared.addLog("获取二维码 - URL: \(url.absoluteString)")
        
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("获取二维码失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                LogManager.shared.addLog("获取二维码 - 状态码: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                LogManager.shared.addLog("获取二维码 - 未收到数据")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    LogManager.shared.addLog("获取二维码 - 收到的JSON数据: \(json)")
                    if let d = json["d"] as? [String: Any],
                       let code = d["code"] as? String {
                        LogManager.shared.addLog("获取二维码成功: \(code)")
                        completion(.success(code))
                    } else {
                        LogManager.shared.addLog("获取二维码 - 无效的响应格式")
                        completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                    }
                }
            } catch {
                LogManager.shared.addLog("获取二维码 - JSON解析失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    struct RideInfo: Codable, Identifiable, Equatable {
        let id: Int
        let statusName: String
        let resourceName: String
        let appointmentTime: String
        
        static func == (lhs: RideInfo, rhs: RideInfo) -> Bool {
            return lhs.id == rhs.id &&
                   lhs.statusName == rhs.statusName &&
                   lhs.resourceName == rhs.resourceName &&
                   lhs.appointmentTime == rhs.appointmentTime
        }
    }

    struct CachedRideHistory: Codable {
        var lastFetchDate: Date
        var rides: [RideInfo]
    }

    func getRideHistory(completion: @escaping (Result<[RideInfo], Error>) -> Void) {
        guard let credentials = UserDataManager.shared.getUserCredentials() else {
            LogManager.shared.addLog("获取乘车历史失败：未找到用户凭证")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到用户凭证"])))
            return
        }
        
        // 获取缓存的乘车历史
        let cachedHistory = getCachedRideHistory()
        let lastFetchDate = cachedHistory?.lastFetchDate ?? Date.distantPast
        let cachedRides = cachedHistory?.rides ?? []
        
        // 计算需要获取的日期范围，使用北京时间
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let today = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -1, to: lastFetchDate) ?? lastFetchDate
        let endDate = today
        
        LogManager.shared.addLog("获取乘车历史：开始日期 \(dateFormatter.string(from: startDate))，结束日期 \(dateFormatter.string(from: endDate))")
        
        // 构建URL
        let urlString = "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&page_size=0&status=0&sort_time=true&sort=desc&date_sta=\(dateFormatter.string(from: startDate))&date_end=\(dateFormatter.string(from: endDate))"
        guard let url = URL(string: urlString) else {
            LogManager.shared.addLog("获取乘车历史失败：无效的URL")
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        
        // 首先进行登录
        login(username: credentials.username, password: credentials.password) { loginResult in
            switch loginResult {
            case .success(_):
                LogManager.shared.addLog("登录成功，开始获取乘车历史")
                
                // 立即尝试获取历史信息
                self.fetchRideHistory(url: url, cachedRides: cachedRides, startDate: startDate, today: today) { result in
                    switch result {
                    case .success(let rides):
                        completion(.success(rides))
                        // 在后台更新应用本地存储信息
                        DispatchQueue.global(qos: .background).async {
                            self.updateCachedRideHistory(rides: rides, lastFetchDate: today)
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                LogManager.shared.addLog("获取乘车历史前登录失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    private func fetchRideHistory(url: URL, cachedRides: [RideInfo], startDate: Date, today: Date, completion: @escaping (Result<[RideInfo], Error>) -> Void) {
        session.dataTask(with: url) { data, response, error in
            if let error = error {
                LogManager.shared.addLog("获取乘车历史网络请求失败: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                LogManager.shared.addLog("获取乘车历史失败：未收到数据")
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未收到数据"])))
                return
            }
            
            // 记录完整的响应文本
            if let responseText = String(data: data, encoding: .utf8) {
                LogManager.shared.addLog("乘车历史响应：\(responseText)")
            }
            
            do {
                let decoder = JSONDecoder()
                let jsonResponse = try decoder.decode(RideHistoryResponse.self, from: data)
                
                let newRideInfos = jsonResponse.d.data.map { ride in
                    RideInfo(id: ride.id, statusName: ride.statusName, resourceName: ride.resourceName, appointmentTime: ride.appointmentTime.trimmingCharacters(in: .whitespaces))
                }
                
                // 合并新旧记录，覆盖最后一次请求日期及之后的记录
                let mergedRides = self.mergeRides(cachedRides: cachedRides, newRides: newRideInfos, lastFetchDate: startDate)
                
                LogManager.shared.addLog("获取乘车历史成功：共 \(mergedRides.count) 条记录，新增或更新 \(newRideInfos.count) 条")
                completion(.success(mergedRides))
            } catch {
                LogManager.shared.addLog("获取乘车历史JSON解析失败: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func getCachedRideHistory() -> CachedRideHistory? {
        if let data = UserDefaults.standard.data(forKey: "cachedRideHistory") {
            return try? JSONDecoder().decode(CachedRideHistory.self, from: data)
        }
        return nil
    }
    
    private func updateCachedRideHistory(rides: [RideInfo], lastFetchDate: Date) {
        let cachedHistory = CachedRideHistory(lastFetchDate: lastFetchDate, rides: rides)
        if let encoded = try? JSONEncoder().encode(cachedHistory) {
            UserDefaults.standard.set(encoded, forKey: "cachedRideHistory")
        }
    }
    
    private func mergeRides(cachedRides: [RideInfo], newRides: [RideInfo], lastFetchDate: Date) -> [RideInfo] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        
        // 创建一个字典来存储所有已有的记录，以 ID 为键
        var mergedRidesDict = Dictionary(uniqueKeysWithValues: cachedRides.map { ($0.id, $0) })
        
        // 更新或添加新记录
        for newRide in newRides {
            if mergedRidesDict[newRide.id] != nil {
                // 如果记录已存在，更新其信息
                mergedRidesDict[newRide.id] = newRide
            } else {
                // 如果是新记录，直接添加
                mergedRidesDict[newRide.id] = newRide
            }
        }
        
        // 将字典转换回数组并排序
        let mergedRides = Array(mergedRidesDict.values)
        return mergedRides.sorted { $0.appointmentTime > $1.appointmentTime }
    }
}

// 其他相关结构体
struct RideHistoryResponse: Codable {
    let d: RideHistoryData
}

struct RideHistoryData: Codable {
    let data: [RideInfoData]
}

struct RideInfoData: Codable {
    let id: Int
    let statusName: String
    let resourceName: String
    let appointmentTime: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case statusName = "status_name"
        case resourceName = "resource_name"
        case appointmentTime = "appointment_tim"
    }
}

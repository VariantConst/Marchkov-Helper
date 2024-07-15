import Foundation

struct LoginService {
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

    static func login(username: String, password: String, completion: @escaping (Result<LoginResponse, Error>) -> Void) {
        let url = URL(string: "https://iaaa.pku.edu.cn/iaaa/oauthlogin.do")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyData = "appid=wproc&userName=\(username)&password=\(password)&redirUrl=https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/"
        request.httpBody = bodyData.data(using: .utf8)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
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
                if loginResponse.success {
                    UserDataManager.shared.saveUserCredentials(username: username, password: password)
                }
                completion(.success(loginResponse))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    static func getResources(token: String, completion: @escaping (Result<[Resource], Error>) -> Void) {
        let session = URLSession.shared
        
        // Step 1: Follow redirect with token
        let redirectURL = URL(string: "https://wproc.pku.edu.cn/site/login/cas-login?redirect_url=https://wproc.pku.edu.cn/v2/reserve/&_rand=0.6441813796046802&token=\(token)")!
        
        let task1 = session.dataTask(with: redirectURL) { _, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Step 2: Get resources
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date = dateFormatter.string(from: Date())
            let resourcesURL = URL(string: "https://wproc.pku.edu.cn/site/reservation/list-page?hall_id=1&time=\(date)&p=1&page_size=0")!
            
            let task2 = session.dataTask(with: resourcesURL) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                    completion(.failure(error))
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                    let listData = try JSONSerialization.data(withJSONObject: (json?["d"] as? [String: Any])?["list"] ?? [], options: [])
                    let resources = try JSONDecoder().decode([Resource].self, from: listData)
                    print(resources)
                    completion(.success(resources))
                } catch {
                    completion(.failure(error))
                }
            }
            task2.resume()
        }
        task1.resume()
    }
}

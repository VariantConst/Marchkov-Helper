import SwiftUI

struct LogView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var logs: [LogEntry] = []
    @State private var searchText = ""
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $searchText)
                
                List {
                    ForEach(filteredLogs) { log in
                        LogEntryView(log: log)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("日志")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("关闭") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing:
                    Button("复制") {
                        UIPasteboard.general.string = logs.map { $0.fullText }.joined(separator: "\n")
                        showCopiedAlert = true
                    }
            )
            .alert(isPresented: $showCopiedAlert) {
                Alert(title: Text("已复制"), message: Text("日志已复制到剪贴板"), dismissButton: .default(Text("确定")))
            }
        }
        .onAppear(perform: refreshLogs)
    }
    
    private var filteredLogs: [LogEntry] {
        if searchText.isEmpty {
            return logs
        } else {
            return logs.filter { $0.fullText.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    private func refreshLogs() {
        logs = LogManager.shared.getLogs()
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { LogEntry(fullText: $0) }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索日志", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let fullText: String
    let timestamp: String
    let message: String
    
    init(fullText: String) {
        self.fullText = fullText
        let components = fullText.components(separatedBy: "] ")
        if components.count >= 2,
           let timestampWithBracket = components.first,
           timestampWithBracket.hasPrefix("[") {
            self.timestamp = String(timestampWithBracket.dropFirst().dropLast())
            self.message = components.dropFirst().joined(separator: "] ")
        } else {
            self.timestamp = ""
            self.message = fullText
        }
    }
}

struct LogEntryView: View {
    let log: LogEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !log.timestamp.isEmpty {
                Text(log.timestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(log.message)
                    .font(.body)
            } else {
                Text(log.fullText)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }
}

// Preview
struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}

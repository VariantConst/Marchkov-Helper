import SwiftUI

struct LogView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var logs: [LogEntry] = []
    @State private var searchText = ""
    @State private var showCopiedAlert = false
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 22/255) : Color(red: 245/255, green: 245/255, blue: 250/255)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 0) {
                    SearchBar(text: $searchText, accentColor: accentColor)
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredLogs) { log in
                                LogEntryView(log: log, accentColor: accentColor)
                                    .transition(.opacity)
                                    .animation(.easeInOut, value: searchText)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("日志")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(accentColor)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIPasteboard.general.string = logs.map { $0.fullText }.joined(separator: "\n")
                        showCopiedAlert = true
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .foregroundColor(accentColor)
                }
            }
            .alert(isPresented: $showCopiedAlert) {
                Alert(
                    title: Text("已复制"),
                    message: Text("日志已复制到剪贴板"),
                    dismissButton: .default(Text("确定"))
                )
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
    let accentColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(accentColor)
            
            TextField("搜索日志", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(accentColor)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
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
    let accentColor: Color
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !log.timestamp.isEmpty {
                Text(log.timestamp)
                    .font(.caption)
                    .foregroundColor(accentColor)
            }
            Text(log.message)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(isExpanded ? nil : 3)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackgroundColor)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 10, x: 0, y: 5)
        .onTapGesture {
            withAnimation(.spring()) {
                isExpanded.toggle()
            }
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}

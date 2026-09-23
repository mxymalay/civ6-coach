import SwiftUI

struct ArchivedConversation: Identifiable {
    let id: URL
    let messages: [ChatMessage]
    var date: Date { messages.first?.date ?? .distantPast }
    var title: String { String((messages.first { $0.role == "user" }?.text ?? "历史对话").prefix(60)) }
}

enum ChatHistoryStore {
    static func load(from directory: URL) throws -> (items: [ArchivedConversation], unreadable: Int) {
        guard FileManager.default.fileExists(atPath: directory.path) else { return ([], 0) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        var items: [ArchivedConversation] = []
        var unreadable = 0
        for file in files where file.lastPathComponent.hasPrefix("conversation-") && file.pathExtension == "json" {
            do {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                guard values.isRegularFile == true, values.isSymbolicLink != true else { continue }
                let messages = try JSONDecoder().decode([ChatMessage].self, from: Data(contentsOf: file))
                if !messages.isEmpty { items.append(ArchivedConversation(id: file, messages: messages)) }
            } catch { unreadable += 1 }
        }
        return (items.sorted { $0.date > $1.date }, unreadable)
    }
}

struct ChatHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.coachTheme) private var theme
    @State private var items: [ArchivedConversation] = []
    @State private var selectedID: URL?
    @State private var warning: String?
    private var selected: ArchivedConversation? { items.first { $0.id == selectedID } }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("历史对话").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("仅查看").font(.system(size: 11)).foregroundStyle(theme.palette.secondary)
                Button { dismiss() } label: { Image(systemName: "xmark") }.buttonStyle(CompactActionButton()).help("关闭历史对话")
            }.padding(20)
            if let warning { Text(warning).font(.system(size: 11)).foregroundStyle(theme.palette.gold).padding(.bottom, 10) }
            HStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            Button { selectedID = item.id } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 10)).foregroundStyle(theme.palette.secondary)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .background(selectedID == item.id ? theme.palette.mint.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain)
                        }
                    }.padding(10)
                }.frame(width: 220).background(theme.palette.sidebar)
                Divider()
                if let selected {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(selected.messages) { message in
                                HStack {
                                    if message.role == "user" { Spacer(minLength: 30) }
                                    VStack(alignment: .leading, spacing: 7) {
                                        HStack {
                                            Label(message.role == "user" ? "你" : "文明陪练", systemImage: message.role == "user" ? "person.crop.circle" : "sparkles")
                                            if message.interrupted { Text("未完成") }
                                        }.font(.system(size: 10)).foregroundStyle(theme.palette.secondary)
                                        MarkdownText(text: message.text)
                                    }.padding(14).background(message.role == "user" ? theme.palette.mint.opacity(0.12) : theme.palette.card, in: RoundedRectangle(cornerRadius: 12))
                                    if message.role != "user" { Spacer(minLength: 30) }
                                }
                            }
                        }.padding(20)
                    }.id(selected.id)
                } else {
                    Text("暂无历史对话").font(.system(size: 13)).foregroundStyle(theme.palette.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }.frame(width: 820, height: 570).background(theme.palette.background).foregroundStyle(theme.palette.primary)
            .onAppear {
                do {
                    let result = try ChatHistoryStore.load(from: AppState.dataFolder)
                    items = result.items; selectedID = items.first?.id
                    if result.unreadable > 0 { warning = "有 \(result.unreadable) 份归档无法读取，原文件已保留。" }
                } catch { warning = "无法读取历史对话：" + error.localizedDescription }
            }
    }
}

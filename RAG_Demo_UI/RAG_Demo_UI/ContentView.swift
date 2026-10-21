//
//  ContentView.swift
//  RAG_Demo_UI
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Theme
private enum Theme {
    static let accent       = Color(red: 0.38, green: 0.40, blue: 0.96)
    static let accentLight  = Color(red: 0.38, green: 0.40, blue: 0.96).opacity(0.12)
    static let userBubble   = LinearGradient(colors: [Color(red: 0.38, green: 0.40, blue: 0.96),
                                                       Color(red: 0.55, green: 0.35, blue: 0.95)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
    static let botBubble    = Color(UIColor.secondarySystemBackground)
    static let bg           = Color(UIColor.systemBackground)
    static let inputBg      = Color(UIColor.secondarySystemBackground)
    static let cardShadow   = Color.black.opacity(0.07)
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var sources: [String] = []
    var context: String = ""
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var availableModels: [String] = ["llama3.2"]
    @Published var selectedModel: String = "llama3.2"
    @Published var documents: [String] = []
    @Published var selectedSources: Set<String> = []

    let api = APIService()

    func loadModels() async {
        guard let models = try? await api.listModels(), !models.isEmpty else { return }
        availableModels = models
        if !models.contains(selectedModel) { selectedModel = models[0] }
    }

    func loadDocuments() async {
        guard let docs = try? await api.listDocuments() else { return }
        documents = docs
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var state = AppState()
    @State private var inputText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var showDocuments = false
    @State private var showSettings = false
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if !state.selectedSources.isEmpty {
                    filterBanner
                }
                chatArea
                inputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showDocuments) { DocumentsView(state: state) }
            .sheet(isPresented: $showSettings)  { SettingsView(state: state)  }
        }
        .task {
            await state.loadModels()
            await state.loadDocuments()
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.accent)
                    .font(.subheadline)
                Text("DocuMind")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            toolbarButton(icon: "slider.horizontal.3") { showSettings = true }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            toolbarButton(icon: "doc.text.magnifyingglass") { showDocuments = true }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            ShareLink(item: exportText()) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.accent)
                    .frame(width: 32, height: 32)
                    .background(Theme.accentLight)
                    .clipShape(Circle())
            }
            .opacity(messages.isEmpty ? 0 : 1)
            .disabled(messages.isEmpty)
        }
    }

    private func toolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accentLight)
                .clipShape(Circle())
        }
    }

    // MARK: - Filter Banner
    private var filterBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .foregroundColor(Theme.accent)
                    .font(.caption)
                ForEach(Array(state.selectedSources).sorted(), id: \.self) { src in
                    Text(src)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.accentLight)
                        .foregroundColor(Theme.accent)
                        .clipShape(Capsule())
                }
                Button {
                    withAnimation { state.selectedSources.removeAll() }
                } label: {
                    Text("Clear all")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Chat Area
    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    if messages.isEmpty { WelcomeView() }
                    ForEach(messages) { msg in
                        MessageBubbleView(message: msg).id(msg.id)
                    }
                    if isTyping {
                        TypingIndicatorView(model: state.selectedModel).id("typing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: isTyping) { newVal in
                if newVal {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Input Bar
    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .center, spacing: 10) {
                TextField("Ask anything...", text: $inputText)
                    .font(.system(size: 15))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.inputBg)
                    .cornerRadius(22)
                    .disabled(isTyping)

                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(
                                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping
                                ? Color(UIColor.systemGray4)
                                : Theme.accent
                            )
                            .frame(width: 36, height: 36)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTyping)
                .animation(.easeInOut(duration: 0.2), value: inputText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.bg)
        }
    }

    // MARK: - Send
    private func sendMessage() {
        let question = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }

        withAnimation { messages.append(ChatMessage(text: question, isUser: true)) }
        inputText = ""
        isTyping = true

        let history: [HistoryMessage] = messages.suffix(6).map {
            HistoryMessage(role: $0.isUser ? "user" : "assistant", content: $0.text)
        }
        let filterSources = state.selectedSources.isEmpty ? nil : Array(state.selectedSources)
        let model = state.selectedModel

        Task {
            do {
                let result = try await state.api.ask(
                    question: question, model: model,
                    history: history, filterSources: filterSources
                )
                messages.append(ChatMessage(
                    text: result.answer, isUser: false,
                    sources: result.sources, context: result.context
                ))
            } catch {
                messages.append(ChatMessage(text: "⚠️ \(error.localizedDescription)", isUser: false))
            }
            isTyping = false
        }
    }

    // MARK: - Export
    private func exportText() -> String {
        var lines = ["DocuMind — Chat Export", "Model: \(state.selectedModel)", ""]
        for msg in messages {
            lines.append("\(msg.isUser ? "You" : "Assistant"): \(msg.text)")
            if !msg.isUser && !msg.sources.isEmpty {
                lines.append("Sources: \(msg.sources.joined(separator: ", "))")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Welcome View
struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.accentLight)
                    .frame(width: 90, height: 90)
                Image(systemName: "sparkles")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(Theme.userBubble)
            }
            VStack(spacing: 8) {
                Text("DocuMind")
                    .font(.title2.bold())
                Text("Upload PDFs and ask questions.\nAnswers are grounded in your documents.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            HStack(spacing: 24) {
                tipCard(icon: "arrow.up.doc", text: "Upload docs")
                tipCard(icon: "slider.horizontal.3", text: "Pick model")
                tipCard(icon: "text.bubble", text: "Ask away")
            }
            .padding(.top, 8)
        }
        .padding(.top, 60)
        .padding(.horizontal, 24)
    }

    private func tipCard(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.accentLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Message Bubble
struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var showContext = false

    var body: some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                if message.isUser { Spacer(minLength: 50) }

                if !message.isUser {
                    ZStack {
                        Circle().fill(Theme.accentLight).frame(width: 28, height: 28)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.bottom, 2)
                }

                if message.isUser {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.userBubble)
                        .clipShape(BubbleShape(isUser: true))
                        .shadow(color: Theme.accent.opacity(0.25), radius: 6, x: 0, y: 3)
                } else {
                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Theme.botBubble)
                        .clipShape(BubbleShape(isUser: false))
                        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
                }

                if message.isUser {
                    ZStack {
                        Circle().fill(Theme.accentLight).frame(width: 28, height: 28)
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.accent)
                    }
                    .padding(.bottom, 2)
                }

                if !message.isUser { Spacer(minLength: 50) }
            }

            if !message.isUser && !message.sources.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showContext.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10))
                        Text(message.sources.joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Image(systemName: showContext ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentLight)
                    .clipShape(Capsule())
                }
                .padding(.leading, 36)

                if showContext {
                    Text(message.context)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(12)
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.accentLight, lineWidth: 1)
                        )
                        .padding(.leading, 36)
                        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Bubble Shape
struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = 6
        var path = Path()
        if isUser {
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY,
                                           width: rect.width - tail, height: rect.height),
                                cornerSize: CGSize(width: r, height: r))
        } else {
            path.addRoundedRect(in: CGRect(x: rect.minX + tail, y: rect.minY,
                                           width: rect.width - tail, height: rect.height),
                                cornerSize: CGSize(width: r, height: r))
        }
        return path
    }
}

// MARK: - Typing Indicator
struct TypingIndicatorView: View {
    let model: String
    @State private var phase = 0

    let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Theme.accentLight).frame(width: 28, height: 28)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.accent)
            }

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.accent.opacity(phase == i ? 1.0 : 0.3))
                        .frame(width: 7, height: 7)
                        .scaleEffect(phase == i ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.botBubble)
            .clipShape(BubbleShape(isUser: false))
            .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)

            Spacer(minLength: 50)
        }
        .padding(.vertical, 4)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Settings Sheet
struct SettingsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Model", selection: $state.selectedModel) {
                        ForEach(state.availableModels, id: \.self) { model in
                            HStack {
                                Image(systemName: "cpu")
                                    .foregroundColor(Theme.accent)
                                Text(model)
                            }
                            .tag(model)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Label("Language Model", systemImage: "cpu")
                }

                Section {
                    if state.documents.isEmpty {
                        Label("No documents uploaded yet", systemImage: "doc.badge.plus")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(state.documents, id: \.self) { doc in
                            HStack(spacing: 12) {
                                Image(systemName: state.selectedSources.contains(doc)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(state.selectedSources.contains(doc)
                                                     ? Theme.accent : .secondary)
                                    .font(.system(size: 18))
                                Text(doc)
                                    .lineLimit(1)
                                    .font(.system(size: 15))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    if state.selectedSources.contains(doc) {
                                        state.selectedSources.remove(doc)
                                    } else {
                                        state.selectedSources.insert(doc)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label("Filter by Document", systemImage: "doc.text.magnifyingglass")
                } footer: {
                    Text(state.selectedSources.isEmpty
                         ? "Querying all documents"
                         : "Querying \(state.selectedSources.count) selected document(s)")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Documents Sheet
struct DocumentsView: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = false
    @State private var isUploading = false
    @State private var showFilePicker = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var documentToDelete: String? = nil
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if state.documents.isEmpty {
                    emptyState
                } else {
                    documentList
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showFilePicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Theme.accentLight)
                            .clipShape(Circle())
                    }
                }
            }
            .overlay {
                if isUploading { uploadingOverlay }
            }
        }
        .fileImporter(isPresented: $showFilePicker,
                      allowedContentTypes: [UTType.pdf],
                      allowsMultipleSelection: false) { handleFilePick($0) }
        .alert("", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage) }
        .confirmationDialog("Delete \"\(documentToDelete ?? "")\"?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let doc = documentToDelete { deleteDocument(doc) }
            }
        } message: { Text("Removes the document and all its indexed data.") }
        .task { await reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Theme.accentLight).frame(width: 80, height: 80)
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(Theme.accent)
            }
            VStack(spacing: 6) {
                Text("No documents yet")
                    .font(.headline)
                Text("Tap + to upload a PDF.\nIn the simulator, drag a PDF\ninto the Files app first.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showFilePicker = true
            } label: {
                Label("Upload PDF", systemImage: "arrow.up.doc")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var documentList: some View {
        List {
            ForEach(state.documents, id: \.self) { doc in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accentLight)
                            .frame(width: 40, height: 40)
                        Image(systemName: "doc.fill")
                            .foregroundColor(Theme.accent)
                            .font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(doc)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1)
                        Text("PDF · Indexed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        documentToDelete = doc
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
            }
        }
        .listStyle(.insetGrouped)
    }

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.4).tint(Theme.accent)
                Text("Uploading & ingesting PDF...")
                    .font(.subheadline.weight(.medium))
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.15), radius: 20)
        }
    }

    private func reload() async {
        isLoading = true
        await state.loadDocuments()
        isLoading = false
    }

    private func handleFilePick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            Task {
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                isUploading = true
                do {
                    let msg = try await state.api.uploadDocument(fileURL: url)
                    alertMessage = "✅ \(msg)"
                    await state.loadDocuments()
                } catch {
                    alertMessage = "❌ Upload failed: \(error.localizedDescription)"
                }
                isUploading = false
                showAlert = true
            }
        case .failure(let error):
            alertMessage = "❌ \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func deleteDocument(_ filename: String) {
        Task {
            do {
                let msg = try await state.api.deleteDocument(filename: filename)
                alertMessage = "🗑️ \(msg)"
                state.selectedSources.remove(filename)
                await state.loadDocuments()
            } catch {
                alertMessage = "❌ Delete failed: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}

#Preview {
    ContentView()
}

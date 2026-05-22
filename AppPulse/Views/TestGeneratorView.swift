import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TestGeneratorView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedSuite: GeneratedSuite?
    @State private var searchText = ""
    @State private var showGenerator = false

    private var filteredSuites: [GeneratedSuite] {
        guard !searchText.isEmpty else { return store.generatedSuites }
        return store.generatedSuites.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if store.generatedSuites.isEmpty {
                    emptySidebar
                } else if filteredSuites.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28)).foregroundStyle(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedSuite) {
                        ForEach(filteredSuites) { suite in
                            SuiteRow(suite: suite)
                                .tag(suite)
                                .contextMenu {
                                    Button(role: .destructive) { deleteSuite(suite) } label: {
                                        Label("Delete Suite", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            let ids = Set(offsets.map { filteredSuites[$0].id })
                            store.generatedSuites.removeAll { ids.contains($0.id) }
                            if let sel = selectedSuite, ids.contains(sel.id) { selectedSuite = nil }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .searchable(text: $searchText, prompt: "Search suites")
            .navigationTitle("AI Tests")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button { showGenerator = true } label: {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                if let suite = selectedSuite {
                    ToolbarItem(placement: .automatic) {
                        Button(role: .destructive) { deleteSuite(suite) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } detail: {
            if let suite = selectedSuite {
                SuiteDetailView(suite: suite)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Select a suite or generate a new one")
                        .foregroundStyle(.secondary)
                    Button("Generate Test Cases") { showGenerator = true }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .sheet(isPresented: $showGenerator) {
            GeneratorSheet { suite in
                store.addGeneratedSuite(suite)
                selectedSuite = suite
                showGenerator = false
            }
        }
    }

    private var emptySidebar: some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No test suites yet")
                .font(.headline)
            Text("Describe a user story and let Gemini generate positive and negative test cases")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Generate Test Cases") { showGenerator = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteSuite(_ suite: GeneratedSuite) {
        store.generatedSuites.removeAll { $0.id == suite.id }
        if selectedSuite?.id == suite.id { selectedSuite = nil }
    }
}

// MARK: - Sidebar Row

struct SuiteRow: View {
    let suite: GeneratedSuite

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(suite.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Text(suite.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Label("\(suite.positiveTests.count)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(suite.negativeTests.count)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .font(.caption)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Suite Detail

struct SuiteDetailView: View {
    let suite: GeneratedSuite
    @State private var filter: TestCaseType? = nil
    @State private var showXCTestSheet = false

    var displayedCases: [GeneratedTestCase] {
        switch filter {
        case .positive: return suite.positiveTests
        case .negative: return suite.negativeTests
        case nil:       return suite.testCases
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Stats header
                HStack(spacing: 16) {
                    SuiteStatPill(count: suite.testCases.count, label: "Total",    color: .blue)
                    SuiteStatPill(count: suite.positiveTests.count, label: "Positive", color: .green)
                    SuiteStatPill(count: suite.negativeTests.count, label: "Negative", color: .red)
                    Spacer()
                    Button { showXCTestSheet = true } label: {
                        Label("XCTest Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    .buttonStyle(.bordered)
                    Button { exportCSV() } label: {
                        Label("Export CSV", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.bordered)
                }

                // User story
                VStack(alignment: .leading, spacing: 6) {
                    Text("User Story").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(suite.userStory)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !suite.scenarios.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scenarios").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(suite.scenarios)
                            .font(.subheadline)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Filter picker
                Picker("Filter", selection: $filter) {
                    Text("All (\(suite.testCases.count))").tag(Optional<TestCaseType>.none)
                    Text("Positive (\(suite.positiveTests.count))").tag(Optional<TestCaseType>.some(.positive))
                    Text("Negative (\(suite.negativeTests.count))").tag(Optional<TestCaseType>.some(.negative))
                }
                .pickerStyle(.segmented)

                // Test cases
                VStack(spacing: 10) {
                    ForEach(displayedCases) { tc in
                        TestCaseCard(testCase: tc)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(suite.name)
        .sheet(isPresented: $showXCTestSheet) {
            XCTestCodeSheet(suite: suite)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Test Cases"
        panel.nameFieldStringValue = "\(suite.name).csv"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        var rows: [String] = ["Type,ID,Title,Steps,Expected Result"]
        for (i, tc) in suite.testCases.enumerated() {
            let type = tc.type == .positive ? "Positive" : "Negative"
            let id   = "TC-\(String(format: "%03d", i + 1))"
            let steps = tc.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " | ")
            let row   = [type, id, tc.title, steps, tc.expectedResult]
                .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
                .joined(separator: ",")
            rows.append(row)
        }

        let csv = "\u{FEFF}" + rows.joined(separator: "\n")  // BOM for Excel UTF-8 detection
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Test Case Card

struct TestCaseCard: View {
    let testCase: GeneratedTestCase
    @State private var expanded = false

    private var accentColor: Color { testCase.type == .positive ? .green : .red }
    private var icon: String { testCase.type == .positive ? "checkmark.circle.fill" : "xmark.circle.fill" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(accentColor)
                        .font(.subheadline)
                    Text(testCase.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(expanded ? nil : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 12) {
                    // Steps
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Steps").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ForEach(Array(testCase.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(i + 1).")
                                    .font(.caption.monospacedDigit().weight(.semibold))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 18, alignment: .trailing)
                                Text(step)
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Expected result
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Expected Result").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(testCase.expectedResult)
                            .font(.subheadline)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(accentColor.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Placeholder Text Editor

private class PlaceholderTextNSView: NSTextView {
    var placeholder: String = ""

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let inset  = textContainerInset
        let hPad   = textContainer?.lineFragmentPadding ?? 5
        let drawRect = NSRect(
            x: inset.width + hPad,
            y: inset.height,
            width: max(0, bounds.width - (inset.width + hPad) * 2),
            height: max(0, bounds.height - inset.height * 2)
        )
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        (placeholder as NSString).draw(in: drawRect, withAttributes: attrs)
    }
}

struct PlaceholderTextEditor: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller   = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground       = false
        scrollView.borderType            = .noBorder

        let tv = PlaceholderTextNSView()
        tv.delegate                   = context.coordinator
        tv.isEditable                 = true
        tv.isSelectable               = true
        tv.isRichText                 = false
        tv.drawsBackground            = false
        tv.font                       = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        tv.autoresizingMask           = [.width]
        tv.isVerticallyResizable      = true
        tv.isHorizontallyResizable    = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)

        scrollView.documentView = tv
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let tv = scrollView.documentView as? PlaceholderTextNSView else { return }
        tv.placeholder = placeholder
        if tv.string != text { tv.string = text }
        tv.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PlaceholderTextEditor
        init(_ parent: PlaceholderTextEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }
    }
}

// MARK: - Generator Sheet

struct GeneratorSheet: View {
    let onGenerate: (GeneratedSuite) -> Void
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @AppStorage("geminiAPIKey")   private var apiKey = ""
    @AppStorage("geminiModel")    private var selectedModel = "gemini-2.5-flash"
    @State private var userStory = ""
    @State private var scenarios = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var showError = false

    private let models = [
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
    ]

    private let service = GeminiService()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Generate Test Cases")
                        .font(.title2.weight(.semibold))
                    Text("Powered by Google Gemini")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isGenerating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Generating…").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // API Key
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Gemini API Key").font(.subheadline.weight(.medium))
                            Spacer()
                            Link("Get a key →", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                                .font(.caption)
                        }
                        SecureField("Paste your API key here", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Model picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Model").font(.subheadline.weight(.medium))
                        HStack(spacing: 10) {
                            Picker("Model", selection: $selectedModel) {
                                ForEach(models, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 200)
                            Text("If you get a 404, try a different model")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    // User Story
                    VStack(alignment: .leading, spacing: 6) {
                        Text("User Story").font(.subheadline.weight(.medium))
                        PlaceholderTextEditor(
                            text: $userStory,
                            placeholder: "e.g. As a shopper, I want to add items to my cart so that I can purchase multiple products in one transaction."
                        )
                        .frame(height: 100)
                        .padding(4)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }

                    // Scenarios
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Scenarios / Acceptance Criteria").font(.subheadline.weight(.medium))
                            Text("(optional)").font(.caption).foregroundStyle(.secondary)
                        }
                        PlaceholderTextEditor(
                            text: $scenarios,
                            placeholder: "e.g. Given a logged-in user, when they tap Add to Cart, then the item count increases and the item appears in the cart."
                        )
                        .frame(height: 80)
                        .padding(4)
                        .background(Color.secondary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
                    }
                }
                .padding(24)
            }

            Divider()

            // Sticky footer buttons
            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button {
                    Task { await generate() }
                } label: {
                    Label(isGenerating ? "Generating…" : "Generate", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(userStory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 540, height: 500)
        .alert("Generation Failed", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func generate() async {
        isGenerating = true
        do {
            let suite = try await service.generateTestCases(
                userStory: userStory.trimmingCharacters(in: .whitespacesAndNewlines),
                scenarios: scenarios.trimmingCharacters(in: .whitespacesAndNewlines),
                apiKey: apiKey,
                model: selectedModel
            )
            NotificationService.shared.notifyGenerationComplete(suiteName: suite.name)
            await MainActor.run { onGenerate(suite) }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
        isGenerating = false
    }
}

// MARK: - Small components

struct SuiteStatPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)").font(.subheadline.weight(.bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    TestGeneratorView()
        .environmentObject(AppStore())
}

// MARK: - XCTest Code Sheet

private struct XCTestCodeSheet: View {
    let suite: GeneratedSuite
    @State private var copied = false
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("XCTest Code").font(.headline)
                    Text("Copy into a Swift test file in Xcode")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(xcTestCode, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)

                Button("Save .swift…") { saveSwiftFile() }
                    .buttonStyle(.bordered)

                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Divider()

            ScrollView {
                Text(xcTestCode)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(width: 680, height: 520)
    }

    private var xcTestCode: String {
        let className = suite.name
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined()
            .components(separatedBy: .punctuationCharacters)
            .joined()
            + "Tests"

        var lines: [String] = [
            "import XCTest",
            "",
            "// Generated by AppPulse · \(suite.date.formatted(date: .abbreviated, time: .shortened))",
            "// User Story: \(suite.userStory)",
            "",
            "final class \(className): XCTestCase {",
        ]

        if !suite.positiveTests.isEmpty {
            lines += ["", "    // MARK: - Positive Tests"]
            for (i, tc) in suite.positiveTests.enumerated() {
                let fnName = "testPositive\(String(format: "%02d", i + 1))"
                lines += ["", "    func \(fnName)() throws {"]
                lines += ["        // \(tc.title)"]
                for (si, step) in tc.steps.enumerated() {
                    lines += ["        // \(si + 1). \(step)"]
                }
                lines += ["        // Expected: \(tc.expectedResult)"]
                lines += ["        XCTFail(\"Not yet implemented\")"]
                lines += ["    }"]
            }
        }

        if !suite.negativeTests.isEmpty {
            lines += ["", "    // MARK: - Negative Tests"]
            for (i, tc) in suite.negativeTests.enumerated() {
                let fnName = "testNegative\(String(format: "%02d", i + 1))"
                lines += ["", "    func \(fnName)() throws {"]
                lines += ["        // \(tc.title)"]
                for (si, step) in tc.steps.enumerated() {
                    lines += ["        // \(si + 1). \(step)"]
                }
                lines += ["        // Expected: \(tc.expectedResult)"]
                lines += ["        XCTFail(\"Not yet implemented\")"]
                lines += ["    }"]
            }
        }

        lines += ["}", ""]
        return lines.joined(separator: "\n")
    }

    private func saveSwiftFile() {
        let panel = NSSavePanel()
        panel.title = "Save XCTest File"
        panel.nameFieldStringValue = "\(suite.name.replacingOccurrences(of: " ", with: ""))Tests.swift"
        panel.allowedContentTypes = [.swiftSource]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? xcTestCode.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }
}

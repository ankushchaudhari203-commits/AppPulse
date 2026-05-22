import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FunctionalTestsView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedRun: TestRun?
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isDragOver = false
    @State private var renameRun: TestRun?
    @State private var renameText = ""
    @State private var showRunProgress = false

    private var filteredRuns: [TestRun] {
        guard !searchText.isEmpty else { return store.testRuns }
        return store.testRuns.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            Group {
                if store.testRuns.isEmpty {
                    emptyState
                } else if filteredRuns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedRun) {
                        ForEach(filteredRuns) { run in
                            TestRunRow(run: run)
                                .tag(run)
                                .contextMenu {
                                    Button("Rename…") {
                                        renameRun  = run
                                        renameText = run.name
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        store.testRuns.removeAll { $0.id == run.id }
                                        if selectedRun?.id == run.id { selectedRun = nil }
                                    } label: {
                                        Label("Delete Run", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            let ids = Set(offsets.map { filteredRuns[$0].id })
                            store.testRuns.removeAll { ids.contains($0.id) }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .searchable(text: $searchText, prompt: "Search runs")
            .navigationTitle("Functional Tests")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        showRunProgress = true
                        Task {
                            do {
                                try await store.runXcodeTests()
                                selectedRun = store.testRuns.first
                            } catch {
                                errorMessage = error.localizedDescription
                                showError    = true
                                showRunProgress = false
                            }
                        }
                    } label: {
                        Label("Run Tests", systemImage: "play.fill")
                    }
                    .disabled(store.xcodeRunner.isRunning)
                    .help("Run xcodebuild test with the project configured in Settings → Tools")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        openPanel()
                    } label: {
                        Label("Import .xcresult", systemImage: "plus")
                    }
                }
                if let run = selectedRun {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            PDFExporter.export(title: run.name) {
                                PrintableTestRunView(run: run)
                            }
                        } label: {
                            Label("Export PDF", systemImage: "arrow.down.doc")
                        }
                        .keyboardShortcut("e", modifiers: .command)
                        .help("Export run as PDF")
                    }
                    ToolbarItem(placement: .automatic) {
                        Button(role: .destructive) {
                            store.testRuns.removeAll { $0.id == run.id }
                            selectedRun = nil
                        } label: {
                            Label("Delete Run", systemImage: "trash")
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
                handleDrop(providers)
            }
            .overlay {
                if isDragOver {
                    DropTargetOverlay()
                }
            }
        } detail: {
            if let run = selectedRun {
                TestRunDetailView(run: run)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("Select a test run")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert("Import Failed", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .sheet(isPresented: $showRunProgress) {
            RunProgressSheet(
                title: "Running Xcode Tests",
                icon: "testtube.2",
                phase: store.xcodeRunner.phase,
                outputLines: store.xcodeRunner.outputLines,
                isRunning: store.xcodeRunner.isRunning
            ) {
                store.xcodeRunner.cancel()
                showRunProgress = false
            }
            .onReceive(store.xcodeRunner.$isRunning) { running in
                if !running { showRunProgress = false }
            }
        }
        .alert("Rename Run", isPresented: Binding(
            get: { renameRun != nil },
            set: { if !$0 { renameRun = nil } }
        )) {
            TextField("Run name", text: $renameText)
            Button("Rename") {
                if let id = renameRun?.id, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.renameTestRun(id: id, name: renameText.trimmingCharacters(in: .whitespaces))
                }
                renameRun = nil
            }
            Button("Cancel", role: .cancel) { renameRun = nil }
        } message: {
            Text("Enter a new name for this test run.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No test runs")
                .font(.headline)
            Text("Run tests directly or import an .xcresult file")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button {
                    showRunProgress = true
                    Task {
                        do {
                            try await store.runXcodeTests()
                            selectedRun = store.testRuns.first
                        } catch {
                            errorMessage = error.localizedDescription
                            showError    = true
                            showRunProgress = false
                        }
                    }
                } label: {
                    Label("Run Tests", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.xcodeRunner.isRunning)

                Button("Import .xcresult") { openPanel() }
                    .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let data = item as? Data,
                      let url  = URL(dataRepresentation: data, relativeTo: nil),
                      url.pathExtension == "xcresult" else { return }
                DispatchQueue.main.async { importURL(url) }
            }
            handled = true
        }
        return handled
    }

    private func openPanel() {
        let panel = NSOpenPanel()
        panel.title = "Select .xcresult"
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        if let type = UTType(filenameExtension: "xcresult") {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK else { return }
        panel.urls.forEach { importURL($0) }
    }

    private func importURL(_ url: URL) {
        do {
            let run = try XCResultParser().parse(at: url)
            store.addTestRun(run)
            selectedRun = run
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Drop overlay

private struct DropTargetOverlay: View {
    var body: some View {
        let accent = Color.accentColor
        RoundedRectangle(cornerRadius: 10)
            .stroke(accent, lineWidth: 2)
            .background(accent.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 10)))
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(accent)
                    Text("Drop .xcresult here")
                        .font(.headline)
                        .foregroundStyle(accent)
                }
            }
            .padding(8)
            .allowsHitTesting(false)
    }
}

// MARK: - Test Run Row
struct TestRunRow: View {
    let run: TestRun

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(run.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Text(String(format: "%.0f%%", run.passRate))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(passRateColor(run.passRate))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(passRateColor(run.passRate).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .fixedSize()
            }
            Text(run.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Label("\(run.passedTests)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(run.failedTests)", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                if run.skippedTests > 0 {
                    Label("\(run.skippedTests)", systemImage: "minus.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail View
struct TestRunDetailView: View {
    let run: TestRun
    @EnvironmentObject var store: AppStore
    @State private var notesText: String

    init(run: TestRun) {
        self.run = run
        _notesText = State(initialValue: run.notes)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Pass rate ring
                ZStack {
                    Circle()
                        .stroke(passRateColor(run.passRate).opacity(0.15), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: run.passRate / 100)
                        .stroke(passRateColor(run.passRate),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: run.passRate)
                }
                .frame(width: 130, height: 130)
                .frame(maxWidth: .infinity)
                .overlay {
                    VStack(spacing: 2) {
                        Text(String(format: "%.0f%%", run.passRate))
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(passRateColor(run.passRate))
                        Text("Pass Rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Stat badges
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    StatBadge(label: "Total",   value: "\(run.totalTests)",   color: .blue)
                    StatBadge(label: "Passed",  value: "\(run.passedTests)",  color: .green)
                    StatBadge(label: "Failed",  value: "\(run.failedTests)",  color: .red)
                    StatBadge(label: "Skipped", value: "\(run.skippedTests)", color: .secondary)
                }

                // Meta
                VStack(alignment: .leading, spacing: 10) {
                    DetailInfoRow(label: "Date",     value: run.date.formatted(date: .complete, time: .shortened))
                    DetailInfoRow(label: "Duration", value: durationLabel)
                    DetailInfoRow(label: "Status",   value: run.status.rawValue.capitalized)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.07), lineWidth: 1))
                .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
                if !run.testCases.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Test Cases")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(run.testCases.count) total")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Divider()
                        ForEach(run.testCases) { tc in
                            TestCaseRow(testCase: tc)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // Notes
                NotesCard(text: $notesText)
                    .onChange(of: notesText) { _, value in
                        store.updateTestRunNotes(id: run.id, notes: value)
                    }
            }
            .padding(24)
        }
        .navigationTitle(run.name)
    }

    private var durationLabel: String {
        let m = Int(run.duration) / 60
        let s = Int(run.duration) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}

// MARK: - Sub-components
struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct DetailInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Test Case Row
struct TestCaseRow: View {
    let testCase: TestCase

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
                .frame(width: 16)
            Text(testCase.name)
                .font(.system(.subheadline, design: .monospaced))
                .lineLimit(1)
            Spacer()
            if testCase.duration > 0 {
                Text(durationLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 1)
    }

    private var icon: String {
        switch testCase.status {
        case .passed:  return "checkmark.circle.fill"
        case .failed:  return "xmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        }
    }

    private var color: Color {
        switch testCase.status {
        case .passed:  return .green
        case .failed:  return .red
        case .skipped: return .secondary
        }
    }

    private var durationLabel: String {
        testCase.duration < 1
            ? String(format: "%.0f ms", testCase.duration * 1000)
            : String(format: "%.2f s", testCase.duration)
    }
}

// MARK: - Shared helper
private func passRateColor(_ rate: Double) -> Color {
    switch rate {
    case 90...: return .green
    case 70..<90: return .orange
    default: return .red
    }
}

// MARK: - Notes Card (shared)
struct NotesCard: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Notes")
                    .font(.subheadline.weight(.semibold))
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Add notes about this run — e.g. branch, deploy version, known issues…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 9)
                }
                TextEditor(text: $text)
                    .font(.subheadline)
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
            }
            .padding(6)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    FunctionalTestsView()
        .environmentObject(AppStore())
}

// MARK: - Shared run progress sheet

struct RunProgressSheet: View {
    let title: String
    let icon: String
    let phase: String
    let outputLines: [String]
    let isRunning: Bool
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(Color.accentColor)
                }
                Text(title).font(.headline)
                Spacer()
                Text(phase)
                    .font(.subheadline)
                    .foregroundStyle(phaseColor)
            }
            .padding()

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(outputLines.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(lineColor(line))
                                .textSelection(.enabled)
                                .id(idx)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: outputLines.count) { _, _ in
                    if let last = outputLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            Divider()

            HStack {
                if !isRunning {
                    Text("Done").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(isRunning ? "Cancel" : "Close", role: isRunning ? .cancel : nil) {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
        }
        .frame(width: 620, height: 420)
    }

    private var phaseColor: Color {
        if phase.contains("✓") { return .green }
        if phase.contains("failure") || phase.contains("Cancelled") { return .orange }
        return .secondary
    }

    private func lineColor(_ line: String) -> Color {
        if line.contains("error:") || line.contains("FAILED") || line.contains("** TEST FAILED") { return .red }
        if line.contains("warning:") { return .orange }
        if line.contains("** TEST SUCCEEDED") || line.contains("BUILD SUCCEEDED") { return .green }
        return .primary
    }
}

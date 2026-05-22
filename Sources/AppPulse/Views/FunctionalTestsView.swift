import SwiftUI

struct FunctionalTestsView: View {
    @StateObject private var parser = XCResultParser.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Functional Tests")
                            .font(.largeTitle).bold()
                        Text("How well does the app work?")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        parser.selectResultFile()
                    } label: {
                        Label("Load .xcresult", systemImage: "folder")
                    }
                    Button {
                        Task { await parser.runTests() }
                    } label: {
                        Label("Run Tests", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if parser.isLoading {
                    ProgressView("Running tests...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if !parser.testSuites.isEmpty {
                    ForEach(parser.testSuites) { suite in
                        TestSuiteRow(suite: suite)
                    }
                } else if !parser.isLoading {
                    EmptyStateView(
                        icon: "checkmark.seal",
                        title: "No results yet",
                        message: "Run your XCUITests or load an existing .xcresult file"
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle("Functional Tests")
    }
}

struct TestSuiteRow: View {
    let suite: TestSuite
    @State private var expanded = true

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    HStack {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .foregroundStyle(.secondary)
                        Text(suite.name).font(.headline)
                        Spacer()
                        Text("\(suite.passed)/\(suite.total) passed")
                            .foregroundStyle(suite.allPassed ? .green : .red)
                            .font(.subheadline)
                        Circle()
                            .fill(suite.allPassed ? Color.green : .red)
                            .frame(width: 10, height: 10)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if expanded {
                    Divider()
                    ForEach(suite.cases) { tc in
                        TestCaseRow(testCase: tc)
                        Divider()
                    }
                }
            }
            .padding(4)
        }
    }
}

struct TestCaseRow: View {
    let testCase: TestCase

    var body: some View {
        HStack {
            Image(systemName: testCase.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(testCase.passed ? .green : .red)
            Text(testCase.name)
                .font(.subheadline)
            Spacer()
            Text(testCase.duration)
                .foregroundStyle(.secondary)
                .font(.caption)
            if !testCase.passed {
                Button("See Why") {
                    // show failure detail
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

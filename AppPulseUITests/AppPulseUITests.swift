import XCTest

final class AppPulseUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testTabNavigation() throws {
        // Wait for splash screen to finish — query any element type with that label
        let overviewTab = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Overview'")).firstMatch
        XCTAssertTrue(overviewTab.waitForExistence(timeout: 15), "Overview tab should appear after splash")

        overviewTab.click()
        Thread.sleep(forTimeInterval: 2)

        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Functional'")).firstMatch.click()
        Thread.sleep(forTimeInterval: 2)

        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Performance'")).firstMatch.click()
        Thread.sleep(forTimeInterval: 2)

        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'API Health'")).firstMatch.click()
        Thread.sleep(forTimeInterval: 2)

        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'AI Tests'")).firstMatch.click()
        Thread.sleep(forTimeInterval: 2)

        app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Reports'")).firstMatch.click()
        Thread.sleep(forTimeInterval: 2)
    }
}

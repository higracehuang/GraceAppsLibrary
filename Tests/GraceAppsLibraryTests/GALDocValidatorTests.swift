//
//  GALDocValidatorTests.swift
//  GraceAppsLibraryTests
//
//  Created by Grace Huang on 11/17/26.
//

import XCTest
@testable import GraceAppsLibrary

final class GALDocValidatorTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }

    private enum TestAdTrigger: String, CaseIterable {
        case fastCompleted = "fast_completed"
        case startFast = "start_fast"
    }

    private enum TestPaywallTrigger: String, CaseIterable {
        case settingsUpgrade = "settings_upgrade"
    }

    func testValidate_TemplatePasses() throws {
        let templateURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("UX_MOMENTS_TEMPLATE.md")

        XCTAssertTrue(FileManager.default.fileExists(atPath: templateURL.path), "Template should exist in repository root")
        
        let isValid = try GALDocValidator.validate(
            docURL: templateURL,
            adTriggers: ["fast_completed"],
            paywallTriggers: ["settings_upgrade"]
        )
        XCTAssertTrue(isValid)
    }

    func testValidate_FileNotFound_ThrowsError() {
        let fakeURL = tempDirectory.appendingPathComponent("NON_EXISTENT.md")
        XCTAssertThrowsError(try GALDocValidator.validate(docURL: fakeURL)) { error in
            guard case GALDocValidationError.fileNotFound = error else {
                XCTFail("Expected fileNotFound, got \(error)")
                return
            }
        }
    }

    func testValidate_MissingSection_ThrowsError() throws {
        let testDoc = tempDirectory.appendingPathComponent("UX_MOMENTS.md")
        let partialContent = """
        # Test App — UX Flow Catalog
        ## 1. Architectural Overview
        Missing everything else.
        """
        try partialContent.write(to: testDoc, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GALDocValidator.validate(docURL: testDoc)) { error in
            guard case GALDocValidationError.missingSection(let name) = error else {
                XCTFail("Expected missingSection, got \(error)")
                return
            }
            XCTAssertEqual(name, "Paywall")
        }
    }

    func testValidate_MissingTrigger_ThrowsError() throws {
        let testDoc = tempDirectory.appendingPathComponent("UX_MOMENTS.md")
        let validSectionsContent = """
        # Test App
        ## 1. Architectural Overview
        ## 2. Paywall Moments
        settings_upgrade
        ## 3. Rating & Review
        ## 4. Full-Screen Ad Moments
        start_fast
        ## 5. Flow Orchestration Matrix
        ## 6. QA Verification Scenarios
        """
        try validSectionsContent.write(to: testDoc, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try GALDocValidator.validate(
                docURL: testDoc,
                adTriggers: TestAdTrigger.allCases,
                paywallTriggers: TestPaywallTrigger.allCases
            )
        ) { error in
            guard case GALDocValidationError.missingAdTrigger(let trigger) = error else {
                XCTFail("Expected missingAdTrigger, got \(error)")
                return
            }
            XCTAssertEqual(trigger, "fast_completed")
        }
    }

    func testLocateUXMoments_FindsInSubdirectories() throws {
        let projectInfoDir = tempDirectory.appendingPathComponent("ProjectInfo")
        try FileManager.default.createDirectory(at: projectInfoDir, withIntermediateDirectories: true)
        let subDoc = projectInfoDir.appendingPathComponent("UX_MOMENTS.md")
        try "# Test".write(to: subDoc, atomically: true, encoding: .utf8)

        let found = GALDocValidator.locateUXMoments(in: tempDirectory)
        XCTAssertEqual(found?.standardizedFileURL, subDoc.standardizedFileURL)
    }

    func testValidateUITestCoverage_Success() throws {
        let testDoc = tempDirectory.appendingPathComponent("UX_MOMENTS.md")
        let docContent = """
        # Test App
        ## 5. Flow Orchestration Matrix
        | Action | Verification |
        |---|---|
        | Fast Ended | `testMatrixRow1_DirectIntentPaywall` |
        | Fast Ad | `testMatrixRow3_FastCompleted_MockAd` |
        """
        try docContent.write(to: testDoc, atomically: true, encoding: .utf8)

        let uiTestFile = tempDirectory.appendingPathComponent("UXMomentsUITests.swift")
        let testFileContent = """
        import XCTest
        final class UXMomentsUITests: XCTestCase {
            func testMatrixRow1_DirectIntentPaywall() throws {}
            func testMatrixRow3_FastCompleted_MockAd() throws {}
        }
        """
        try testFileContent.write(to: uiTestFile, atomically: true, encoding: .utf8)

        let isValid = try GALDocValidator.validateUITestCoverage(docURL: testDoc, uiTestFileURL: uiTestFile)
        XCTAssertTrue(isValid)
    }

    func testValidateUITestCoverage_MissingTestCase_Throws() throws {
        let testDoc = tempDirectory.appendingPathComponent("UX_MOMENTS.md")
        let docContent = """
        # Test App
        | Action | Verification |
        |---|---|
        | Fast Ended | `testMatrixRow1_DirectIntentPaywall` |
        | Fast Ad | `testMatrixRow3_FastCompleted_MockAd` |
        """
        try docContent.write(to: testDoc, atomically: true, encoding: .utf8)

        let uiTestFile = tempDirectory.appendingPathComponent("UXMomentsUITests.swift")
        let incompleteContent = """
        import XCTest
        final class UXMomentsUITests: XCTestCase {
            func testMatrixRow1_DirectIntentPaywall() throws {}
        }
        """
        try incompleteContent.write(to: uiTestFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try GALDocValidator.validateUITestCoverage(docURL: testDoc, uiTestFileURL: uiTestFile)
        ) { error in
            guard case GALDocValidationError.missingUITestCase(let method, _) = error else {
                XCTFail("Expected missingUITestCase, got \(error)")
                return
            }
            XCTAssertEqual(method, "testMatrixRow3_FastCompleted_MockAd")
        }
    }

    func testValidateUITestCoverage_MissingFile_Throws() {
        let missingFile = tempDirectory.appendingPathComponent("NonExistentUITests.swift")
        XCTAssertThrowsError(
            try GALDocValidator.validateUITestCoverage(uiTestFileURL: missingFile)
        ) { error in
            guard case GALDocValidationError.missingUITestFile = error else {
                XCTFail("Expected missingUITestFile, got \(error)")
                return
            }
        }
    }

    func testLocateUXMomentsUITests_FindsFile() throws {
        let subDir = tempDirectory.appendingPathComponent("AppUITests")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        let uiTestFile = subDir.appendingPathComponent("UXMomentsUITests.swift")
        try "// tests".write(to: uiTestFile, atomically: true, encoding: .utf8)

        let found = GALDocValidator.locateUXMomentsUITests(in: tempDirectory)
        XCTAssertEqual(found?.standardizedFileURL, uiTestFile.standardizedFileURL)
    }
}

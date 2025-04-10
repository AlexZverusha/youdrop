//
//  YouDropTests.swift
//  YouDropTests
//
//  Created by Alex on 4/3/25.
//

import XCTest
import SwiftUI
@testable import YouDrop


final class YouDropTests: XCTestCase {

    func testInitialStatusMessageIsLocalized() {
        let view = ContentView()
        let mirror = Mirror(reflecting: view)
        if let statusMessage = mirror.descendant("_statusMessage") as? State<String> {
            XCTAssertEqual(statusMessage.wrappedValue, NSLocalizedString("input.prompt", comment: ""))
        } else {
            XCTFail("Wrong status ContentView")
        }
    }

    func testDefaultFormatIsMP4() {
        let view = ContentView()
        let mirror = Mirror(reflecting: view)
        if let format = mirror.descendant("_selectedFormat") as? State<Format> {
            XCTAssertEqual(format.wrappedValue, .mp4)
        } else {
            XCTFail("Wrong format ContentView")
        }
    }

    func testDefaultQualityIsBest() {
        let view = ContentView()
        let mirror = Mirror(reflecting: view)
        if let quality = mirror.descendant("_selectedQuality") as? State<String> {
            XCTAssertEqual(quality.wrappedValue, "best")
        } else {
            XCTFail("Wrong selected Quality ContentView")
        }
    }

    func testLocalizedStringsExist() {
        let keys = [
            "input.prompt",
            "label.video.quality",
            "button.paste.clipboard",
            "button.download",
            "label.saved.as",
            "button.show.in.finder",
            "status.downloading",
            "status.saved",
            "error.ytdlp.notfound.status",
            "error.ytdlp.notfound.log",
            "log.ytdlp.found",
            "log.command",
            "error.tempfile.notfound.status",
            "error.tempfile.notfound.log",
            "error.file.missing.status",
            "error.file.missing.log",
            "error.tempdir.failed",
            "error.run.failed.status"
        ]

        for key in keys {
            let localized = NSLocalizedString(key, tableName: nil, bundle: .main, value: "", comment: "")
            XCTAssertFalse(localized == key || localized.isEmpty, "Should be translated: \(key)")
        }
    }
}

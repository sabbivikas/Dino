//
//  ProfileDetailsDirtyTests.swift
//  DinoTests
//
//  The save button's dirty detection after the immediate-persist fix:
//  name/bio changes enable it; the photo deliberately can't (it persists
//  on pick, so the signature has no photo input at all).
//

import XCTest
@testable import Dino

final class ProfileDetailsDirtyTests: XCTestCase {

    func testCleanStateHasNoChanges() {
        XCTAssertFalse(ProfileDetailsDirty.hasChanges(name: "sylvia", originalName: "sylvia",
                                                      bio: "hi", originalBio: "hi"))
    }

    func testNameChangeIsDirty() {
        XCTAssertTrue(ProfileDetailsDirty.hasChanges(name: "sylvia r", originalName: "sylvia",
                                                     bio: "hi", originalBio: "hi"))
    }

    func testBioChangeIsDirty() {
        XCTAssertTrue(ProfileDetailsDirty.hasChanges(name: "sylvia", originalName: "sylvia",
                                                     bio: "hello", originalBio: "hi"))
    }

    func testPhotoCannotDirtyTheSaveButton() {
        // the function takes no photo input — this test documents the
        // immediate-persist contract at the type level: identical text ⇒
        // clean, regardless of any photo activity
        XCTAssertFalse(ProfileDetailsDirty.hasChanges(name: "", originalName: "",
                                                      bio: "", originalBio: ""))
    }
}

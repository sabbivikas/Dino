//
//  JournalPhotoStore.swift
//  Dino
//
//  Cloud durability for journal photos. Historically photos lived ONLY in the
//  local Documents directory (and are excluded from device backups), so any
//  reinstall or device change lost them while the Firestore docs kept dangling
//  photoFileName references. This store:
//   • uploads every saved photo to Storage at users/{uid}/journalPhotos/{name}
//     — fully async, NEVER blocking or delaying the journal save
//   • backfills uploads for any local photos that predate the feature
//   • downloads on demand when a referenced file is missing locally, so old
//     photos come back on a fresh install
//   • distinguishes "still fetching" from "permanently missing" for the UI
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseStorage

@MainActor
enum JournalPhotoStore {

    enum PhotoState: Equatable {
        case loaded(UIImage)
        case fetching
        case missing        // not local, not in the cloud — genuinely gone
    }

    private static let uploadedKey = "dino.journalPhotos.uploaded"
    private static var inFlight = Set<String>()

    private static var uploadedNames: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: uploadedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: uploadedKey) }
    }

    private static func localURL(_ name: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }

    private static func storageRef(_ name: String, uid: String) -> StorageReference {
        Storage.storage().reference().child("users/\(uid)/journalPhotos/\(name)")
    }

    // MARK: - Upload (fire-and-forget)

    /// Upload one photo if it exists locally and hasn't been uploaded yet.
    /// Safe to call repeatedly; failures retry on the next backfill pass.
    static func uploadIfNeeded(_ name: String?) {
        guard let name, !name.isEmpty,
              !uploadedNames.contains(name), !inFlight.contains(name),
              let uid = Auth.auth().currentUser?.uid,
              let data = try? Data(contentsOf: localURL(name)) else { return }
        inFlight.insert(name)
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"
        storageRef(name, uid: uid).putData(data, metadata: meta) { _, error in
            Task { @MainActor in
                inFlight.remove(name)
                if error == nil {
                    uploadedNames.insert(name)
                } else {
                    #if DEBUG
                    print("🖼️ journal photo upload failed: \(error?.localizedDescription ?? "")")
                    #endif
                }
            }
        }
    }

    /// Walk all entries and upload any local photos the cloud doesn't have yet
    /// (covers photos created before this feature shipped). Cheap when done.
    static func backfillUploads(entries: [JournalEntry]) {
        for entry in entries {
            uploadIfNeeded(entry.photoFileName)
        }
    }

    // MARK: - Load (local first, then cloud)

    /// Resolve a photo: local file → loaded; else try Storage (writing the file
    /// back locally with the same protections); else missing.
    static func fetchPhoto(_ name: String) async -> PhotoState {
        let url = localURL(name)
        if let img = UIImage(contentsOfFile: url.path) { return .loaded(img) }
        guard let uid = Auth.auth().currentUser?.uid else { return .missing }
        do {
            let data = try await storageRef(name, uid: uid).data(maxSize: 6 * 1024 * 1024)
            guard let img = UIImage(data: data) else { return .missing }
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path)
            var mutableURL = url
            var vals = URLResourceValues()
            vals.isExcludedFromBackup = true
            try? mutableURL.setResourceValues(vals)
            uploadedNames.insert(name)   // it's in the cloud by definition
            return .loaded(img)
        } catch {
            return .missing
        }
    }
}

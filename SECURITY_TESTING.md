# Security testing (Dino)

This document complements Cursor **Bugbot** / **Security Review** agents (see [.cursor/BUGBOT.md](.cursor/BUGBOT.md)). Those agents review **source and diffs**. Use the items below for **dependency hygiene**, **Firestore policy verification**, and **mobile/runtime** assessment.

## Dependency and supply chain

- **GitHub Dependabot** is configured in [.github/dependabot.yml](.github/dependabot.yml) for GitHub Actions, Ruby/Bundler (Fastlane), and npm packages under `firebase-rules-tests/`.
- Swift Package Manager pins live in [Dino.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved](Dino.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved). Periodically resolve packages in Xcode and review release notes for Firebase / GoogleSignIn / AppAuth.

## Firestore rules (automated)

- Rules file: [firestore.rules](firestore.rules).
- Unit tests: [firebase-rules-tests/](firebase-rules-tests/) using `@firebase/rules-unit-testing` and the Firestore emulator.
- CI: [.github/workflows/firestore-rules.yml](.github/workflows/firestore-rules.yml) runs on pushes and PRs that touch rules or test files.

### Run tests locally

1. Install a **Java 17+** runtime (required by the Firestore emulator).
2. Install Node 20+.
3. From the repo root:

```bash
cd firebase-rules-tests
npm install
npm test
```

## Firebase Emulator Suite (manual exploratory testing)

Use the [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite) to exercise auth + Firestore clients against local rules without touching production. Helpful for validating new collections or sync paths before deploy.

## Mobile / runtime assessment (not covered by Cursor agents)

Cursor agents do **not** replace dynamic testing of the installed app. When the threat model requires it, consider:

- **OWASP MASVS** as a checklist for storage, crypto, network, and platform interaction.
- **Proxy tooling** (e.g. Charles, mitmproxy) for TLS and API behavior review in debug builds.
- **Jailbreak / instrumentation** only where legally and contractually allowed, for advanced assessments.

## Xcode sanitizers

Use Address Sanitizer and Thread Sanitizer during development builds to catch memory and concurrency defects (defense-in-depth; distinct from auth/rule bugs).

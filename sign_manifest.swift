#!/usr/bin/env swift
// sign_manifest.swift: Ed25519-sign the EXACT bytes of manifest.json.
//
// Usage (in the centinal-lists workflow, after refresh.sh writes manifest.json):
//   MANIFEST_SIGNING_KEY="${{ secrets.MANIFEST_SIGNING_KEY }}" swift sign_manifest.swift manifest.json
//
// Writes `<manifest>.sig` next to the manifest: the base64 Ed25519 signature over
// the manifest file's bytes exactly as served, plus a trailing newline. The app
// (ManifestVerifier.verify(manifestBytes:detachedSignature:)) verifies those
// same bytes against the public key compiled into the binary, so any edit to
// manifest.json after signing (even whitespace) is rejected.
//
// The private key is the base64 of the 32-byte raw Curve25519 signing key, read
// ONLY from the MANIFEST_SIGNING_KEY environment variable. It is never printed.
// If EXPECTED_PUBLIC_KEY is set, the script refuses to sign unless the key's
// public half matches it (catches a rotated or mistyped secret before it ships
// a manifest every client would reject).
//
// Requires macOS (CryptoKit). Exit codes: 0 signed, 1 error, 2 usage.

import Foundation
import CryptoKit

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data("sign_manifest: \(message)\n".utf8))
    exit(code)
}

let args = CommandLine.arguments
guard args.count == 2 else { fail("usage: sign_manifest.swift <manifest.json>", code: 2) }
let manifestPath = args[1]

guard let keyB64 = ProcessInfo.processInfo.environment["MANIFEST_SIGNING_KEY"]?
        .trimmingCharacters(in: .whitespacesAndNewlines), !keyB64.isEmpty else {
    fail("MANIFEST_SIGNING_KEY is not set")
}
guard let raw = Data(base64Encoded: keyB64),
      let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
    fail("MANIFEST_SIGNING_KEY is not a base64 32-byte Ed25519 private key")
}

let publicB64 = key.publicKey.rawRepresentation.base64EncodedString()
if let expected = ProcessInfo.processInfo.environment["EXPECTED_PUBLIC_KEY"]?
    .trimmingCharacters(in: .whitespacesAndNewlines), !expected.isEmpty, expected != publicB64 {
    fail("signing key does not match EXPECTED_PUBLIC_KEY; refusing to sign")
}

guard let bytes = FileManager.default.contents(atPath: manifestPath), !bytes.isEmpty else {
    fail("cannot read \(manifestPath)")
}
// Sanity: it must be JSON, so we never sign an error page.
guard (try? JSONSerialization.jsonObject(with: bytes)) != nil else {
    fail("\(manifestPath) is not valid JSON")
}

let signature: Data
do {
    signature = try key.signature(for: bytes)
} catch {
    fail("signing failed: \(error)")
}
guard key.publicKey.isValidSignature(signature, for: bytes) else {
    fail("self-verification failed")
}

let sigPath = manifestPath + ".sig"
let sigText = signature.base64EncodedString() + "\n"
do {
    try sigText.write(toFile: sigPath, atomically: true, encoding: .utf8)
} catch {
    fail("cannot write \(sigPath): \(error)")
}
print("sign_manifest: wrote \(sigPath) (public key \(publicB64))")

// swift-tools-version: 6.0
import PackageDescription

// Minimal, SELF-CONTAINED package for the public `centinal-lists` repo. It ships
// ONLY the build-time converter (`blockgen`) + AdGuard's SafariConverterLib — no
// proprietary BlockerCore source. blockgen turns an Adblock-Plus filter list into
// Safari content-blocker JSON; the repo's refresh.sh packs the outputs and writes
// the signed manifest. SafariConverterLib is GPL-3.0 CODE used only at build time
// (never shipped), and the compiled lists this repo publishes are GPL-3.0 data.
let package = Package(
    name: "blockgen",
    dependencies: [
        // Pin EXACTLY (not `from:`) so the app repo's bundled baseline and this
        // repo's OTA output are byte-reproducible — a version drift would change
        // rule counts and break the app's Transparency numbers.
        .package(url: "https://github.com/AdguardTeam/SafariConverterLib", exact: "4.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "blockgen",
            dependencies: [
                .product(name: "ContentBlockerConverter", package: "SafariConverterLib"),
            ]
        ),
    ]
)

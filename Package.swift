// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Paperlike",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure Foundation. No AppKit, so it is unit-testable anywhere.
        .target(name: "PaperlikeCore"),
        .executableTarget(
            name: "Paperlike",
            dependencies: ["PaperlikeCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(name: "PaperlikeCoreTests", dependencies: ["PaperlikeCore"]),
    ]
)

// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SQLite",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SQLite",
            targets: ["SQLite"]
        ),
        .executable(
            name: "t_sqlite",
            targets: ["SQLiteTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Errors.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
    ],
    targets: [
        // a thin wrapper over the system libsqlite3
        .target(
            name: "SQLite",
            dependencies: [
                .product(name: "Errors", package: "Errors"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),

        .executableTarget(
            name: "SQLiteTests",
            dependencies: [
                "SQLite",
                .product(name: "Errors", package: "Errors"),
                .product(name: "Testing", package: "Testing"),
            ],
            path: "Testing/SQLiteTests"
        ),
    ]
)

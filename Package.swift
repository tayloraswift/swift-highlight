// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "swift-highlight",
    products: 
    [
        .library(name: "Highlight", targets: ["Highlight"]),
    ],
    dependencies: 
    [
    ],
    targets: 
    [
        .target(name: "Highlight", path: "sources/highlight"),
    ]
)

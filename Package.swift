// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "swift-highlight",
    products: 
    [
        .library(name: "Notebook", targets: ["Notebook"]),
    ],
    dependencies: 
    [
    ],
    targets: 
    [
        .target(name: "Notebook", path: "sources/notebook"),
    ]
)

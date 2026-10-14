// swift-tools-version:6.0
// Linux 上编 SideStore 主程序用的 SwiftPM 外壳（tools/linux-build.sh 用；Mac / CI 仍走 AltStore.xcodeproj）。
// 只编 SideStore 这一个可执行文件，小组件、SideBackup.ipa 和 Xcode 专属资源取自参考包（见 linux-build.sh）。
// Sources/SideStore/ 下是指回仓库源码目录的软链，由 linux-build.sh 生成。依赖版本跟 Xcode 的 Package.resolved 一致。
import Foundation
import PackageDescription

let pkg = Context.packageDirectory          // build/linux/pkg
let repo = pkg + "/../../.."
let src = pkg + "/Sources/SideStore"

// 同步文件夹里除 .swift 外都是资源（Linux 编不了，取自参考包）；另去掉 pbxproj 里对 SideStore 目标的成员例外
let membershipExceptions = [
    "SideStore/Tests", "SideStore/Utils/misc/xcmapping-diff-reporter",
    "AltStore/Info.plist", "AltStore/Resources/ReleaseEntitlements.plist",
]
func nonSwift(_ dir: String) -> [String] {
    let e = FileManager.default.enumerator(atPath: src + "/" + dir + "/")!
    var out: [String] = []
    while let p = e.nextObject() as? String {
        let full = src + "/" + dir + "/" + p
        var isDir: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: full, isDirectory: &isDir)
        if isDir.boolValue {
            // .xcassets / .xcdatamodeld 之类整包排除，不往里走
            if p.split(separator: "/").last!.contains(".") { out.append(dir + "/" + p); e.skipDescendants() }
        } else if !p.hasSuffix(".swift") {
            out.append(dir + "/" + p)
        }
    }
    return out
}
let excluded = membershipExceptions + ["Shared", "AltStore", "SideStore"].flatMap(nonSwift)

// 链接时 clang 只拿到 --sysroot，读不到 SDKSettings，LC_BUILD_VERSION 的 sdk 会写成 18.0，所以显式给 -isysroot
let sdkLink: [String] = Context.environment["SS_IOS_SDK"].map { ["-Xclang-linker", "-isysroot", "-Xclang-linker", $0] } ?? []

// deps/ 里是清单按「宿主」判断平台的依赖（宿主是 Linux 就不用 xcframework、改用宿主的库），linux-build.sh
// 检出跟 Package.resolved 同一提交并把判断改成 iOS 的结果；根包里的本地包会顶替同名的远程依赖
let patchedDeps = ((try? FileManager.default.contentsOfDirectory(atPath: pkg + "/deps")) ?? []).sorted()
    .map { Package.Dependency.package(path: "deps/" + $0) }

let package = Package(
    name: "SideStoreLinux",
    platforms: [.iOS(.v15)],
    dependencies: patchedDeps + [
        .package(path: repo + "/Dependencies/minimuxer"),
        .package(path: repo + "/Dependencies/SideSign"),
        .package(url: "https://github.com/bmoliveira/MarkdownKit.git", exact: "1.7.3"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", revision: "e0c7eebc5a4465a3c4680764f26b7a61f567cdaf"),
        .package(url: "https://github.com/kean/Nuke", exact: "13.2.0"),
        .package(url: "https://github.com/daltoniam/Starscream", exact: "4.0.8"),
        .package(url: "https://github.com/SwiftPackageIndex/SemanticVersion", exact: "0.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "SideStore",
            dependencies: [
                .product(name: "Minimuxer", package: "minimuxer"),
                .product(name: "SideSign", package: "SideSign"),
                "MarkdownKit", "KeychainAccess", "Nuke", "Starscream", "SemanticVersion",
            ],
            exclude: excluded,
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("BareSlashRegexLiterals"),  // Xcode 默认开，SwiftPM 默认关
                .define("BETA"),                                    // SWIFT_ACTIVE_COMPILATION_CONDITIONS
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-Osize"], .when(configuration: .release)),
            ],
            linkerSettings: [.unsafeFlags(sdkLink + [
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path/Frameworks",
                "-Xlinker", "-w",
                "-Xlinker", "-no_exported_symbols",  // LD_EXPORT_SYMBOLS = NO
            ])]
        ),
    ]
)

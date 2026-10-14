import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if false  // linux: 同 Xcode 构建，见 mac-codegen.sh
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

    /// The "Background" asset catalog color resource.
    static let background = ColorResource(name: "Background", bundle: resourceBundle)

    /// The "BlurTint" asset catalog color resource.
    static let blurTint = ColorResource(name: "BlurTint", bundle: resourceBundle)

    /// The "ClipPrimary" asset catalog color resource.
    static let clipPrimary = ColorResource(name: "ClipPrimary", bundle: resourceBundle)

    /// The "DarkButtonBackground" asset catalog color resource.
    static let darkButtonBackground = ColorResource(name: "DarkButtonBackground", bundle: resourceBundle)

    /// The "DeltaPrimary" asset catalog color resource.
    static let deltaPrimary = ColorResource(name: "DeltaPrimary", bundle: resourceBundle)

    /// The "GradientBottom" asset catalog color resource.
    static let gradientBottom = ColorResource(name: "GradientBottom", bundle: resourceBundle)

    /// The "GradientTop" asset catalog color resource.
    static let gradientTop = ColorResource(name: "GradientTop", bundle: resourceBundle)

    /// The "Primary" asset catalog color resource.
    static let primary = ColorResource(name: "Primary", bundle: resourceBundle)

    /// The "RefreshGreen" asset catalog color resource.
    static let refreshGreen = ColorResource(name: "RefreshGreen", bundle: resourceBundle)

    /// The "RefreshOrange" asset catalog color resource.
    static let refreshOrange = ColorResource(name: "RefreshOrange", bundle: resourceBundle)

    /// The "RefreshRed" asset catalog color resource.
    static let refreshRed = ColorResource(name: "RefreshRed", bundle: resourceBundle)

    /// The "RefreshYellow" asset catalog color resource.
    static let refreshYellow = ColorResource(name: "RefreshYellow", bundle: resourceBundle)

    /// The "SettingsBackground" asset catalog color resource.
    static let settingsBackground = ColorResource(name: "SettingsBackground", bundle: resourceBundle)

    /// The "SettingsHighlighted" asset catalog color resource.
    static let settingsHighlighted = ColorResource(name: "SettingsHighlighted", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "App" asset catalog image resource.
    static let app = ImageResource(name: "App", bundle: resourceBundle)

    /// The "Back" asset catalog image resource.
    static let back = ImageResource(name: "Back", bundle: resourceBundle)

    /// The "BackgroundAudioPermission" asset catalog image resource.
    static let backgroundAudioPermission = ImageResource(name: "BackgroundAudioPermission", bundle: resourceBundle)

    /// The "BackgroundFetchPermission" asset catalog image resource.
    static let backgroundFetchPermission = ImageResource(name: "BackgroundFetchPermission", bundle: resourceBundle)

    /// The "BetaBadge" asset catalog image resource.
    static let betaBadge = ImageResource(name: "BetaBadge", bundle: resourceBundle)

    /// The "Blue" asset catalog image resource.
    static let blue = ImageResource(name: "Blue", bundle: resourceBundle)

    /// The "Dark" asset catalog image resource.
    static let dark = ImageResource(name: "Dark", bundle: resourceBundle)

    /// The "GitHub" asset catalog image resource.
    static let gitHub = ImageResource(name: "GitHub", bundle: resourceBundle)

    /// The "Honeydew" asset catalog image resource.
    static let honeydew = ImageResource(name: "Honeydew", bundle: resourceBundle)

    /// The "Mastodon" asset catalog image resource.
    static let mastodon = ImageResource(name: "Mastodon", bundle: resourceBundle)

    /// The "MyApps" asset catalog image resource.
    static let myApps = ImageResource(name: "MyApps", bundle: resourceBundle)

    /// The "News" asset catalog image resource.
    static let news = ImageResource(name: "News", bundle: resourceBundle)

    /// The "Next" asset catalog image resource.
    static let next = ImageResource(name: "Next", bundle: resourceBundle)

    /// The "PhotosPermission" asset catalog image resource.
    static let photosPermission = ImageResource(name: "PhotosPermission", bundle: resourceBundle)

    /// The "Pride" asset catalog image resource.
    static let pride = ImageResource(name: "Pride", bundle: resourceBundle)

    /// The "Sandy" asset catalog image resource.
    static let sandy = ImageResource(name: "Sandy", bundle: resourceBundle)

    /// The "Settings" asset catalog image resource.
    static let settings = ImageResource(name: "Settings", bundle: resourceBundle)

    /// The "SideStore" asset catalog image resource.
    static let sideStore = ImageResource(name: "SideStore", bundle: resourceBundle)

    /// The "Sky" asset catalog image resource.
    static let sky = ImageResource(name: "Sky", bundle: resourceBundle)

    /// The "Snow" asset catalog image resource.
    static let snow = ImageResource(name: "Snow", bundle: resourceBundle)

    /// The "Sources" asset catalog image resource.
    static let sources = ImageResource(name: "Sources", bundle: resourceBundle)

    /// The "Starburst" asset catalog image resource.
    static let starburst = ImageResource(name: "Starburst", bundle: resourceBundle)

    /// The "Storm" asset catalog image resource.
    static let storm = ImageResource(name: "Storm", bundle: resourceBundle)

    /// The "Threads" asset catalog image resource.
    static let threads = ImageResource(name: "Threads", bundle: resourceBundle)

    /// The "Twitter" asset catalog image resource.
    static let twitter = ImageResource(name: "Twitter", bundle: resourceBundle)

    /// The "Vista" asset catalog image resource.
    static let vista = ImageResource(name: "Vista", bundle: resourceBundle)

    /// The "Winter" asset catalog image resource.
    static let winter = ImageResource(name: "Winter", bundle: resourceBundle)

}

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}

protocol _ACResourceInitProtocol {}
extension AppKit.NSImage: _ACResourceInitProtocol {}

@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension _ACResourceInitProtocol {

    /// Initialize a `NSImage` with an image resource.
    init(resource: ImageResource) {
        self = resource.bundle.image(forResource: NSImage.Name(resource.name))! as! Self
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(resource: ColorResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}

@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(resource: ImageResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(_ resource: ImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif
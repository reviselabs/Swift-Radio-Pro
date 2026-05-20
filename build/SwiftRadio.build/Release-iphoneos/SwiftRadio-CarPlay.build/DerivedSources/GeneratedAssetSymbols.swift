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

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

    /// The "LaunchBackground" asset catalog color resource.
    static let launchBackground = ColorResource(name: "LaunchBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "logo" asset catalog image resource.
    static let logo = ImageResource(name: "logo", bundle: resourceBundle)

    /// The "station-4play" asset catalog image resource.
    static let station4Play = ImageResource(name: "station-4play", bundle: resourceBundle)

    /// The "station-bangaz" asset catalog image resource.
    static let stationBangaz = ImageResource(name: "station-bangaz", bundle: resourceBundle)

    /// The "station-cherri" asset catalog image resource.
    static let stationCherri = ImageResource(name: "station-cherri", bundle: resourceBundle)

    /// The "station-chill" asset catalog image resource.
    static let stationChill = ImageResource(name: "station-chill", bundle: resourceBundle)

    /// The "station-hawkesburyradio" asset catalog image resource.
    static let stationHawkesburyradio = ImageResource(name: "station-hawkesburyradio", bundle: resourceBundle)

    /// The "station-injabulo" asset catalog image resource.
    static let stationInjabulo = ImageResource(name: "station-injabulo", bundle: resourceBundle)

    /// The "station-kissfm" asset catalog image resource.
    static let stationKissfm = ImageResource(name: "station-kissfm", bundle: resourceBundle)

    /// The "station-mix" asset catalog image resource.
    static let stationMix = ImageResource(name: "station-mix", bundle: resourceBundle)

    /// The "station-regentradio" asset catalog image resource.
    static let stationRegentradio = ImageResource(name: "station-regentradio", bundle: resourceBundle)

    /// The "station-starterfm" asset catalog image resource.
    static let stationStarterfm = ImageResource(name: "station-starterfm", bundle: resourceBundle)

    /// The "station-trance" asset catalog image resource.
    static let stationTrance = ImageResource(name: "station-trance", bundle: resourceBundle)

    /// The "station-tune1" asset catalog image resource.
    static let stationTune1 = ImageResource(name: "station-tune1", bundle: resourceBundle)

    /// The "station-v1radio" asset catalog image resource.
    static let stationV1Radio = ImageResource(name: "station-v1radio", bundle: resourceBundle)

    /// The "stationImage" asset catalog image resource.
    static let station = ImageResource(name: "stationImage", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .launchBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .launchBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: SwiftUI.Color { .init(.launchBackground) }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "LaunchBackground" asset catalog color.
    static var launchBackground: SwiftUI.Color { .init(.launchBackground) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "logo" asset catalog image.
    static var logo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .logo)
#else
        .init()
#endif
    }

    /// The "station-4play" asset catalog image.
    static var station4Play: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .station4Play)
#else
        .init()
#endif
    }

    /// The "station-bangaz" asset catalog image.
    static var stationBangaz: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationBangaz)
#else
        .init()
#endif
    }

    /// The "station-cherri" asset catalog image.
    static var stationCherri: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationCherri)
#else
        .init()
#endif
    }

    /// The "station-chill" asset catalog image.
    static var stationChill: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationChill)
#else
        .init()
#endif
    }

    /// The "station-hawkesburyradio" asset catalog image.
    static var stationHawkesburyradio: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationHawkesburyradio)
#else
        .init()
#endif
    }

    /// The "station-injabulo" asset catalog image.
    static var stationInjabulo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationInjabulo)
#else
        .init()
#endif
    }

    /// The "station-kissfm" asset catalog image.
    static var stationKissfm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationKissfm)
#else
        .init()
#endif
    }

    /// The "station-mix" asset catalog image.
    static var stationMix: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationMix)
#else
        .init()
#endif
    }

    /// The "station-regentradio" asset catalog image.
    static var stationRegentradio: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationRegentradio)
#else
        .init()
#endif
    }

    /// The "station-starterfm" asset catalog image.
    static var stationStarterfm: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationStarterfm)
#else
        .init()
#endif
    }

    /// The "station-trance" asset catalog image.
    static var stationTrance: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationTrance)
#else
        .init()
#endif
    }

    /// The "station-tune1" asset catalog image.
    static var stationTune1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationTune1)
#else
        .init()
#endif
    }

    /// The "station-v1radio" asset catalog image.
    static var stationV1Radio: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stationV1Radio)
#else
        .init()
#endif
    }

    /// The "stationImage" asset catalog image.
    static var station: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .station)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "logo" asset catalog image.
    static var logo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .logo)
#else
        .init()
#endif
    }

    /// The "station-4play" asset catalog image.
    static var station4Play: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .station4Play)
#else
        .init()
#endif
    }

    /// The "station-bangaz" asset catalog image.
    static var stationBangaz: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationBangaz)
#else
        .init()
#endif
    }

    /// The "station-cherri" asset catalog image.
    static var stationCherri: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationCherri)
#else
        .init()
#endif
    }

    /// The "station-chill" asset catalog image.
    static var stationChill: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationChill)
#else
        .init()
#endif
    }

    /// The "station-hawkesburyradio" asset catalog image.
    static var stationHawkesburyradio: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationHawkesburyradio)
#else
        .init()
#endif
    }

    /// The "station-injabulo" asset catalog image.
    static var stationInjabulo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationInjabulo)
#else
        .init()
#endif
    }

    /// The "station-kissfm" asset catalog image.
    static var stationKissfm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationKissfm)
#else
        .init()
#endif
    }

    /// The "station-mix" asset catalog image.
    static var stationMix: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationMix)
#else
        .init()
#endif
    }

    /// The "station-regentradio" asset catalog image.
    static var stationRegentradio: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationRegentradio)
#else
        .init()
#endif
    }

    /// The "station-starterfm" asset catalog image.
    static var stationStarterfm: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationStarterfm)
#else
        .init()
#endif
    }

    /// The "station-trance" asset catalog image.
    static var stationTrance: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationTrance)
#else
        .init()
#endif
    }

    /// The "station-tune1" asset catalog image.
    static var stationTune1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationTune1)
#else
        .init()
#endif
    }

    /// The "station-v1radio" asset catalog image.
    static var stationV1Radio: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stationV1Radio)
#else
        .init()
#endif
    }

    /// The "stationImage" asset catalog image.
    static var station: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .station)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

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
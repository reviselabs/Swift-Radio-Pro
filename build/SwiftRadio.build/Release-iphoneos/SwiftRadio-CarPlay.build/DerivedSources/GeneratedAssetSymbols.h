#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.radiocorp.starterplus-carplay";

/// The "LaunchBackground" asset catalog color resource.
static NSString * const ACColorNameLaunchBackground AC_SWIFT_PRIVATE = @"LaunchBackground";

/// The "logo" asset catalog image resource.
static NSString * const ACImageNameLogo AC_SWIFT_PRIVATE = @"logo";

/// The "station-4play" asset catalog image resource.
static NSString * const ACImageNameStation4Play AC_SWIFT_PRIVATE = @"station-4play";

/// The "station-bangaz" asset catalog image resource.
static NSString * const ACImageNameStationBangaz AC_SWIFT_PRIVATE = @"station-bangaz";

/// The "station-cherri" asset catalog image resource.
static NSString * const ACImageNameStationCherri AC_SWIFT_PRIVATE = @"station-cherri";

/// The "station-chill" asset catalog image resource.
static NSString * const ACImageNameStationChill AC_SWIFT_PRIVATE = @"station-chill";

/// The "station-hawkesburyradio" asset catalog image resource.
static NSString * const ACImageNameStationHawkesburyradio AC_SWIFT_PRIVATE = @"station-hawkesburyradio";

/// The "station-injabulo" asset catalog image resource.
static NSString * const ACImageNameStationInjabulo AC_SWIFT_PRIVATE = @"station-injabulo";

/// The "station-kissfm" asset catalog image resource.
static NSString * const ACImageNameStationKissfm AC_SWIFT_PRIVATE = @"station-kissfm";

/// The "station-mix" asset catalog image resource.
static NSString * const ACImageNameStationMix AC_SWIFT_PRIVATE = @"station-mix";

/// The "station-regentradio" asset catalog image resource.
static NSString * const ACImageNameStationRegentradio AC_SWIFT_PRIVATE = @"station-regentradio";

/// The "station-starterfm" asset catalog image resource.
static NSString * const ACImageNameStationStarterfm AC_SWIFT_PRIVATE = @"station-starterfm";

/// The "station-trance" asset catalog image resource.
static NSString * const ACImageNameStationTrance AC_SWIFT_PRIVATE = @"station-trance";

/// The "station-tune1" asset catalog image resource.
static NSString * const ACImageNameStationTune1 AC_SWIFT_PRIVATE = @"station-tune1";

/// The "station-v1radio" asset catalog image resource.
static NSString * const ACImageNameStationV1Radio AC_SWIFT_PRIVATE = @"station-v1radio";

/// The "stationImage" asset catalog image resource.
static NSString * const ACImageNameStationImage AC_SWIFT_PRIVATE = @"stationImage";

#undef AC_SWIFT_PRIVATE

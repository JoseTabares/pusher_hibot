#import "PusherHibotPlugin.h"
#if __has_include(<pusher_hibot/pusher_hibot-Swift.h>)
#import <pusher_hibot/pusher_hibot-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "pusher_hibot-Swift.h"
#endif

@implementation PusherHibotPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftPusherHibotPlugin registerWithRegistrar:registrar];
}
@end

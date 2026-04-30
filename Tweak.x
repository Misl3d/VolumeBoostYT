#import "YTVolumeHUD.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// YouTube Settings Headers
@interface YTSettingsCell : UITableViewCell
@end

@interface YTSettingsSectionItem : NSObject
+ (instancetype)switchItemWithTitle:(NSString *)title
                   titleDescription:(NSString *)titleDescription
            accessibilityIdentifier:(NSString *)accessibilityIdentifier
                           switchOn:(BOOL)switchOn
                        switchBlock:(BOOL (^)(YTSettingsCell *cell,
                                              BOOL enabled))switchBlock
                      settingItemId:(int)settingItemId;
@end

@interface YTSettingsViewController : UIViewController
- (void)setSectionItems:(NSMutableArray<YTSettingsSectionItem *> *)items
            forCategory:(NSUInteger)category
                  title:(NSString *)title
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
- (void)setSectionItems:(NSMutableArray<YTSettingsSectionItem *> *)items
            forCategory:(NSUInteger)category
                  title:(NSString *)title
                   icon:(id)icon
       titleDescription:(NSString *)titleDescription
           headerHidden:(BOOL)headerHidden;
@end

@interface YTSettingsGroupData : NSObject
@property(nonatomic, assign) NSInteger type;
- (NSArray<NSNumber *> *)orderedCategories;
@end

@interface YTAppSettingsPresentationData : NSObject
+ (NSArray<NSNumber *> *)settingsCategoryOrder;
@end

@interface YTSettingsSectionItemManager : NSObject
- (void)updateYTGesturesSectionWithEntry:(id)entry;
@end

// Unique Section ID to avoid conflict with VolumeBoostYT ('ndyt')
static const NSInteger YTGestureSection = 'ytgs'; 
static NSString *const kYTGesturesEnabledKey = @"YTGesturesEnabled";

static BOOL IsYTGesturesEnabled() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults objectForKey:kYTGesturesEnabledKey] ? [defaults boolForKey:kYTGesturesEnabledKey] : YES;
}

// -----------------------------------------------------
// SYSTEM VOLUME HELPER
// -----------------------------------------------------

static UISlider *GetSystemVolumeSlider() {
    static UISlider *volumeSlider = nil;
    if (!volumeSlider) {
        MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
        for (UIView *view in [volumeView subviews]) {
            if ([NSStringFromClass([view class]) isEqualToString:@"MPVolumeSlider"]) {
                volumeSlider = (UISlider *)view;
                break;
            }
        }
    }
    return volumeSlider;
}

static float GetCurrentSystemVolume() {
    return [[AVAudioSession sharedInstance] outputVolume];
}

static void SetSystemVolume(float level) {
    if (level < 0.0f) level = 0.0f;
    if (level > 1.0f) level = 1.0f;
    
    UISlider *slider = GetSystemVolumeSlider();
    [slider setValue:level animated:NO];
    [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
}

// -----------------------------------------------------
// UI Hooks (sendEvent:)
// -----------------------------------------------------

static float gestureStartVolume = 0.0f;
static BOOL possibleVolumeGesture = NO;
static BOOL isTrackingVolumeGesture = NO;
static CGPoint initialTouchPoint;

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (!IsYTGesturesEnabled()) { %orig(event); return; }

    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self];

    switch (touch.phase) {
        case UITouchPhaseBegan: {
            if (location.x >= self.bounds.size.width - 25.0f) {
                possibleVolumeGesture = YES;
                isTrackingVolumeGesture = NO;
                initialTouchPoint = location;
                return; 
            }
            break;
        }
        case UITouchPhaseMoved: {
            if (possibleVolumeGesture) {
                CGFloat dx = initialTouchPoint.x - location.x;
                CGFloat dy = fabs(location.y - initialTouchPoint.y);
                if (dx > 15.0f && dx > dy) {
                    isTrackingVolumeGesture = YES;
                    possibleVolumeGesture = NO;
                    initialTouchPoint = location;
                    gestureStartVolume = GetCurrentSystemVolume();
                    return;
                } else if (dy > 20.0f) {
                    possibleVolumeGesture = NO;
                }
            }

            if (isTrackingVolumeGesture) {
                CGFloat translationY = location.y - initialTouchPoint.y;
                float deltaVolume = -translationY / 300.0f; 
                SetSystemVolume(gestureStartVolume + deltaVolume);
                return;
            }
            break;
        }
        case UITouchPhaseEnded:
        case UITouchPhaseCancelled: {
            possibleVolumeGesture = NO;
            isTrackingVolumeGesture = NO;
            break;
        }
        default: break;
    }
    %orig(event);
}
%end

// -----------------------------------------------------
// YouTube In-App Settings Integration
// -----------------------------------------------------

%group YouTubeSettings

%hook YTSettingsGroupData
- (NSArray<NSNumber *> *)orderedCategories {
    if (self.type != 1) return %orig;

    if (class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks))) {
        return %orig;
    }

    NSMutableArray *mutableCategories = %orig.mutableCopy;
    if (mutableCategories) {
        [mutableCategories insertObject:@(YTGestureSection) atIndex:0];
    }
    return mutableCategories.copy ?: %orig;
}

+ (NSMutableArray<NSNumber *> *)tweaks {
    NSMutableArray<NSNumber *> *tweaks = %orig;
    if (tweaks && ![tweaks containsObject:@(YTGestureSection)]) {
        [tweaks addObject:@(YTGestureSection)];
    }
    return tweaks;
}
%end

%hook YTAppSettingsPresentationData
+ (NSArray<NSNumber *> *)settingsCategoryOrder {
    NSArray<NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];

    if (insertIndex != NSNotFound) {
        NSMutableArray<NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(YTGestureSection) atIndex:insertIndex + 1];
        return mutableOrder.copy;
    }
    return order ?: %orig;
}
%end

%hook YTSettingsSectionItemManager
%new(v@:@)
- (void)updateYTGesturesSectionWithEntry:(id)entry {
    NSMutableArray<YTSettingsSectionItem *> *sectionItems = [NSMutableArray array];
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    if (!YTSettingsSectionItemClass) return;

    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    YTSettingsSectionItem *enableTweak = [YTSettingsSectionItemClass
          switchItemWithTitle:@"Enable YTGestures"
             titleDescription:@"Allow custom right-edge pan volume gesture"
      accessibilityIdentifier:nil
                     switchOn:IsYTGesturesEnabled()
                  switchBlock:^BOOL(YTSettingsCell *cell, BOOL enabled) {
                    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kYTGesturesEnabledKey];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    return YES;
                  }
                settingItemId:0];
    [sectionItems addObject:enableTweak];

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        [settingsViewController setSectionItems:sectionItems
                                    forCategory:YTGestureSection
                                          title:@"YTGestures"
                                           icon:nil
                               titleDescription:nil
                                   headerHidden:NO];
    } else if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:titleDescription:headerHidden:)]) {
        [settingsViewController setSectionItems:sectionItems
                                    forCategory:YTGestureSection
                                          title:@"YTGestures"
                               titleDescription:nil
                                   headerHidden:NO];
    }
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == YTGestureSection) {
        [self updateYTGesturesSectionWithEntry:entry];
        return;
    }
    %orig;
}
%end

%end // end group YouTubeSettings

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.apple.springboard"]) return;

    if (NSClassFromString(@"YTSettingsGroupData")) {
        %init(YouTubeSettings);
    }
    %init;
}

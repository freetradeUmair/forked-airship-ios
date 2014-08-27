/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAUserNotificationCategories.h"
#import "UAGlobal.h"

@implementation UAUserNotificationCategories

+ (NSSet *)defaultCategories {
    return [self defaultCategoriesWithRequireAuth:YES];
}

+ (NSSet *)defaultCategoriesWithRequireAuth:(BOOL)requireAuth {
    NSArray *categories = @[[self createYesNoForegroundCategoryRequireAuth:requireAuth],
                            [self createYesNoBackgroundCategoryRequireAuth:requireAuth],
                            [self createShopNowCategory],
                            [self createBuyNowCategory],
                            [self createFollowCategoryRequireAuth:requireAuth],
                            [self createUnfollowCategoryRequireAuth:requireAuth],
                            [self createOptInCategoryRequireAuth:requireAuth],
                            [self createOptOutCategoryRequireAuth:requireAuth],
                            [self createRemindMeLaterCategoryRequireAuth:requireAuth],
                            [self createShareCategory],
                            [self createAcceptOrDeclineForegroundCategoryRequireAuth:requireAuth],
                            [self createAcceptOrDeclineBackgroundCategoryRequireAuth:requireAuth]];

    return [NSSet setWithArray:categories];
}


+ (UIUserNotificationCategory *)createYesNoForegroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @YES,
                           @"title_resource": @"ua_yes_no_foreground_yes",
                           @"title": @"Yes"},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title_resource": @"ua_yes_no_foreground_no",
                           @"title": @"No",
                           @"authenticationRequired":@(requireAuth)}];

    return [self createCategory:@"ua_yes_no_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createYesNoBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"yes",
                           @"foreground": @NO,
                           @"title_resource": @"ua_yes_no_background_yes",
                           @"title": @"Yes",
                           @"authenticationRequired": @(requireAuth)},
                         @{@"identifier": @"no",
                           @"foreground": @NO,
                           @"title_resource": @"ua_yes_no_background_no",
                           @"title": @"No",
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_yes_no_background" actions:actions];
}


+ (UIUserNotificationCategory *)createShopNowCategory {
    NSArray *actions = @[@{@"identifier": @"shop_now",
                           @"foreground": @YES,
                           @"title_resource": @"ua_shop_now_shop_now",
                           @"title": @"Shop Now"}];

    return [self createCategory:@"ua_shop_now" actions:actions];
}

+ (UIUserNotificationCategory *)createBuyNowCategory {
    NSArray *actions = @[@{@"identifier": @"buy_now",
                           @"foreground": @YES,
                           @"title_resource": @"ua_buy_now_buy_now",
                           @"title": @"Buy Now"}];

    return [self createCategory:@"ua_buy_now" actions:actions];
}

+ (UIUserNotificationCategory *)createFollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"follow",
                           @"foreground": @NO,
                           @"title_resource": @"ua_follow_follow",
                           @"title": @"Follow",
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_follow" actions:actions];
}


+ (UIUserNotificationCategory *)createUnfollowCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"unfollow",
                           @"foreground": @NO,
                           @"title_resource": @"ua_unfollow_unfollow",
                           @"title": @"Unfollow",
                           @"destructive": @YES,
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_unfollow" actions:actions];
}

+ (UIUserNotificationCategory *)createOptInCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_in",
                           @"foreground": @NO,
                           @"title_resource": @"ua_opt_in_opt_in",
                           @"title": @"Opt-in",
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_opt_in" actions:actions];
}

+ (UIUserNotificationCategory *)createOptOutCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"opt_out",
                           @"foreground": @NO,
                           @"title_resource": @"ua_opt_out_opt_out",
                           @"title": @"Opt-out",
                           @"destructive": @YES,
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_opt_out" actions:actions];
}

+ (UIUserNotificationCategory *)createRemindMeLaterCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"remind",
                           @"foreground": @NO,
                           @"title_resource": @"ua_remind_me_later_remind",
                           @"title": @"Remind Me Later",
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_remind_me_later" actions:actions];
}

+ (UIUserNotificationCategory *)createShareCategory {
    NSArray *actions = @[@{@"identifier": @"share",
                           @"foreground": @YES,
                           @"title_resource": @"ua_share_share",
                           @"title": @"Share"}];

    return [self createCategory:@"ua_share" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineForegroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"accept",
                           @"foreground": @YES,
                           @"title_resource": @"ua_accept_decline_foreground_accept",
                           @"title": @"Accept"},
                         @{@"identifier": @"decline",
                           @"foreground": @NO,
                           @"title_resource": @"ua_accept_decline_foreground_decline",
                           @"title": @"Decline",
                           @"authenticationRequired":@(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_foreground" actions:actions];
}

+ (UIUserNotificationCategory *)createAcceptOrDeclineBackgroundCategoryRequireAuth:(BOOL)requireAuth {
    NSArray *actions = @[@{@"identifier": @"accept",
                           @"foreground": @NO,
                           @"title_resource": @"ua_accept_decline_background_accept",
                           @"title": @"Accept",
                           @"authenticationRequired": @(requireAuth)},
                         @{@"identifier": @"decline",
                           @"foreground": @NO,
                           @"title_resource": @"ua_accept_decline_background_decline",
                           @"title": @"Decline",
                           @"authenticationRequired": @(requireAuth)}];

    return [self createCategory:@"ua_accept_decline_background" actions:actions];
}

+ (NSSet *)createCategoriesFromFile:(NSString *)path {
    NSDictionary *categoriesDictionary = [[NSDictionary alloc] initWithContentsOfFile:path];

    NSMutableSet *categories = [NSMutableSet set];

    for (NSString *categoryId in [categoriesDictionary allKeys]) {
        NSArray *actions = [categoriesDictionary valueForKey:categoryId];
        if (actions) {
            UIUserNotificationCategory *category = [self createCategory:categoryId actions:actions];
            if (category) {
                [categories addObject:category];
            }
        }
    }

    return [NSSet setWithSet:categories];
}

+ (UIUserNotificationCategory *)createCategory:(NSString *)categoryId actions:(NSArray *)actionDefinitions {
    NSMutableArray *actions = [NSMutableArray array];

    for (NSDictionary *actionDefinition in actionDefinitions) {
        NSString *title;
        if (actionDefinition[@"title_resource"]) {
            title = NSLocalizedStringWithDefaultValue(actionDefinition[@"title_resource"], nil, [NSBundle mainBundle], actionDefinition[@"title"], nil);
        } else if (actionDefinition[@"title"]) {
            title = actionDefinition[@"title"];
        }

        if (!title) {
            UA_LERR(@"Error creating category: %@ for action: %@ due to missing required title.",
                    categoryId, actionDefinition[@"identifier"]);
            return nil;
        }

        UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
        action.destructive = [actionDefinition[@"destructive"] boolValue];
        action.activationMode = [actionDefinition[@"foreground"] boolValue] ? UIUserNotificationActivationModeForeground : UIUserNotificationActivationModeBackground;
        action.title = title;
        action.identifier = actionDefinition[@"identifier"];
        action.authenticationRequired = [actionDefinition[@"authenticationRequired"] boolValue];
        [actions addObject:action];
    }

    UIMutableUserNotificationCategory *category = [[UIMutableUserNotificationCategory alloc] init];
    [category setActions:actions forContext:UIUserNotificationActionContextMinimal];
    [category setActions:actions forContext:UIUserNotificationActionContextDefault];
    category.identifier = categoryId;

    return category;
}

@end

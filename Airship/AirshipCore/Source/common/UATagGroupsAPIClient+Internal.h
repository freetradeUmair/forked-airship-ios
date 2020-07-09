/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAAPIClient.h"

@class UARuntimeConfig;
@class UATagGroupsMutation;

NS_ASSUME_NONNULL_BEGIN

/**
* The tag goups channel store key.
*/
extern NSString * const UATagGroupsChannelStoreKey;

/**
* The tag groups named user store key.
*/
extern NSString * const UATagGroupsNamedUserStoreKey;

/**
 * A high level abstraction for performing tag group operations.
 */
@interface UATagGroupsAPIClient : UAAPIClient

///---------------------------------------------------------------------------------------
/// @name Tag Groups API Client Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Airship config.
 * @param keyStore the tag groups key store.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config keyStore:(NSString *)keyStore ;

/**
 * Factory method to create a UATagGroupsAPIClient.
 *
 * @param config The Airship config.
 * @param session The request session.
 * @param keyStore the tag groups key store.
 * @return UATagGroupsAPIClient instance.
 */
+ (instancetype)clientWithConfig:(UARuntimeConfig *)config session:(UARequestSession *)session keyStore:(NSString *)keyStore;

/**
 * Update the tag group for the identifier.
 *
 * @param identifier The ID string.
 * @param mutation The tag groups changes.
 * @param completionHandler The completion handler with the status code.
 */
- (void)updateTagGroupsForId:(NSString *)identifier
           tagGroupsMutation:(UATagGroupsMutation *)mutation
           completionHandler:(void (^)(NSUInteger status))completionHandler;

@end

NS_ASSUME_NONNULL_END

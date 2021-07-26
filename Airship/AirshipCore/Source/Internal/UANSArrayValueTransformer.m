/* Copyright Airship and Contributors */

#import "UANSArrayValueTransformer.h"
#import "UAGlobal.h"

@implementation UANSArrayValueTransformer

+ (Class)transformedValueClass {
    return [NSData class];
}

+ (BOOL)allowsReverseTransformation {
    return YES;
}

- (id)transformedValue:(id)value {
    NSError *error = nil;
    id result = [NSKeyedArchiver archivedDataWithRootObject:value
                                      requiringSecureCoding:YES
                                                      error:&error];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}

- (id)reverseTransformedValue:(id)value {
    NSError *error = nil;

    NSSet<Class> *classes = [NSSet setWithArray:@[[NSDictionary class], [NSArray class],
                                                  [NSString class], [NSNumber class],
                                                  [NSSet class], [NSDate class], [NSData class],
                                                  [NSURL class], [NSUUID class], [NSNull class]]];

    id result = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:value error:&error];

    if (error) {
        UA_LERR(@"Failed to transform value: %@, error: %@", value, error);
    }

    return result;
}

@end

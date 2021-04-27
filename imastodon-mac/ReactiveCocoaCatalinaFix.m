@import AppKit;

@implementation NSStackView (CatalinaFix)

- (void)safelyRemoveArrangedSubviews
{
    // see also https://github.com/ReactiveCocoa/ReactiveCocoa/issues/3690
    @try {
        for (NSView *v in self.arrangedSubviews) {
            [self removeArrangedSubview:v];
        }
    } @catch(NSException *exception) {
        if ([exception.reason hasPrefix:@"Cannot remove an observer <NSStackView"]) {
            NSLog(@"ignore exception: %@", exception);
        } else {
            @throw exception;
        }
    }
}

@end

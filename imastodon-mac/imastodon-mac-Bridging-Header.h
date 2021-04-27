@import AppKit;

@interface NSStackView (CatalinaFix)
- (void)safelyRemoveArrangedSubviews;
@end

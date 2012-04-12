//
//  SVStackRootController.m
//  PSStackedView
//
//  Created by Peter Steinberger on 7/14/11.
//  Copyright 2011 Peter Steinberger. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "PSStackedView.h"
#import "UIViewController+PSStackedView.h"
#import "UIViewController+YSEmbedding.h"

#define kPSSVStackAnimationSpeedModifier 1.f // DEBUG!
#define kPSSVStackAnimationDuration kPSSVStackAnimationSpeedModifier * 0.25f
#define kPSSVStackAnimationBounceDuration kPSSVStackAnimationSpeedModifier * 0.20f
#define kPSSVStackAnimationPushDuration kPSSVStackAnimationSpeedModifier * 0.25f
#define kPSSVStackAnimationPopDuration kPSSVStackAnimationSpeedModifier * 0.25f
#define kPSSVMaxSnapOverOffset 20
#define kPSSVAssociatedBaseViewControllerKey @"kPSSVAssociatedBaseViewController"
#define kPSSVAssociatedChildViewControllersKey @"kPSSVAssociatedChildViewControllers"

// reduces alpha over overlapped view controllers. 1.f would totally black-out on complete overlay
#define kAlphaReductRatio 10.f
#define EPSILON .001f // float calculations

// prevents me getting crazy
typedef void(^PSSVSimpleBlock)(void);


@interface PSStackedViewController()

@property(nonatomic, retain) UIViewController *rootViewController;
@property(nonatomic, retain) UIViewController *floatingViewController;
@property(nonatomic, retain) NSArray *viewControllers;
@property(nonatomic, assign) NSInteger firstVisibleIndex;
@property(nonatomic, assign) CGFloat floatIndex;
@property(nonatomic, assign) BOOL createdWithAlloc;

- (UIViewController *)overlappedViewController;
- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer;

- (void)sharedInit;

- (NSArray*)inactiveViewControllers;
- (NSArray*)activeViewControllers;

@end

@implementation PSStackedViewController

@synthesize leftInset = leftInset_;
@synthesize largeLeftInset = largeLeftInset_;
@synthesize viewControllers = viewControllers_;
@synthesize floatIndex = floatIndex_;
@synthesize rootViewController = rootViewController_;
@synthesize floatingViewController = floatingViewController_;
@synthesize panRecognizer = panRecognizer_;
@synthesize delegate = delegate_;
@synthesize reduceAnimations = reduceAnimations_;
@synthesize enableBounces = enableBounces_;
@synthesize enableShadows = enableShadows_;
@synthesize enableDraggingPastInsets = enableDraggingPastInsets_;
@synthesize enableScalingFadeInOut = enableScalingFadeInOut_;
@synthesize enableAppearsFromRight = enableAppearsFromRight_;
@synthesize defaultShadowWidth = defaultShadowWidth_;
@synthesize defaultShadowAlpha  = defaultShadowAlpha_;
@synthesize cornerRadius = cornerRadius_;
@synthesize numberOfTouches = numberOfTouches_;
@dynamic firstVisibleIndex;
@synthesize createdWithAlloc;

#ifdef ALLOW_SWIZZLING_NAVIGATIONCONTROLLER
@synthesize navigationBar;
#endif

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (void)configureGestureRecognizer
{
    [self.view removeGestureRecognizer:self.panRecognizer];
    
    // add a gesture recognizer to detect dragging to the guest controllers
    UIPanGestureRecognizer *panRecognizer = [[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)] autorelease];
    if (numberOfTouches_ > 0)
    {
        [panRecognizer setMinimumNumberOfTouches:numberOfTouches_];
    } else {
        [panRecognizer setMaximumNumberOfTouches:1];            
    }
    [panRecognizer setDelaysTouchesBegan:NO];
    [panRecognizer setDelaysTouchesEnded:YES];
    [panRecognizer setCancelsTouchesInView:YES];
    panRecognizer.delegate = self;
    [self.view addGestureRecognizer:panRecognizer];
    self.panRecognizer = panRecognizer;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController {
	return [self initWithRootViewController:rootViewController floatingViewController:nil];
}

- (id)initWithRootViewController:(UIViewController *)rootViewController floatingViewController:(UIViewController *)floatingViewController {
    if ((self = [super init])) {
        self.rootViewController = rootViewController;
		self.floatingViewController = floatingViewController;
		self.createdWithAlloc = YES;
        [self sharedInit];
    }
    return self;
}

- (void)dealloc {
    delegate_ = nil;
    self.panRecognizer.delegate = nil;
	self.panRecognizer = nil;
	
    // remove all view controllers the hard way (w/o calling delegate)
    while ([self.viewControllers count]) {
        [self popViewControllerAnimated:NO];
    }
    
	[viewControllers_ release];
	
	self.viewControllers = nil;	
	self.rootViewController = nil;
	self.floatingViewController = nil;
	
	[super dealloc];
}

- (void)sharedInit {
	
#ifdef ALLOW_SWIZZLING_NAVIGATIONCONTROLLER
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        Method origMethod = class_getInstanceMethod([UIViewController class], @selector(navigationController));
        Method overrideMethod = class_getInstanceMethod([UIViewController class], @selector(navigationControllerSwizzled));
        method_exchangeImplementations(origMethod, overrideMethod);
	});
#endif
		
	if (rootViewController_) {
		objc_setAssociatedObject(rootViewController_, kPSSVAssociatedStackViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN); // associate weak
	}
	if (floatingViewController_) {
		objc_setAssociatedObject(floatingViewController_, kPSSVAssociatedStackViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN); // associate weak
	}
	
	viewControllers_ = [[NSMutableArray alloc] init];
	
	// set some reasonble defaults
	leftInset_ = 60;
	largeLeftInset_ = 200;
	
	[self configureGestureRecognizer];
	
	enableBounces_ = YES;
	enableShadows_ = YES;
	enableDraggingPastInsets_ = YES;
	enableScalingFadeInOut_ = YES;
	defaultShadowWidth_ = 60.0f;
	defaultShadowAlpha_ = 0.2f;
	cornerRadius_ = 6.0f;
}


- (void)embedSubviews {
	
    if (self.rootViewController) {
		[self beginAddingTransitionForChildViewController:self.rootViewController];
		[self.rootViewController willMoveToParentViewController:self];
		
		UIView *unused = self.rootViewController.view;
#pragma unused(unused)
		
		if (self.view.window && self.isRunningOnIOS4OrEarlier) {
			[self.rootViewController viewWillAppear:NO];
		}
		
        [self.view addSubview:self.rootViewController.view];
		
		if (self.view.window && self.isRunningOnIOS4OrEarlier) {
			[self.rootViewController viewDidAppear:NO];
		}
		
		[self.rootViewController didMoveToParentViewController:self];
		[self endAddingTransitionForChildViewController:self.rootViewController];
    }
    
    for (UIViewController *controller in self.viewControllers) {
        // forces view loading, calls viewDidLoad via system
        UIView *controllerView = controller.view;
#pragma unused(controllerView)
    }
	
    if (self.floatingViewController) {
		[self beginAddingTransitionForChildViewController:self.floatingViewController];
		[self.floatingViewController willMoveToParentViewController:self];
		
		UIView *unused = self.floatingViewController.view;
#pragma unused(unused)
		
		if (self.view.window && self.isRunningOnIOS4OrEarlier) {
			[self.floatingViewController viewWillAppear:NO];
		}
		
		[self.view addSubview:self.floatingViewController.view];
		
		if (self.view.window && self.isRunningOnIOS4OrEarlier) {
			[self.floatingViewController viewDidAppear:NO];
		}
		
		[self.floatingViewController didMoveToParentViewController:self];
		[self endAddingTransitionForChildViewController:self.floatingViewController];
    }	
}

- (void)awakeFromNib {
	[self sharedInit];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self embedSubviews];
	});
	
}




///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Delegate

- (void)setDelegate:(id<PSStackedViewDelegate>)delegate {
    if (delegate != delegate_) {
        delegate_ = delegate;
        
        delegateFlags_.delegateWillInsertViewController = [delegate respondsToSelector:@selector(stackedView:willInsertViewController:)];
        delegateFlags_.delegateDidInsertViewController = [delegate respondsToSelector:@selector(stackedView:didInsertViewController:)];
        delegateFlags_.delegateWillRemoveViewController = [delegate respondsToSelector:@selector(stackedView:willRemoveViewController:)];
        delegateFlags_.delegateDidRemoveViewController = [delegate respondsToSelector:@selector(stackedView:didRemoveViewController:)];
        delegateFlags_.delegateDidPanViewController = [delegate respondsToSelector:@selector(stackedView:didPanViewController:byOffset:)];
        delegateFlags_.delegateDidAlign = [delegate respondsToSelector:@selector(stackedViewDidAlign:)];
		
    }
}

- (void)delegateWillInsertViewController:(UIViewController *)viewController {
    if (delegateFlags_.delegateWillInsertViewController) {
        [self.delegate stackedView:self willInsertViewController:viewController];
    }
}

- (void)delegateDidInsertViewController:(UIViewController *)viewController {
    if (delegateFlags_.delegateDidInsertViewController) {
        [self.delegate stackedView:self didInsertViewController:viewController];
    }
}

- (void)delegateWillRemoveViewController:(UIViewController *)viewController {
    if (delegateFlags_.delegateWillRemoveViewController) {
        [self.delegate stackedView:self willRemoveViewController:viewController];
    }
}

- (void)delegateDidRemoveViewController:(UIViewController *)viewController {
    if (delegateFlags_.delegateDidRemoveViewController) {
        [self.delegate stackedView:self didRemoveViewController:viewController];
    }
}

- (void)delegateDidPanViewController:(UIViewController *)viewController byOffset:(NSInteger)offset {
    if (delegateFlags_.delegateDidPanViewController) {
        [self.delegate stackedView:self didPanViewController:viewController byOffset:offset];
    }
}

- (void)delegateDidAlign{
    if (delegateFlags_.delegateDidAlign) {
        [self.delegate stackedViewDidAlign:self];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helpers

- (NSInteger)firstVisibleIndex {
    NSInteger firstVisibleIndex = floorf(self.floatIndex);
    return firstVisibleIndex;
}

- (CGRect)viewRect {
    // self.view.frame not used, it's wrong in viewWillAppear
    CGRect viewRect = [[UIScreen mainScreen] applicationFrame];
    return viewRect;
}

// return screen width
- (CGFloat)screenWidth {
    CGRect viewRect = [self viewRect];
    CGFloat screenWidth = PSIsLandscape() ? viewRect.size.height : viewRect.size.width;
    return screenWidth;
}

- (CGFloat)screenHeight {
    CGRect viewRect = [self viewRect];
    NSUInteger screenHeight = PSIsLandscape() ? viewRect.size.width : viewRect.size.height;
    return screenHeight;
}

- (CGFloat)maxControllerWidth {
    CGFloat maxWidth = [self screenWidth] - self.leftInset;
    return maxWidth;
}

// total stack width if completely expanded
- (NSUInteger)totalStackWidth {
    NSUInteger totalStackWidth = 0;
    for (UIViewController *controller in self.viewControllers) {
        totalStackWidth += controller.containerView.frameWidth;
    }
    return totalStackWidth;
}

// menu is only collapsable if stack is large enough
- (BOOL)isMenuCollapsable {
    BOOL isMenuCollapsable = [self totalStackWidth] + self.largeLeftInset > [self screenWidth];
    return isMenuCollapsable;
}

// return current left border (how it *should* be)
- (NSUInteger)currentLeftInset {
    return self.floatIndex >= 0.5 ? self.leftInset : self.largeLeftInset;
}

// minimal left border is depending on amount of VCs
- (NSUInteger)minimalLeftInset {
    return [self isMenuCollapsable] ? self.leftInset : self.largeLeftInset;
}

// check if a view controller is visible or not
- (BOOL)isViewControllerVisible:(UIViewController *)viewController completely:(BOOL)completely {
    NSParameterAssert(viewController);
    NSUInteger screenWidth = [self screenWidth];
    
    BOOL isVCVisible = ((viewController.containerView.frameLeft < screenWidth && !completely) ||
                        (completely && viewController.containerView.frameRight <= screenWidth));
    return isVCVisible;
}

// returns view controller that is displayed before viewController 
- (UIViewController *)previousViewController:(UIViewController *)viewController {
    if(!viewController) // don't assert on mere menu events
        return nil;
    
    NSUInteger vcIndex = [self indexOfViewController:viewController];
    UIViewController *prevVC = nil;
    if (vcIndex > 0) {
        prevVC = [self.viewControllers objectAtIndex:vcIndex-1];
    }
    
    return prevVC;
}

// returns view controller that is displayed after viewController 
- (UIViewController *)nextViewController:(UIViewController *)viewController {
    NSParameterAssert(viewController);
    
    NSUInteger vcIndex = [self indexOfViewController:viewController];
    UIViewController *nextVC = nil;
    if (vcIndex + 1 < [self.viewControllers count]) {
        nextVC = [self.viewControllers objectAtIndex:vcIndex+1];
    }
    
    return nextVC;
}

// returns last visible view controller. this *can* be the last view controller in the stack, 
// but also one of the previous ones if the user navigates back in the stack
- (UIViewController *)lastVisibleViewControllerCompletelyVisible:(BOOL)completely {
    __block UIViewController *lastVisibleViewController = nil;
    
    [self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *currentViewController = (UIViewController *)obj;
        if ([self isViewControllerVisible:currentViewController completely:completely]) {
            lastVisibleViewController = currentViewController;
            *stop = YES;
        }
    }];
    
    return lastVisibleViewController;
}

// returns true if firstVisibleIndex is the last available index.
- (BOOL)isLastIndex {
    BOOL isLastIndex = self.firstVisibleIndex == (NSInteger)([self.viewControllers count] - 1);
    return isLastIndex;
}

enum {
    PSSVRoundNearest,
    PSSVRoundUp,
    PSSVRoundDown
}typedef PSSVRoundOption;

- (BOOL)isFloatIndexBetween:(CGFloat)floatIndex {
    CGFloat intIndex, restIndex;
    restIndex = modff(floatIndex, &intIndex);
    BOOL isBetween = fabsf(restIndex - 0.5f) < EPSILON;
    return isBetween;
}

// check if index is valid. Valid indexes are >= 0.0 and only full or .5 parts are allowed.
// there are lots of other, more complex rules, so calculate!
- (BOOL)isValidFloatIndex:(CGFloat)floatIndex {
    BOOL isValid = floatIndex == 0.f; // 0.f is always allowed
    if (!isValid) {
        CGFloat contentWidth = [self totalStackWidth];
        if (floatIndex == 0.5f) {
            // docking to menu is only allowed if content > available size.
            isValid = contentWidth > [self screenWidth] - self.largeLeftInset;
        }else {
            NSUInteger stackCount = [self.viewControllers count];
            CGFloat intIndex, restIndex;
            restIndex = modff(floatIndex, &intIndex); // split e.g. 1.5 in 1.0 and 0.5
            isValid = stackCount > intIndex && contentWidth > ([self screenWidth] - self.leftInset);
            if (isValid && fabsf(restIndex - 0.5f) < EPSILON) {  // comparing floats -> if so, we have a .5 here
                if (ceilf(floatIndex) < stackCount) { // at the end?
                    CGFloat widthLeft = [[self.viewControllers objectAtIndex:floorf(floatIndex)] containerView].frameWidth;
                    CGFloat widthRight = [[self.viewControllers objectAtIndex:ceilf(floatIndex)] containerView].frameWidth;
                    isValid = (widthLeft + widthRight) > ([self screenWidth] - self.leftInset);
                }else {
                    isValid = NO;
                }
            }
        }
    }
    return isValid;
}

- (CGFloat)nearestValidFloatIndex:(CGFloat)floatIndex round:(PSSVRoundOption)roundOption {
    CGFloat roundedFloat;
    CGFloat intIndex, restIndex;
    restIndex = modff(floatIndex, &intIndex);
    
    if (restIndex < 0.5f) {
        if (roundOption == PSSVRoundNearest) {
            restIndex = (restIndex < 0.25f) ? 0.f : 0.5f;
        }else {
            restIndex = (roundOption == PSSVRoundUp) ? 0.5f : 0.f;
        }
    }else {
        if (roundOption == PSSVRoundNearest) {
            restIndex = (restIndex < 0.75f) ? 0.5f : 1.f;
        }else {
            restIndex = (roundOption == PSSVRoundUp) ? 1.f : 0.5f;
        }
    }
    roundedFloat = intIndex + restIndex;
    
    // now check if this is valid
    BOOL isValid = [self isValidFloatIndex:roundedFloat];
    
    // if not valid, and custom rounding produced a .5, test again with full rounding
    if (!isValid && restIndex == 0.5f) {
        CGFloat naturalRoundedIndex;
        if (roundOption == PSSVRoundNearest) {
            naturalRoundedIndex = roundf(floatIndex);
        }else if(roundOption == PSSVRoundUp) {
            naturalRoundedIndex = ceilf(floatIndex);
        }else {
            naturalRoundedIndex = floorf(floatIndex);
        }
        // if that works out, return it!
        if ([self isValidFloatIndex:naturalRoundedIndex]) {
            isValid = YES;
            roundedFloat = naturalRoundedIndex;
        }
    }
    
    // still not valid? start the for loops, find nearest valid index
    if (!isValid) {
        CGFloat validLowIndex = 0.f, validHighIndex = 0.f;
        
        // upper bound
        CGFloat viewControllerCount = [self.viewControllers count];
        for (CGFloat tester = roundedFloat + 0.5f; tester < viewControllerCount;  tester += 0.5f) {
            if ([self isValidFloatIndex:tester]) {
                validHighIndex = tester;
                break;
            }
        }
        // lower bound
        for (CGFloat tester = roundedFloat - 0.5f; tester >= 0.f;  tester -= 0.5f) {
            if ([self isValidFloatIndex:tester]) {
                validLowIndex = tester;
                break;
            }
        }
        
        if (fabsf(validLowIndex - roundedFloat) < fabsf(validHighIndex - roundedFloat)) {
            roundedFloat = validLowIndex;
        }else {
            roundedFloat = validHighIndex;
        }
    }
    
    return roundedFloat;
}

- (CGFloat)nearestValidFloatIndex:(CGFloat)floatIndex {
    return [self nearestValidFloatIndex:floatIndex round:PSSVRoundNearest];
}

- (CGFloat)nextFloatIndex:(CGFloat)floatIndex {
    CGFloat nextFloat = floatIndex;
    CGFloat roundedFloat = [self nearestValidFloatIndex:floatIndex];
    CGFloat viewControllerCount = [self.viewControllers count];
    for (CGFloat tester = roundedFloat + 0.5f; tester < viewControllerCount;  tester += 0.5f) {
        if ([self isValidFloatIndex:tester]) {
            nextFloat = tester;
            break;
        }
    }
    return nextFloat;
}

- (CGFloat)prevFloatIndex:(CGFloat)floatIndex {
    CGFloat prevFloat = floatIndex;
    CGFloat roundedFloat = [self nearestValidFloatIndex:floatIndex];
    for (CGFloat tester = roundedFloat - 0.5f; tester >= 0.f;  tester -= 0.5f) {
        if ([self isValidFloatIndex:tester]) {
            prevFloat = tester;
            break;
        }
    }
    return prevFloat;
}

/// calculates all rects for current visibleIndex orientation
- (NSArray *)rectsForControllers {
    NSMutableArray *frames = [NSMutableArray array];
    
    // TODO: currently calculates *all* objects, should cache!
    CGFloat floatIndex = [self nearestValidFloatIndex:self.floatIndex];
    [self.viewControllers enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *currentVC = (UIViewController *)obj;
        CGFloat leftPos = [self currentLeftInset];
        CGRect leftRect = idx > 0 ? [[frames objectAtIndex:idx-1] CGRectValue] : CGRectZero;
        
        if (idx == floorf(floatIndex)) {
            BOOL dockRight = ![self isFloatIndexBetween:floatIndex] && floatIndex >= 1.f;
            
            // should we pan it to the right?
            if (dockRight) {
                leftPos = [self screenWidth] - currentVC.containerView.frameWidth;
            }
        }else if (idx > floatIndex) {
            // connect vc to left vc's right!
            leftPos = leftRect.origin.x + leftRect.size.width;
        }
        
        CGRect currentRect = CGRectMake(leftPos, currentVC.containerView.frameTop, currentVC.containerView.frameWidth, currentVC.containerView.frameHeight);
        [frames addObject:[NSValue valueWithCGRect:currentRect]];
    }];
    [self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if(idx < floatIndex && idx < [self.viewControllers count] - 1) {
            CGRect crect = [[frames objectAtIndex:idx] CGRectValue];
            CGRect nrect = [[frames objectAtIndex:idx + 1] CGRectValue];
            
            CGFloat lpos = nrect.origin.x - crect.size.width;
            lpos = MAX(lpos, [self currentLeftInset]);
            
            CGRect newrect = CGRectMake(lpos, crect.origin.y, crect.size.width, crect.size.height);
            [frames replaceObjectAtIndex:idx withObject:[NSValue valueWithCGRect:newrect]];
        }
    }];
    
    return frames;
}

/// calculates the specific rect
- (CGRect)rectForControllerAtIndex:(NSUInteger)idx {
    NSArray *frames = [self rectsForControllers];
    return [[frames objectAtIndex:idx] CGRectValue];
}


/// moves a rect around, recalculates following rects
- (NSArray *)modifiedRects:(NSArray *)frames newLeft:(CGFloat)newLeft index:(NSUInteger)idx {
    NSMutableArray *modifiedFrames = [NSMutableArray arrayWithArray:frames];
    
    CGRect prevFrame;
    for (unsigned int i = idx; i < [modifiedFrames count]; i++) {
        CGRect vcFrame = [[modifiedFrames objectAtIndex:i] CGRectValue];
        if (i == idx) {
            vcFrame.origin.x = newLeft;
        }else {
            vcFrame.origin.x = prevFrame.origin.x + prevFrame.size.width;
        }
        [modifiedFrames replaceObjectAtIndex:i withObject:[NSValue valueWithCGRect:vcFrame]];
        prevFrame = vcFrame;
    }
    
    return modifiedFrames;
}

// at some point, dragging does not make any more sense
- (BOOL)snapPointAvailableAfterOffset:(NSInteger)offset {
    BOOL snapPointAvailableAfterOffset = YES;
    NSUInteger screenWidth = [self screenWidth];
    NSUInteger totalWidth = [self totalStackWidth];
    NSUInteger minCommonWidth = MIN(screenWidth, totalWidth);
    //    NSArray *frames = [self rectsForControllers];
    
    // are we at the end?
    UIViewController *topViewController = [self topViewController];
    if (topViewController == [self lastVisibleViewControllerCompletelyVisible:YES]) {
        if (minCommonWidth + [self minimalLeftInset] <= topViewController.containerView.frameRight) {
            snapPointAvailableAfterOffset = NO;
        }
    }
    
    // slow down first controller when dragged to the right
    if ([self canCollapseStack] == 0) {
        snapPointAvailableAfterOffset = NO;
    }
    
    if ([self firstViewController].containerView.frameLeft > self.largeLeftInset) {
        snapPointAvailableAfterOffset = NO;
    }
    
    return snapPointAvailableAfterOffset;
}

- (BOOL)displayViewControllerOnRightMost:(UIViewController *)vc animated:(BOOL)animated {
    NSUInteger idx = [self indexOfViewController:vc];
    if (idx != NSNotFound) {
        [self displayViewControllerIndexOnRightMost:idx animated:animated];
        return YES;
    }
    return NO;
}

// ensures index is on rightmost position
- (void)displayViewControllerIndexOnRightMost:(NSInteger)idx animated:(BOOL)animated; {
    // add epsilon to round indexes like 1.0 to 2.0, also -1.0 to -2.0
    CGFloat floatIndexOffset = idx - self.floatIndex;
    NSInteger indexOffset = ceilf(floatIndexOffset + (floatIndexOffset > 0 ? EPSILON : -EPSILON));
    if (indexOffset > 0) {
        [self collapseStack:indexOffset animated:animated];
    }else if(indexOffset < 0) {
        [self expandStack:indexOffset animated:animated];
    }
    
    // hide menu, if first VC is larger than available screen space with floatIndex = 0.0
    else if (index == 0 && [self.viewControllers count] /*&& [[self.viewControllers objectAtIndex:0] containerView].width >= ([self screenWidth] - self.leftInset)*/) {
        self.floatIndex = 0.5f;
        [self alignStackAnimated:YES];
    }
}

- (void)displayRootViewControllerAnimated:(BOOL)animated{
    
    self.floatIndex = 0.0f;
    [self alignStackAnimated:YES];
	
}

// iterates controllers and sets width (also, enlarges if requested width is larger than current width)
- (void)updateViewControllerSizes {
    CGFloat maxControllerView = [self maxControllerWidth];
    for (UIViewController *controller in self.viewControllers) {
        [controller.containerView limitToMaxWidth:maxControllerView];
    }
}

- (CGFloat)overlapRatio {
    CGFloat overlapRatio = 0.f;
    
    UIViewController *overlappedVC = [self overlappedViewController];
    if (overlappedVC) {
        UIViewController *rightVC = [self nextViewController:overlappedVC];
        PSSVLog(@"overlapping %@ with %@", NSStringFromCGRect(overlappedVC.containerView.frame), NSStringFromCGRect(rightVC.containerView.frame));
        overlapRatio = fabsf(overlappedVC.containerView.frameRight - rightVC.containerView.frameLeft)/overlappedVC.containerView.frameWidth;
    }
    return overlapRatio;
}

// updates view containers
- (void)updateViewControllerMasksAndShadow {   
    if (enableShadows_ == YES) {
        // only one!
        if ([self.viewControllers count] == 1) {
            //    [[self firstViewController].containerView addMaskToCorners:UIRectCornerAllCorners];
            self.firstViewController.containerView.shadow = PSSVSideLeft | PSSVSideRight;
        }else {
            // rounded corners on first and last controller
            [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                UIViewController *vc = (UIViewController *)obj;
                if (idx == 0) {
                    //[vc.containerView addMaskToCorners:UIRectCornerBottomLeft | UIRectCornerTopLeft];
                }else if(idx == [self.viewControllers count]-1) {
                    //        [vc.containerView addMaskToCorners:UIRectCornerBottomRight | UIRectCornerTopRight];
                    vc.containerView.shadow = PSSVSideLeft | PSSVSideRight;
                }else {
                    //      [vc.containerView removeMask];
                    vc.containerView.shadow = PSSVSideLeft | PSSVSideRight;
                }
            }];
        }
        
        // update alpha mask
        CGFloat overlapRatio = [self overlapRatio];
        UIViewController *overlappedVC = [self overlappedViewController];
        overlappedVC.containerView.darkRatio = MIN(overlapRatio, 1.f)/kAlphaReductRatio;
        
        // reset alpha ratio everywhere else
        for (UIViewController *vc in self.viewControllers) {
            if (vc != overlappedVC) {
                vc.containerView.darkRatio = 0.0f;
            }
        }
    }
}

- (NSArray *)visibleViewControllersSetFullyVisible:(BOOL)fullyVisible; {
    NSMutableArray *array = [NSMutableArray array];    
    [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([self isViewControllerVisible:obj completely:fullyVisible]) {
            [array addObject:obj];
        }
    }];
    
    return [[array copy] autorelease];
}


// check if there is any overlapping going on between VCs
- (BOOL)isViewController:(UIViewController *)leftViewController overlappingWith:(UIViewController *)rightViewController {
    NSParameterAssert(leftViewController);
    NSParameterAssert(rightViewController);
    
    // figure out which controller is the top one
    if ([self indexOfViewController:rightViewController] < [self indexOfViewController:leftViewController]) {
        PSSVLog(@"overlapping check flipped! fixing that...");
        UIViewController *tmp = rightViewController;
        rightViewController = leftViewController;
        leftViewController = tmp;
    }
    
    BOOL overlapping = leftViewController.containerView.frameRight > rightViewController.containerView.frameLeft;
    if (overlapping) {
        PSSVLog(@"overlap detected: %@ (%@) with %@ (%@)", leftViewController, NSStringFromCGRect(leftViewController.containerView.frame), rightViewController, NSStringFromCGRect(rightViewController.containerView.frame));
    }
    return overlapping;
}

// find the rightmost overlapping controller
- (UIViewController *)overlappedViewController {
    __block UIViewController *overlappedViewController = nil;
    
    [self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *currentViewController = (UIViewController *)obj;
        UIViewController *leftViewController = [self previousViewController:currentViewController];
        
        BOOL overlapping = NO;
        if (leftViewController && currentViewController) {
            overlapping = [self isViewController:leftViewController overlappingWith:currentViewController];
        }
        
        if (overlapping) {
            overlappedViewController = leftViewController;
            *stop = YES;
        }
    }];
    
    return overlappedViewController;
}

- (void)embedActiveViewControllers {
	[[self activeViewControllers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		UIViewController *vc = (UIViewController*)obj;
		
		if (![vc.containerView isControllerViewEmbedded]) {
			if (self.isRunningOnIOS4OrEarlier) [vc viewWillAppear:NO];
			[vc.containerView embedControllerView];
			if (self.isRunningOnIOS4OrEarlier) [vc viewDidAppear:NO];
		}
		
	}];
}

- (void)unembedInactiveViewControllers {
	[[self inactiveViewControllers] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		UIViewController *vc = (UIViewController*)obj;
		if ([vc.containerView isControllerViewEmbedded]) {
			if (self.isRunningOnIOS4OrEarlier) [vc viewWillDisappear:NO];
			[vc.containerView unembedControllerView];
			if (self.isRunningOnIOS4OrEarlier) [vc viewDidDisappear:NO];
		}
	}];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Touch Handling

- (void)stopStackAnimation {
    // remove all current animations
    //[self.view.layer removeAllAnimations];
    [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UIViewController *vc = (UIViewController *)obj;
        [vc.containerView.layer removeAllAnimations];
    }];
}

// moves the stack to a specific offset. 
- (void)moveStackWithOffset:(NSInteger)offset animated:(BOOL)animated userDragging:(BOOL)userDragging {
	if (self.viewControllers.count == 0) return;
    PSSVLog(@"moving stack on %d pixels (animated:%d, decellerating:%d)", offset, animated, userDragging);
	[self stopStackAnimation];
	if (offset > 0) {
		UIViewController *firstActiveVC = [[self activeViewControllers] objectAtIndex:0];
		UIViewController *targetCV = [self previousViewController:firstActiveVC];
		if (![targetCV.containerView isControllerViewEmbedded]) {
			if (self.isRunningOnIOS4OrEarlier) [targetCV viewWillAppear:NO];
			[targetCV.containerView embedControllerView];
			if (self.isRunningOnIOS4OrEarlier) [targetCV viewDidAppear:NO];
		}
	} else {
		UIViewController *lastActiveVC = [[self activeViewControllers] lastObject];
		UIViewController *targetCV = [self nextViewController:lastActiveVC];
		if (![targetCV.containerView isControllerViewEmbedded]) {
			if (self.isRunningOnIOS4OrEarlier) [targetCV viewWillAppear:NO];
			[targetCV.containerView embedControllerView];
			if (self.isRunningOnIOS4OrEarlier) [targetCV viewDidAppear:NO];
		}
	}
    
    // let the delegate know the user is moving the stack
    if (self.delegate && userDragging) {
        [self delegateDidPanViewController:self.topViewController byOffset:offset];
    }
    
    
    [UIView animateWithDuration:animated ? kPSSVStackAnimationDuration : 0.f delay:0.f options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
        
        // enumerate controllers from right to left
        // scroll each controller until we begin to overlap!
        __block BOOL isTopViewController = YES;
        [self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            UIViewController *currentViewController = (UIViewController *)obj;
            UIViewController *leftViewController = [self previousViewController:currentViewController];
            UIViewController *rightViewController = [self nextViewController:currentViewController];        
            NSInteger minimalLeftInset = [self minimalLeftInset];
            
            // we just move the top view controller
            NSInteger currentVCLeftPosition = currentViewController.containerView.frameLeft;
            if (isTopViewController) {
                currentVCLeftPosition += offset;
            }else {
                // make sure we're connected to the next controller!
                currentVCLeftPosition = rightViewController.containerView.frameLeft - currentViewController.containerView.frameWidth;
            }
            
            // prevent scrolling < minimal width (except for the top view controller - allow stupidness!)
            if (currentVCLeftPosition < minimalLeftInset && (!userDragging || (userDragging && !isTopViewController))) {
                currentVCLeftPosition = minimalLeftInset;
            }
            
            // a previous view controller is not allowed to overlap the next view controller.
            if (leftViewController && leftViewController.containerView.frameRight > currentVCLeftPosition) {
                NSInteger leftVCLeftPosition = currentVCLeftPosition - leftViewController.containerView.frameWidth;
                if (leftVCLeftPosition < minimalLeftInset) {
                    leftVCLeftPosition = minimalLeftInset;
                }
                leftViewController.containerView.frameLeft = leftVCLeftPosition;
            }
            
            if (enableDraggingPastInsets_ == NO)
            {
                int stackWidth = (!isTopViewController) ? 0 : (leftViewController) ? leftViewController.containerView.frameWidth : (rightViewController) ? rightViewController.containerView.frameWidth : 0;
                int padding  = 45;
                if ((int)(currentVCLeftPosition-stackWidth) <= (int)leftInset_ ) {
                    currentVCLeftPosition = leftInset_ + stackWidth;
                }
                else if ((int)(currentVCLeftPosition-stackWidth) >= (int)largeLeftInset_ + padding) {
                    //For a more natural
                    currentVCLeftPosition = largeLeftInset_ + stackWidth + padding;
                }
            }
            
            currentViewController.containerView.frameLeft = currentVCLeftPosition;
            
            isTopViewController = NO; // there can only be one.
        }];
        
        [self updateViewControllerMasksAndShadow];
        
        
        // special case, if we have overlapping controllers!
        // in this case underlying controllers are visible, but they are overlapped by another controller
        UIViewController *lastViewController = [self lastVisibleViewControllerCompletelyVisible:YES];
        // there may be no controller completely visible - use partly visible then
        if (!lastViewController) {
            NSArray *visibleViewControllers = self.visibleViewControllers;
            lastViewController = [visibleViewControllers count] ? [visibleViewControllers objectAtIndex:0] : nil;
        }
        
        // calculate float index
        NSUInteger newFirstVisibleIndex = lastViewController ? [self indexOfViewController:lastViewController] : 0;         
        CGFloat floatIndex = [self nearestValidFloatIndex:newFirstVisibleIndex]; // absolut value
        
        CGFloat overlapRatio = 0.f;
        UIViewController *overlappedVC = [self overlappedViewController];
        if (overlappedVC) {
            UIViewController *rightVC = [self nextViewController:overlappedVC];
            PSSVLog(@"overlapping %@ with %@", NSStringFromCGRect(overlappedVC.containerView.frame), NSStringFromCGRect(rightVC.containerView.frame));
            overlapRatio = fabsf(overlappedVC.containerView.frameRight - rightVC.containerView.frameLeft)/(overlappedVC.containerView.frameRight - ([self screenWidth] - rightVC.containerView.frameWidth));
        }
        
        // only update ratio if < 1 (else we move sth else)
        if (overlapRatio <= 1.f && overlapRatio > 0.f) {
            floatIndex += 0.5f + overlapRatio*0.5f; // fully overlapped = the .5 ratio!
        }else {
            // overlap ratio
            UIViewController *lastVC = [self.visibleViewControllers lastObject];
            UIViewController *prevVC = [self previousViewController:lastVC];
            if (lastVC && prevVC && lastVC.containerView.frameRight > [self screenWidth]) {
                overlapRatio = fabsf(([self screenWidth] - lastVC.containerView.frameLeft)/([self screenWidth] - (self.leftInset + prevVC.containerView.frameWidth)))*.5f;
                floatIndex += overlapRatio;
            }
        }
        
        // special case for menu
        if (floatIndex == 0.f) {
            CGFloat menuCollapsedRatio = (self.largeLeftInset - self.firstViewController.containerView.frameLeft)/(self.largeLeftInset - self.leftInset);
			CGFloat minMenuCollapsedRatio = MIN(0.5f, menuCollapsedRatio/2);
            menuCollapsedRatio = MAX(0.0f, minMenuCollapsedRatio);
            floatIndex += menuCollapsedRatio;
        }
        
        floatIndex_ = floatIndex;
    } completion:nil];
}

- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer {    
    CGPoint translatedPoint = [recognizer translationInView:self.view];
    UIGestureRecognizerState state = recognizer.state;
    
    // reset last offset if gesture just started
    if (state == UIGestureRecognizerStateBegan) {
        lastDragOffset_ = 0;
    }
    
    NSInteger offset = translatedPoint.x - lastDragOffset_;
    
    // if the move does not make sense (no snapping region), only use 1/2 offset
    BOOL snapPointAvailable = [self snapPointAvailableAfterOffset:offset];
    if (!snapPointAvailable) {
        PSSVLog(@"offset dividing/2 in effect");
        
        // we only want to move full pixels - but if we drag slowly, 1 get divided to zero.
        // so only omit every second event
        if (abs(offset) == 1) {
            if(!lastDragDividedOne_) {
                lastDragDividedOne_ = YES;
                offset = 0;
            }else {
                lastDragDividedOne_ = NO;
            }
        }else {
            offset = roundf(offset/2.f);
        }
    }
    [self moveStackWithOffset:offset animated:NO userDragging:YES];
    
    // set up designated drag destination
    if (state == UIGestureRecognizerStateBegan) {
        if (offset > 0) {
            lastDragOption_ = SVSnapOptionRight;
        }else {
            lastDragOption_ = SVSnapOptionLeft;
        }
    }else {
        // if there's a continuous drag in one direction, keep designation - else use nearest to snap.
        if ((lastDragOption_ == SVSnapOptionLeft && offset > 0) || (lastDragOption_ == SVSnapOptionRight && offset < 0)) {
            lastDragOption_ = SVSnapOptionNearest;
        }
    }
    
    // save last point to calculate new offset
    if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
        lastDragOffset_ = translatedPoint.x;
    }
    
    // perform snapping after gesture ended
    BOOL gestureEnded = state == UIGestureRecognizerStateEnded;
    if (gestureEnded) {
        
        if (lastDragOption_ == SVSnapOptionRight) {
            self.floatIndex = [self nearestValidFloatIndex:self.floatIndex round:PSSVRoundDown];
        }else if(lastDragOption_ == SVSnapOptionLeft) {
            self.floatIndex = [self nearestValidFloatIndex:self.floatIndex round:PSSVRoundUp];
        }else {
            self.floatIndex = [self nearestValidFloatIndex:self.floatIndex round:PSSVRoundNearest];
        }
        
        [self alignStackAnimated:YES];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SVStackRootController (Public)

- (NSInteger)indexOfViewController:(UIViewController *)viewController {
    __block NSUInteger idx = [self.viewControllers indexOfObject:viewController];
    if (idx == NSNotFound) {
        idx = [self.viewControllers indexOfObject:viewController.navigationController];
        if (idx == NSNotFound) {
            [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger indx, BOOL *stop) {
                if ([obj isKindOfClass:[UINavigationController class]] && ((UINavigationController *)obj).topViewController == viewController) {
                    idx = indx;
                    *stop = YES;
                }
            }];
        }
    }
    return idx;
}

- (UIViewController *)topViewController {
    return [self.viewControllers lastObject];
}

- (UIViewController *)firstViewController {
    return [self.viewControllers count] ? [self.viewControllers objectAtIndex:0] : nil;
}

- (NSArray *)visibleViewControllers {
    return [self visibleViewControllersSetFullyVisible:NO];
}

- (NSArray *)fullyVisibleViewControllers {
    return [self visibleViewControllersSetFullyVisible:YES];
}

- (NSArray*)inactiveViewControllers {
	CGRect screenBounds = [UIScreen mainScreen].bounds; 
	NSMutableArray *inactiveControllers = [NSMutableArray array];
	__block CGPoint point = CGPointZero;
	
	[self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		UIViewController *vc = (UIViewController*)obj;
		if (!vc.isViewLoaded || (vc.isViewLoaded && CGPointEqualToPoint(point, vc.containerView.frameOrigin)) || (vc.isViewLoaded && vc.containerView.frameLeft > CGRectGetMaxX(screenBounds))) {
			[inactiveControllers insertObject:vc atIndex:0];
		}
		point = vc.containerView.frameOrigin;
	}];
	
	return inactiveControllers;
}

- (NSArray*)activeViewControllers {
	CGRect screenBounds = [UIScreen mainScreen].bounds; 
	NSMutableArray *activeControllers = [NSMutableArray array];
	__block CGPoint point = CGPointZero;
	
	[self.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		UIViewController *vc = (UIViewController*)obj;
		if (vc.isViewLoaded && (!CGPointEqualToPoint(point, vc.containerView.frameOrigin)) && (vc.containerView.frameLeft < CGRectGetMaxX(screenBounds))) {
			[activeControllers insertObject:vc atIndex:0];
		}
		point = vc.containerView.frameOrigin;
	}];
	
	return activeControllers;
}


- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    [self pushViewController:viewController fromViewController:self.topViewController animated:animated];
}

- (void)pushViewController:(UIViewController *)viewController fromViewController:(UIViewController *)baseViewController animated:(BOOL)animated {    
    // figure out where to push, and if we need to get rid of some viewControllers
    if (baseViewController) {
        [self.viewControllers enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            UIViewController *baseVC = objc_getAssociatedObject(obj, kPSSVAssociatedBaseViewControllerKey);
            if (baseVC == baseViewController) {
                PSSVLog(@"BaseViewController found on index: %d", idx);
                UIViewController *parentVC = [self previousViewController:obj];
                if (parentVC) {
                    [self popToViewController:parentVC animated:animated];
                }else {
                    [self popToRootViewControllerAnimated:animated];
                }
                *stop = YES;
            }
        }];
        
        objc_setAssociatedObject(viewController, kPSSVAssociatedBaseViewControllerKey, baseViewController, OBJC_ASSOCIATION_ASSIGN); // associate weak
    }
	
	[self beginAddingTransitionForChildViewController:viewController];
	[self addChildViewController:viewController];
    
    PSSVLog(@"pushing with index %d on stack: %@ (animated: %d)", [self.viewControllers count], viewController, animated);    
    viewController.view.frameHeight = [self screenHeight];
    
    // get predefined stack width; query topViewController if we have a UINavigationController
    CGFloat stackWidth = viewController.stackWidth;
    if (stackWidth == 0.f && [viewController isKindOfClass:[UINavigationController class]]) {
        UIViewController *topVC = ((UINavigationController *)viewController).topViewController;
        stackWidth = topVC.stackWidth;
    }
    if (stackWidth > 0.f) {
        viewController.view.frameWidth = stackWidth;
    }
    
    // Starting out in portrait, right side up, we see a 20 pixel gap (for status bar???)
    viewController.view.frameTop = 0.f;
    
    [self delegateWillInsertViewController:viewController];
    
    // controller view is embedded into a container
    PSSVContainerView *container = [PSSVContainerView containerViewWithController:viewController];
    NSUInteger leftGap = [self totalStackWidth] + [self minimalLeftInset];    
    container.frameLeft = leftGap;
    container.frameWidth = viewController.view.frameWidth;
    container.autoresizingMask = UIViewAutoresizingFlexibleHeight; // width is not flexible!
    container.shadowWidth = defaultShadowWidth_;
    container.shadowAlpha = defaultShadowAlpha_;
    container.cornerRadius = cornerRadius_;
	[container addMaskToCorners:UIRectCornerAllCorners];
    [container limitToMaxWidth:[self maxControllerWidth]];
    PSSVLog(@"container frame: %@", NSStringFromCGRect(container.frame));
    
    // relay willAppear and add to subview
    if (self.isRunningOnIOS4OrEarlier) [viewController viewWillAppear:animated];
    
    if (animated) {
        container.alpha = 0.f;
        if (enableScalingFadeInOut_)
            container.transform = CGAffineTransformMakeScale(1.2f, 1.2f); // large but fade in
		if (enableAppearsFromRight_) {
			container.transform = CGAffineTransformMakeTranslation(leftGap, 0); // large but fade in
		}
    }
    
	if (self.floatingViewController) {
		[self.view insertSubview:container belowSubview:self.floatingViewController.view];
	} else {
		[self.view addSubview:container];
	}
    
    if (animated) {
        [UIView animateWithDuration:kPSSVStackAnimationPushDuration delay:0.f options:UIViewAnimationOptionAllowUserInteraction animations:^{
            container.alpha = 1.f;
			container.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
			[viewController didMoveToParentViewController:self];
			[self endAddingTransitionForChildViewController:viewController];
		}];
    }
    
    // properly sizes the scroll view contents (for table view scrolling)
    [container layoutIfNeeded];
    //container.width = viewController.view.width; // sync width (after it may has changed in layoutIfNeeded)
    
    if (self.isRunningOnIOS4OrEarlier) [viewController viewDidAppear:animated];
    [viewControllers_ addObject:viewController];
    
    // register stack controller
    objc_setAssociatedObject(viewController, kPSSVAssociatedStackViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
    
    [self updateViewControllerMasksAndShadow];
    [self displayViewControllerIndexOnRightMost:[self.viewControllers count]-1 animated:animated];
    [self delegateDidInsertViewController:viewController];
}

- (BOOL)popViewController:(UIViewController *)controller animated:(BOOL)animated {
    if (controller != self.topViewController) {
        return NO;
    } else {
        return [self popViewControllerAnimated:animated] == controller;
    }
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    PSSVLog(@"popping controller: %@ (#%d total, animated:%d)", [self topViewController], [self.viewControllers count], animated);
    
    UIViewController *lastController = [[[self topViewController] retain] autorelease];
    if (lastController) {
		
        [self delegateWillRemoveViewController:lastController];
		[self beginRemovingTransitionForChildViewController:lastController];
		[lastController willMoveToParentViewController:nil];
        
        // remove from view stack!
        PSSVContainerView *container = lastController.containerView;
		
        if (self.isRunningOnIOS4OrEarlier) [lastController viewWillDisappear:animated];
        
        PSSVSimpleBlock finishBlock = ^{
			[container removeFromSuperview];
            if (self.isRunningOnIOS4OrEarlier) [lastController viewDidDisappear:animated];
			[lastController removeFromParentViewController];
            [self delegateDidRemoveViewController:lastController];
			[self endRemovingTransitionForChildViewController:lastController];
			objc_setAssociatedObject(lastController, kPSSVAssociatedStackViewControllerKey, nil, OBJC_ASSOCIATION_ASSIGN);
        };
        
        if (animated) { // kPSSVStackAnimationDuration
            [UIView animateWithDuration:kPSSVStackAnimationPopDuration delay:0.f options:UIViewAnimationOptionBeginFromCurrentState animations:^(void) {
                lastController.containerView.alpha = 0.f;
                if (enableScalingFadeInOut_)
                    lastController.containerView.transform = CGAffineTransformMakeScale(0.8f, 0.8f); // make smaller while fading out
				if (enableAppearsFromRight_)
					lastController.containerView.transform = CGAffineTransformMakeTranslation(self.view.frameWidth - lastController.containerView.frameLeft, 0);
            } completion:^(BOOL finished) {
                // even with duration = 0, this doesn't fire instantly but on a future runloop with NSFireDelayedPerform, thus ugly double-check
                if (finished) {
                    finishBlock();
                }
            }];
        }
        else {
            finishBlock();
        }
        
        [viewControllers_ removeLastObject];        
                
        // realign view controllers
        [self updateViewControllerMasksAndShadow];
        [self alignStackAnimated:animated];
    }
    
    return lastController;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated; {
    NSMutableArray *array = [NSMutableArray array];
    while ([self.viewControllers count] > 0) {
        UIViewController *vc = [self popViewControllerAnimated:animated];
        [array addObject:vc];
    }
    return array;
}

// get view controllers that are in stack _after_ current view controller
- (NSArray *)viewControllersAfterViewController:(UIViewController *)viewController {
    NSParameterAssert(viewController);
    NSUInteger idx = [self indexOfViewController:viewController];
    if (NSNotFound == idx) {
        return nil;
    }
    
    NSArray *array = nil;
    // don't remove view controller we've been called with
    if ([self.viewControllers count] > idx + 1) {
        array = [self.viewControllers subarrayWithRange:NSMakeRange(idx + 1, [self.viewControllers count] - idx - 1)];
    }
    
    return array;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated; {
    NSParameterAssert(viewController);
    
    NSUInteger idx = [self indexOfViewController:viewController];
    if (NSNotFound == idx) {
        return nil;
    }
    PSSVLog(@"popping to index %d, from %d", idx, [self.viewControllers count]);
    
    NSArray *controllersToRemove = [self viewControllersAfterViewController:viewController];
    [controllersToRemove enumerateObjectsUsingBlock:^(id obj, NSUInteger indx, BOOL *stop) {
        [self popViewControllerAnimated:animated];
    }];
    
    return controllersToRemove;
}

- (NSArray *)controllersForClass:(Class)theClass {
    NSArray *controllers = [self.viewControllers filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject isKindOfClass:theClass] || ([evaluatedObject isKindOfClass:[UINavigationController class]] && [((UINavigationController *)evaluatedObject).topViewController isKindOfClass:theClass]);
    }]];
    return controllers;
}

// last visible index is calculated dynamically, depending on width of VCs
- (NSInteger)lastVisibleIndex {
    NSInteger lastVisibleIndex = self.firstVisibleIndex;
    
    NSUInteger currentLeftInset = [self currentLeftInset];
    NSInteger screenSpaceLeft = [self screenWidth] - currentLeftInset;
    while (screenSpaceLeft > 0 && lastVisibleIndex < (NSInteger)[self.viewControllers count]) {
        UIViewController *vc = [self.viewControllers objectAtIndex:lastVisibleIndex];
        screenSpaceLeft -= vc.containerView.frameWidth;
        
        if (screenSpaceLeft >= 0) {
            lastVisibleIndex++;
        }        
    }
    
    if (lastVisibleIndex > 0) {
        lastVisibleIndex--; // compensate for last failure
    }
    
    return lastVisibleIndex;
}

// returns +/- amount if grid is not aligned correctly
// + if view is too far on the right, - if too far on the left
- (CGFloat)gridOffsetByPixels {
    CGFloat gridOffset = 0;
    
    CGFloat firstVCLeft = self.firstViewController.containerView.frameLeft;
    
    // easiest case, controller is > then wide menu
    if (firstVCLeft > [self currentLeftInset] || firstVCLeft < [self currentLeftInset]) {
        gridOffset = firstVCLeft - [self currentLeftInset];
    }else {
        NSUInteger targetIndex = self.firstVisibleIndex; // default, abs(gridOffset) < 1
        
        UIViewController *overlappedVC = [self overlappedViewController];
        if (overlappedVC) {
            UIViewController *rightVC = [self nextViewController:overlappedVC];
            targetIndex = [self indexOfViewController:rightVC];
            PSSVLog(@"overlapping %@ with %@", NSStringFromCGRect(overlappedVC.containerView.frame), NSStringFromCGRect(rightVC.containerView.frame));
        }
        
        UIViewController *targetVCController = [self.viewControllers objectAtIndex:targetIndex];
        CGRect targetVCFrame = [self rectForControllerAtIndex:targetIndex];
        gridOffset = targetVCController.containerView.frameLeft - targetVCFrame.origin.x;
    }
    
    PSSVLog(@"gridOffset: %f", gridOffset);
    return gridOffset;
}

/// detect if last drag offset is large enough that we should make a snap animation
- (BOOL)shouldSnapAnimate {
    BOOL shouldSnapAnimate = abs(lastDragOffset_) > 10;
    return shouldSnapAnimate;
}

// bouncing is a three-way operation
enum {
    PSSVBounceNone,
    PSSVBounceMoveToInitial,
    PSSVBounceBleedOver,
    PSSVBounceBack,    
}typedef PSSVBounceOption;

- (void)alignStackAnimated:(BOOL)animated duration:(CGFloat)duration bounceType:(PSSVBounceOption)bounce {	
    animated = animated && !self.isReducingAnimations; // don't animate if set
    self.floatIndex = [self nearestValidFloatIndex:self.floatIndex]; // round to nearest correct index
    UIViewAnimationCurve animationCurve = UIViewAnimationCurveEaseInOut;
    if (animated) {
        if (bounce == PSSVBounceMoveToInitial) {
            if ([self shouldSnapAnimate]) {
                animationCurve = UIViewAnimationCurveLinear;
            }
            CGFloat gridOffset = [self gridOffsetByPixels];
            snapBackFromLeft_ = gridOffset < 0;
            
            // some magic numbers to better reflect movement time
            duration = abs(gridOffset)/200.f * duration * 0.4f + duration * 0.6f;
        }else if(bounce == PSSVBounceBleedOver) {
            animationCurve = UIViewAnimationCurveEaseOut;
        }
    }
    
    PSSVSimpleBlock alignmentBlock = ^{
        
        PSSVLog(@"Begin aliging VCs. Last drag offset:%d direction:%d bounce:%d.", lastDragOffset_, lastDragOption_, bounce);
        
        // calculate offset used only when we're bleeding over
        NSInteger snapOverOffset = 0; // > 0 = <--- ; we scrolled from right to left.
        NSUInteger firstVisibleIndex = [self firstVisibleIndex];
        NSUInteger lastFullyVCIndex = [self indexOfViewController:[self lastVisibleViewControllerCompletelyVisible:YES]];
        BOOL bounceAtVeryEnd = NO;
        
        if ([self shouldSnapAnimate] && bounce == PSSVBounceBleedOver) {
            snapOverOffset = abs(lastDragOffset_ / 5.f);
            if (snapOverOffset > kPSSVMaxSnapOverOffset) {
                snapOverOffset = kPSSVMaxSnapOverOffset;
            }
            
            // positive/negative snap offset depending on snap back direction
            snapOverOffset *= snapBackFromLeft_ ? 1 : -1;
            
            // if we're dragging menu all the way out, bounce back in
            PSSVLog(@"%@", NSStringFromCGRect(self.firstViewController.containerView.frame));
            CGFloat firstVCLeft = self.firstViewController.containerView.frameLeft;
            if (firstVisibleIndex == 0 && !snapBackFromLeft_ && firstVCLeft >= self.largeLeftInset) {
                bounceAtVeryEnd = YES;
            }else if(lastFullyVCIndex == [self.viewControllers count]-1 && lastFullyVCIndex > 0) {
                bounceAtVeryEnd = YES;
            }
            
            PSSVLog(@"bouncing with offset: %d, firstIndex:%d, snapToLeft:%d veryEnd:%d", snapOverOffset, firstVisibleIndex, snapOverOffset<0, bounceAtVeryEnd);
        }
        
        // iterate over all view controllers and snap them to their correct positions
        __block NSArray *frames = [self rectsForControllers];
        [self.viewControllers enumerateObjectsWithOptions:0 usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            UIViewController *currentVC = (UIViewController *)obj;
            
            CGRect currentFrame = [[frames objectAtIndex:idx] CGRectValue];
            currentVC.containerView.frameLeft = currentFrame.origin.x;
            
            // menu drag to right case or swiping last vc towards menu
            if (bounceAtVeryEnd) {
                if (idx == firstVisibleIndex) {
                    frames = [self modifiedRects:frames newLeft:currentVC.containerView.frameLeft + snapOverOffset index:idx];
                }
            }
            // snap the leftmost view controller
            else if ((snapOverOffset > 0 && idx == firstVisibleIndex) || (snapOverOffset < 0 && (idx == firstVisibleIndex+1))
                     || [self.viewControllers count] == 1) {
                frames = [self modifiedRects:frames newLeft:currentVC.containerView.frameLeft + snapOverOffset index:idx];
            }
            
            // set again (maybe changed)
            currentFrame = [[frames objectAtIndex:idx] CGRectValue];
            currentVC.containerView.frameLeft = currentFrame.origin.x;
        }];
		
		[self embedActiveViewControllers];
        
        [self updateViewControllerMasksAndShadow];
        
    };
    
    if (animated) {
        [UIView animateWithDuration:duration delay:0.f
                            options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState | animationCurve
                         animations:alignmentBlock completion:^(BOOL finished) {
                             /*  Scroll physics are applied here. Drag speed is saved in lastDragOffset. (direction with +/-, speed)
                              *  If we are above a certain speed, we "shoot over the target", then snap back. 
                              *  This is of course dependent on the direction we scrolled.
                              *
                              *  Right swiping (collapsing) makes the next vc overlapping the current vc a few pixels.
                              *  Left swiping (expanding) takes the parent controller a few pixels with, then snapping back.
                              *
                              *  We have 3 animations total
                              *   1) scroll to correct position
                              *   2) bleed over
                              *   3) snap back to correct position
                              */        
                             if (finished && [self shouldSnapAnimate]) {
                                 CGFloat animationDuration = kPSSVStackAnimationBounceDuration/2.f;
                                 switch (bounce) {
                                     case PSSVBounceMoveToInitial: {
                                         // bleed over now!
                                         [self alignStackAnimated:YES duration:animationDuration bounceType:PSSVBounceBleedOver];
                                     }break;
                                     case PSSVBounceBleedOver: {
                                         // now bounce back to origin
                                         [self alignStackAnimated:YES duration:animationDuration bounceType:PSSVBounceBack];
                                     }break;
                                         
                                     case PSSVBounceNone:
                                         [self delegateDidAlign];
                                     case PSSVBounceBack:
                                         [self delegateDidAlign];
										 
                                     default: {
                                         lastDragOffset_ = 0; // clear last drag offset for the animation
                                         //[self removeAnimationBlockerView];
                                     }break;
                                 }
                             }else if(finished){
                                 
                                 [self delegateDidAlign];
								 
                             }
							 
							 [self unembedInactiveViewControllers];
                         }
         ];
    }
    else {
        alignmentBlock();
        //[self delegateDidAlign];
    }
    NSLog(@"activeViewControllers = %@\n", [self activeViewControllers]);
}

- (void)alignStackAnimated:(BOOL)animated; {
    if([self enableBounces]) {
        [self alignStackAnimated:animated duration:kPSSVStackAnimationDuration bounceType:PSSVBounceMoveToInitial];
    }
    else {
        [self alignStackAnimated:animated duration:kPSSVStackAnimationDuration bounceType:PSSVBounceNone];
    }
}

- (NSUInteger)canCollapseStack; {
    NSUInteger steps = [self.viewControllers count] - self.firstVisibleIndex - 1;
    
    if (self.lastVisibleIndex == (NSInteger)[self.viewControllers count]-1) {
        //PSSVLog(@"complete stack is displayed - aborting.");
        steps = 0;
    }else if (self.firstVisibleIndex + steps > [self.viewControllers count]-1) {
        steps = [self.viewControllers count] - self.firstVisibleIndex - 1;
        //PSSVLog(@"too much steps, adjusting to %d", steps);
    }
    
    return steps;
}


- (NSUInteger)collapseStack:(NSInteger)steps animated:(BOOL)animated; { // (<--- increases firstVisibleIndex)
    PSSVLog(@"collapsing stack with %d steps [%d-%d]", steps, self.firstVisibleIndex, self.lastVisibleIndex);
    
    CGFloat newFloatIndex = self.floatIndex;
    while (steps > 0) {
        newFloatIndex = [self nextFloatIndex:newFloatIndex];
        steps--;
    }
    
    if (newFloatIndex > 0.f) {
        self.floatIndex = MAX(newFloatIndex, self.floatIndex);
    }
    
    [self alignStackAnimated:animated];
    return steps;
}


- (NSUInteger)canExpandStack; {
    NSUInteger steps = self.firstVisibleIndex;
    
    // sanity check
    if (steps >= [self.viewControllers count]-1) {
        PSSVLog(@"Warning: firstVisibleIndex is higher than viewController count!");
        steps = [self.viewControllers count]-1;
    }
    
    return steps;
}

- (NSUInteger)expandStack:(NSInteger)steps animated:(BOOL)animated; { // (---> decreases firstVisibleIndex)
    steps = abs(steps); // normalize
    PSSVLog(@"expanding stack with %d steps [%d-%d]", steps, self.firstVisibleIndex, self.lastVisibleIndex);
    
    CGFloat newFloatIndex = self.floatIndex;
    while (steps > 0) {
        newFloatIndex = [self prevFloatIndex:newFloatIndex];
        steps--;
    }
    
    self.floatIndex = MIN(newFloatIndex, self.floatIndex);
    
    [self alignStackAnimated:animated];
    return steps; 
}

- (void)setNumberOfTouches:(NSUInteger)numberOfTouches
{
    numberOfTouches_ = numberOfTouches;
    [self configureGestureRecognizer];
}

- (void)setLeftInset:(NSUInteger)leftInset {
    [self setLeftInset:leftInset animated:NO];
}

- (void)setLeftInset:(NSUInteger)leftInset animated:(BOOL)animated; {
    leftInset_ = leftInset;
    [self alignStackAnimated:animated];
}

- (void)setLargeLeftInset:(NSUInteger)leftInset {
    [self setLargeLeftInset:leftInset animated:NO];
}

- (void)setLargeLeftInset:(NSUInteger)leftInset animated:(BOOL)animated; {
    largeLeftInset_ = leftInset;
    [self alignStackAnimated:animated];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIView

- (void)viewDidLoad {
    [super viewDidLoad];
	
	if (self.createdWithAlloc) {
		[self embedSubviews];
	}
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
	if (self.rootViewController.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
		[self.rootViewController viewWillAppear:animated];
	}
    
    for (UIViewController *controller in self.viewControllers) {
		if (controller.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
			[controller viewWillAppear:animated];
		}
    }
	if (self.floatingViewController.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
		[self.floatingViewController viewWillAppear:animated];
	}
    
    // enlarge/shrinken stack
    [self updateViewControllerSizes];
    [self updateViewControllerMasksAndShadow];    
    [self alignStackAnimated:NO];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
	if (self.rootViewController.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
		[self.rootViewController viewDidAppear:animated];
	}
    for (UIViewController *controller in self.viewControllers) {
		if (controller.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
			[controller viewDidAppear:animated];
		}
    }
	if (self.floatingViewController.isViewLoaded && self.isRunningOnIOS4OrEarlier) {
		[self.floatingViewController viewDidAppear:animated];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.isRunningOnIOS4OrEarlier) [self.rootViewController viewWillDisappear:animated];
    for (UIViewController *controller in self.viewControllers) {
        if (self.isRunningOnIOS4OrEarlier) [controller viewWillDisappear:animated];
    }
	if (self.isRunningOnIOS4OrEarlier) [self.floatingViewController viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    if (self.isRunningOnIOS4OrEarlier) [self.rootViewController viewDidDisappear:animated];
    for (UIViewController *controller in self.viewControllers) {
        if (self.isRunningOnIOS4OrEarlier) [controller viewDidDisappear:animated];
    }
	if (self.isRunningOnIOS4OrEarlier) [self.floatingViewController viewDidDisappear:animated];
}

- (void)viewDidUnload {
    [self.rootViewController.view removeFromSuperview];
    self.rootViewController.view = nil;
    [self.rootViewController viewDidUnload];
    
    for (UIViewController *controller in self.viewControllers) {
        [controller.view removeFromSuperview];
        controller.view = nil;
        [controller viewDidUnload];
    }
	
	[self.floatingViewController.view removeFromSuperview];
    self.floatingViewController.view = nil;
    [self.floatingViewController viewDidUnload];
    
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    if (PSIsIpad()) {
        return YES;
    }else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

// event relay
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    //lastVisibleIndexBeforeRotation_ = self.lastVisibleIndex;
    
	
	[rootViewController_ willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	if (self.isRunningOnIOS4OrEarlier) {
		for (UIViewController *controller in self.viewControllers) {
			[controller willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
		}
	}
	
	[floatingViewController_ willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
}

// event relay
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [rootViewController_ didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    
    if (self.isReducingAnimations) {
        [self updateViewControllerSizes];
        [self updateViewControllerMasksAndShadow];
    }
    
	if (self.isRunningOnIOS4OrEarlier) {
		for (UIViewController *controller in self.viewControllers) {
			[controller didRotateFromInterfaceOrientation:fromInterfaceOrientation];
		}
	}
	
	[floatingViewController_ didRotateFromInterfaceOrientation:fromInterfaceOrientation];
	
    // ensure we're correctly aligned (may be messed up in willAnimate, if panRecognizer is still active)
    [self alignStackAnimated:!self.isReducingAnimations];
}

// event relay
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [rootViewController_ willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if (!self.isReducingAnimations) {
        [self updateViewControllerSizes];
        [self updateViewControllerMasksAndShadow];    
    }
    
	if (self.isRunningOnIOS4OrEarlier) {
		// finally relay rotation events
		for (UIViewController *controller in self.viewControllers) {
			[controller willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
		}
	}
	
	[floatingViewController_ willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // enlarge/shrinken stack
    [self alignStackAnimated:!self.isReducingAnimations];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) {
        // prevent recognizing touches on the slider
        return NO;
    }
    return YES;
}


@end



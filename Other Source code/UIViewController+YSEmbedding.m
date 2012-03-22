//
//  UIViewController+YSEmbedding.m
//  PSStackedViewExample
//
//  Created by Marc Palluat de Besset on 22/03/2012.
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <objc/runtime.h>

#import "UIViewController+YSEmbedding.h"


static void AddMethod( SEL selector, NSString *name );
static void SwizzleMethod( SEL selector, SEL otherSelector );


#define kYSAssociatedChildViewControllerAddingKey @"YSAssociatedChildViewControllerAdding"
#define kYSAssociatedChildViewControllerRemovingKey @"kAssociatedChildViewControllerRemoving"
#define kYSAssociatedChildViewControllersKey @"kAssociatedChildViewControllers"
#define kYSAssociatedParentViewControllerKey @"kAssociatedParentViewController"


@implementation UIViewController (YSEmbedding)

@dynamic isRunningOnIOS4OrEarlier, childViewControllers;

+ (BOOL)isRunningOnIOS4OrEarlier {
	static BOOL flag = NO;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		flag = ![self instancesRespondToSelector:NSSelectorFromString(@"automaticallyForwardAppearanceAndRotationMethodsToChildViewControllers")];
		
	});
	return flag;
}

- (BOOL)isRunningOnIOS4OrEarlier {
	return [[self class] isRunningOnIOS4OrEarlier];
}

- (void)beginAddingTransitionForChildViewController:(UIViewController*)childController {
	if (self.isRunningOnIOS4OrEarlier) {
		objc_setAssociatedObject(childController, kYSAssociatedChildViewControllerAddingKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN);
	}
}

- (void)endAddingTransitionForChildViewController:(UIViewController*)childController {
	if (self.isRunningOnIOS4OrEarlier) {
		objc_setAssociatedObject(childController, kYSAssociatedChildViewControllerAddingKey, nil, OBJC_ASSOCIATION_RETAIN);
	}
}

- (void)beginRemovingTransitionForChildViewController:(UIViewController*)childController {
	if (self.isRunningOnIOS4OrEarlier) {
		objc_setAssociatedObject(childController, kYSAssociatedChildViewControllerRemovingKey, [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN);
	}
}

- (void)endRemovingTransitionForChildViewController:(UIViewController*)childController {
	if (self.isRunningOnIOS4OrEarlier) {
		objc_setAssociatedObject(childController, kYSAssociatedChildViewControllerRemovingKey, nil, OBJC_ASSOCIATION_RETAIN);
	}
}

- (NSArray*)imp_childViewControllers {
	NSArray *children = objc_getAssociatedObject(self, kYSAssociatedChildViewControllersKey);
	if (children) return [[children copy] autorelease];
	return [NSArray array];
}

- (void)imp_willMoveToParentViewController:(UIViewController *)parent {}
- (void)imp_didMoveToParentViewController:(UIViewController *)parent {}

- (BOOL)imp_isMovingFromParentViewController {
	NSNumber *flag = objc_getAssociatedObject(self, kYSAssociatedChildViewControllerRemovingKey);
	if (flag) {
		return [flag boolValue];
	}
	return NO;
}

- (BOOL)imp_isMovingToParentViewController {
	NSNumber *flag = objc_getAssociatedObject(self, kYSAssociatedChildViewControllerAddingKey);
	if (flag) {
		return [flag boolValue];
	}
	return NO;
}

- (UIViewController*)imp_parentViewController {
	UIViewController *parent = [self imp_parentViewController];
	if (parent) return parent;
	else {
		return objc_getAssociatedObject(self, kYSAssociatedParentViewControllerKey);
	}
	return nil;
}

- (void)imp_addChildViewController:(UIViewController *)childController {
	if (childController.parentViewController) {
		[childController removeFromParentViewController];
	}
	
	[childController willMoveToParentViewController:self];
	
	NSMutableArray *children = objc_getAssociatedObject(self, kYSAssociatedChildViewControllersKey);
	if (!children) {
		children = [NSMutableArray array];
		objc_setAssociatedObject(self, kYSAssociatedChildViewControllersKey, children, OBJC_ASSOCIATION_RETAIN);
	}
	
	[children addObject:childController];
	objc_setAssociatedObject(childController, kYSAssociatedParentViewControllerKey, self, OBJC_ASSOCIATION_ASSIGN);
}

- (void)imp_removeChildViewController:(UIViewController*)childController {
	NSMutableArray *children = objc_getAssociatedObject(self, kYSAssociatedChildViewControllersKey);
	if (children) {
		[childController retain];
		[children removeObject:childController];
		[childController didMoveToParentViewController:nil];
		[childController release];
	}
}

- (void)imp_removeFromParentViewController {
	[self.parentViewController performSelector:NSSelectorFromString(@"removeChildViewController:") withObject:self];
}

@end



static void AddMethod( SEL selector, NSString *name ) {
	Method method = class_getInstanceMethod([UIViewController class], selector);
    const char *types = method_getTypeEncoding(method);
	IMP address = method_getImplementation(method);
	
	class_addMethod([UIViewController class], NSSelectorFromString(name), address, types);
}

static void SwizzleMethod( SEL selector, SEL otherSelector ) {
	Method origMethod = class_getInstanceMethod([UIViewController class], selector);
	Method overrideMethod = class_getInstanceMethod([UIViewController class], otherSelector);
	method_exchangeImplementations(origMethod, overrideMethod);
}

/*
 This function adds the following methods to UIViewController when running on IOS 4 :
 
 - (void)willMoveToParentViewController:(UIViewController *)parent;
 - (void)didMoveToParentViewController:(UIViewController *)parent;
 - (void)removeFromParentViewController;
 - (BOOL)isMovingFromParentViewController;
 - (BOOL)isMovingToParentViewController;
 
 It changes the implementation of  - (UIViewController*)parentViewController;
 
 It also adds the following methods to self :
 
 - (NSArray*)childViewControllers;
 - (void)addChildViewController:(UIViewController *)childController;
 - (void)removeChildViewController:(UIViewController*)childController;
  */

static void __attribute__ ((constructor)) ImplementContainerAPI(void) {
	if ([UIViewController isRunningOnIOS4OrEarlier]) {
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			AddMethod( NSSelectorFromString(@"imp_childViewControllers"), @"childViewControllers" );
			AddMethod( NSSelectorFromString(@"imp_addChildViewController:"), @"addChildViewController:" );
			AddMethod( NSSelectorFromString(@"imp_removeChildViewController:"), @"removeChildViewController:" );
			AddMethod( NSSelectorFromString(@"imp_willMoveToParentViewController:"), @"willMoveToParentViewController:" );
			AddMethod( NSSelectorFromString(@"imp_didMoveToParentViewController:"), @"didMoveToParentViewController:" );
			SwizzleMethod( NSSelectorFromString(@"imp_parentViewController"), NSSelectorFromString(@"parentViewController"));
			AddMethod( NSSelectorFromString(@"imp_removeFromParentViewController"), @"removeFromParentViewController" );
			AddMethod( NSSelectorFromString(@"imp_isMovingFromParentViewController"), @"isMovingFromParentViewController" );
			AddMethod( NSSelectorFromString(@"imp_isMovingToParentViewController"), @"isMovingToParentViewController" );
		});
	}
}

//
//  UIViewController+YSEmbedding.h
//  PSStackedViewExample
//
//  Created by Marc Palluat de Besset on 22/03/2012.
//  Copyright (c) 2012 Peter Steinberger. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (YSEmbedding)

@property (nonatomic, readonly) BOOL isRunningOnIOS4OrEarlier;
@property (nonatomic, readonly) NSArray *childViewControllers;

+ (BOOL)isRunningOnIOS4OrEarlier;

// These methods should be called from the implementation of container view controllers
- (void)beginAddingTransitionForChildViewController:(UIViewController*)childController;
- (void)endAddingTransitionForChildViewController:(UIViewController*)childController;

- (void)beginRemovingTransitionForChildViewController:(UIViewController*)childController;
- (void)endRemovingTransitionForChildViewController:(UIViewController*)childController;




@end

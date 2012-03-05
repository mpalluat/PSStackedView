//
//  UIView+YSGeometry.h
//  YellSearch
//
//  Created by Marc Palluat de Besset on 23/06/2011.
//  Copyright 2011 Yell. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^frame_block_t)(CGRect *frame);
typedef void(^bounds_block_t)(CGRect *bounds);
typedef void(^center_block_t)(CGPoint *center);

@interface UIView (YSGeometry)

- (void)setFrameUsingBlock:(frame_block_t)block;
- (void)setBoundsUsingBlock:(bounds_block_t)block;
- (void)setCenterUsingBlock:(center_block_t)block;


// frame
@property (nonatomic, assign) CGPoint frameOrigin;
@property (nonatomic, assign) CGSize frameSize;

@property (nonatomic, assign) CGFloat frameLeft;
@property (nonatomic, assign) CGFloat frameRight;
@property (nonatomic, assign) CGFloat frameTop;
@property (nonatomic, assign) CGFloat frameBottom;
@property (nonatomic, assign) CGFloat frameWidth;
@property (nonatomic, assign) CGFloat frameHeight;


// bounds
@property (nonatomic, assign) CGPoint boundsOrigin;
@property (nonatomic, assign) CGSize boundsSize;

@property (nonatomic, assign) CGFloat boundsLeft;
@property (nonatomic, assign) CGFloat boundsRight;
@property (nonatomic, assign) CGFloat boundsTop;
@property (nonatomic, assign) CGFloat boundsBottom;
@property (nonatomic, assign) CGFloat boundsWidth;
@property (nonatomic, assign) CGFloat boundsHeight;

// center
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;


- (void)centerFrameIntoFrame:(CGRect)frame;

@end

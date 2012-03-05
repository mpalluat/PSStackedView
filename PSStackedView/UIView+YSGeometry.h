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
- (CGPoint)frameOrigin;
- (void)setFrameOrigin:(CGPoint)origin;

- (CGSize)frameSize;
- (void)setFrameSize:(CGSize)size;

- (CGFloat)frameLeft;
- (void)setFrameLeft:(CGFloat)left;

- (CGFloat)frameRight;
- (void)setFrameRight:(CGFloat)right;

- (CGFloat)frameTop;
- (void)setFrameTop:(CGFloat)top;

- (CGFloat)frameBottom;
- (void)setFrameBottom:(CGFloat)bottom;

- (CGFloat)frameWidth;
- (void)setFrameWidth:(CGFloat)width;

- (CGFloat)frameHeight;
- (void)setFrameHeight:(CGFloat)height;

// bounds
- (CGPoint)boundsOrigin;
- (void)setBoundsOrigin:(CGPoint)origin;

- (CGSize)boundsSize;
- (void)setBoundsSize:(CGSize)size;

- (CGFloat)boundsLeft;
- (void)setBoundsLeft:(CGFloat)left;

- (CGFloat)boundsRight;
- (void)setBoundsRight:(CGFloat)right;

- (CGFloat)boundsTop;
- (void)setBoundsTop:(CGFloat)top;

- (CGFloat)boundsBottom;
- (void)setBoundsBottom:(CGFloat)bottom;

- (CGFloat)boundsWidth;
- (void)setBoundsWidth:(CGFloat)width;

- (CGFloat)boundsHeight;
- (void)setBoundsHeight:(CGFloat)height;

// center
- (CGFloat)centerX;
- (void)setCenterX:(CGFloat)x;

- (CGFloat)centerY;
- (void)setCenterY:(CGFloat)y;

- (void)centerFrameIntoFrame:(CGRect)frame;

@end

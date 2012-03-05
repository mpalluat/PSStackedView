//
//  UIView+YSGeometry.m
//  YellSearch
//
//  Created by Marc Palluat de Besset on 23/06/2011.
//  Copyright 2011 Yell. All rights reserved.
//

#import "UIView+YSGeometry.h"


@implementation UIView (YSGeometry)

- (void)setFrameUsingBlock:(frame_block_t)block {
	CGRect frame = self.frame;
	block(&frame);
	self.frame = frame;
}

- (void)setBoundsUsingBlock:(bounds_block_t)block {
	CGRect bounds = self.bounds;
	block(&bounds);
	self.bounds = bounds;
}

- (void)setCenterUsingBlock:(center_block_t)block {
	CGPoint center = self.center;
	block(&center);
	self.center = center;
}

- (CGPoint)frameOrigin {
    return self.frame.origin;
}

- (void)setFrameOrigin:(CGPoint)origin {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->origin = origin;
	}];
}

- (CGSize)frameSize {
    return self.frame.size;
}

- (void)setFrameSize:(CGSize)size {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->size = size;
	}];
}

- (CGFloat)frameLeft {
    return self.frame.origin.x;
}

- (void)setFrameLeft:(CGFloat)left {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->origin.x = left;
	}];
}

- (CGFloat)frameRight {
    return CGRectGetMaxX(self.frame);
}

- (void)setFrameRight:(CGFloat)right {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->origin.x = right - CGRectGetWidth(*frame);
	}];
}

- (CGFloat)frameTop {
    return self.frame.origin.y;
}

- (void)setFrameTop:(CGFloat)top {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->origin.y = top;
	}];
}

- (CGFloat)frameBottom {
    return CGRectGetMaxY(self.frame);
}

- (void)setFrameBottom:(CGFloat)bottom {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->origin.y = bottom - CGRectGetHeight(*frame);
	}];
}

- (CGFloat)frameWidth {
    return CGRectGetWidth(self.frame);
}

- (void)setFrameWidth:(CGFloat)width {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->size.width = width;
	}];
}

- (CGFloat)frameHeight {
    return CGRectGetHeight(self.frame);
}

- (void)setFrameHeight:(CGFloat)height {
	[self setFrameUsingBlock:^(CGRect *frame) {
		frame->size.height = height;
	}];
}




- (CGPoint)boundsOrigin {
    return self.bounds.origin;
}

- (void)setBoundsOrigin:(CGPoint)origin {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->origin = origin;
	}];
}

- (CGSize)boundsSize {
    return self.bounds.size;
}

- (void)setBoundsSize:(CGSize)size {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->size = size;
	}];
}

- (CGFloat)boundsLeft {
    return self.bounds.origin.x;
}

- (void)setBoundsLeft:(CGFloat)left {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->origin.x = left;
	}];

}

- (CGFloat)boundsRight {
    return CGRectGetMaxX(self.bounds);
}

- (void)setBoundsRight:(CGFloat)right {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->origin.x = right - CGRectGetWidth(*bounds);
	}];
}

- (CGFloat)boundsTop {
    return self.bounds.origin.y;
}

- (void)setBoundsTop:(CGFloat)top {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->origin.y = top;
	}];
}

- (CGFloat)boundsBottom {
    return CGRectGetMaxY(self.bounds);
}

- (void)setBoundsBottom:(CGFloat)bottom {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->origin.y = bottom - CGRectGetHeight(*bounds);
	}];
}

- (CGFloat)boundsWidth {
    return CGRectGetWidth(self.bounds);
}

- (void)setBoundsWidth:(CGFloat)width {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->size.width = width;
	}];
}

- (CGFloat)boundsHeight {
    return CGRectGetHeight(self.bounds);
}

- (void)setBoundsHeight:(CGFloat)height {
	[self setBoundsUsingBlock:^(CGRect *bounds) {
		bounds->size.height = height;
	}];
}

- (CGFloat)centerX {
	return self.center.x;
}

- (void)setCenterX:(CGFloat)x {
	[self setCenterUsingBlock:^(CGPoint *center) {
		center->x = x;
	}];
}

- (CGFloat)centerY {
	return self.center.y;
}

- (void)setCenterY:(CGFloat)y {
	[self setCenterUsingBlock:^(CGPoint *center) {
		center->y = y;
	}];
}


- (void)centerFrameIntoFrame:(CGRect)frame {
    CGRect myFrame = self.frame;
    self.frame = CGRectMake( CGRectGetMidX(frame) - CGRectGetWidth(myFrame) / 2.0f, CGRectGetMidY(frame) - CGRectGetHeight(myFrame) / 2.0f, CGRectGetWidth(myFrame), CGRectGetHeight(myFrame));
}


@end

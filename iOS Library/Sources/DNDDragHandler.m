//
//  DNDDragHandler.m
//  ios-drag-and-drop
//
//  Created by Markus Gasser on 3/1/13.
//  Copyright (c) 2013 Team RG. All rights reserved.
//

#import "DNDDragHandler.h"
#import "DNDDragAndDropController_Private.h"
#import "DNDDragOperation_Private.h"


@interface DNDDragHandler ()

@property (nonatomic, strong) UIPanGestureRecognizer *dragRecognizer;
@property (nonatomic, strong) DNDDragOperation *currentDragOperation;

@end


@implementation DNDDragHandler

#pragma mark - Initialization

- (instancetype)initWithController:(DNDDragAndDropController *)controller sourceView:(UIView *)source delegate:(id<DNDDragSourceDelegate>)delegate {
    NSParameterAssert(controller != nil);
    NSParameterAssert(source != nil);
    NSParameterAssert(delegate != nil);
    
    if ((self = [super init])) {
        _controller = controller;
        _dragSourceView = source;
        _dragDelegate = delegate;
        _dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragGesture:)];
        _dragRecognizer.maximumNumberOfTouches = 1;
        [_dragSourceView addGestureRecognizer:_dragRecognizer];
    }
    return self;
}

- (void)dealloc {
    [_dragSourceView removeGestureRecognizer:_dragRecognizer];
}


#pragma mark - Handling the Drag Gesture

- (void)handleDragGesture:(UIGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        [self beginDraggingForGestureRecognizer:recognizer];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        [self updateDraggingForGestureRecognizer:recognizer];
    } else {
        [self finishDraggingForGestureRecognizer:recognizer];
    }
}

- (void)beginDraggingForGestureRecognizer:(UIGestureRecognizer *)recognizer {
    NSAssert(self.currentDragOperation == nil, @"Should not yet have a context");
    
    self.currentDragOperation = [[DNDDragOperation alloc] initWithDragHandler:self dragSourceView:self.dragSourceView];
    UIView *dragView = [self.dragDelegate draggingViewForDragOperation:self.currentDragOperation];
    if (dragView == nil) {
        [self cancelDragging];
        return;
    }
    
    self.currentDragOperation.draggingView = dragView;
    [self.controller.dragPaneView addSubview:dragView];
    dragView.center = [recognizer locationInView:self.controller.dragPaneView];
}

- (void)updateDraggingForGestureRecognizer:(UIGestureRecognizer *)recognizer {
    NSAssert(self.currentDragOperation != nil, @"Need a context");
    
    if ([self.currentDragOperation isDraggingViewRemoved]) {
        return;
    }
    
    self.currentDragOperation.dragLocation = [recognizer locationInView:self.controller.dragPaneView];
    
    UIView *dropTarget = [self dropTargetAtLocation:[recognizer locationInView:self.controller.dragPaneView]];
    if (dropTarget != self.currentDragOperation.dropTargetView) {
        [self switchCurrentDropTargetToView:dropTarget];
    }
    
    if ([self notifyShouldPositionInDropTarget]) {
        self.currentDragOperation.draggingView.center = [recognizer locationInView:self.controller.dragPaneView];
    }
}

- (void)finishDraggingForGestureRecognizer:(UIGestureRecognizer *)recognizer {
    NSAssert(self.currentDragOperation != nil, @"Need a context");
    
    if ([self.currentDragOperation isDraggingViewRemoved]) {
        return;
    }
    
    if (self.currentDragOperation.dropTargetView != nil) {
        [self notifyDropInTarget:self.currentDragOperation.dropTargetView];
        [self removeDragViewIfNecessary];
    } else {
        [self notifyDragCancel];
        [self removeDragViewIfNecessary];
    }
}


#pragma mark - Helper Methods

- (UIView *)dropTargetAtLocation:(CGPoint)location {
    BOOL userInteractionEnabled = self.currentDragOperation.draggingView.userInteractionEnabled;
    UIView *dropTarget;
    
    self.currentDragOperation.draggingView.userInteractionEnabled = NO; // make sure it's not returned by -hitTest:withEvent:
    dropTarget = [self.controller dropTargetAtLocation:location];
    self.currentDragOperation.draggingView.userInteractionEnabled = userInteractionEnabled;
    
    return dropTarget;
}

- (void)switchCurrentDropTargetToView:(UIView *)newDropTarget {
    [self notifyLeaveDropTarget];
    self.currentDragOperation.dropTargetView = newDropTarget;
    [self notifyEnterDropTarget];
}

- (void)removeDragViewIfNecessary {
    if (![self.currentDragOperation isDraggingViewRemoved]) {
        [self.currentDragOperation removeDraggingView];
    }
}

- (void)cancelDragging {
    [self resetDragRecognizer];
    self.currentDragOperation = nil;
}

- (void)resetDragRecognizer {
    if (self.dragRecognizer.enabled) {
        self.dragRecognizer.enabled = NO;
        self.dragRecognizer.enabled = YES;
    }
}


#pragma mark - Delegate Interaction

- (void)notifyEnterDropTarget {
    id<DNDDropTargetDelegate> delegate = [self.controller delegateForDropTarget:self.currentDragOperation.dropTargetView];
    if ([delegate respondsToSelector:@selector(dragOperation:didEnterDropTarget:)]) {
        [delegate dragOperation:self.currentDragOperation didEnterDropTarget:self.currentDragOperation.dropTargetView];
    }
}

- (void)notifyLeaveDropTarget {
    id<DNDDropTargetDelegate> delegate = [self.controller delegateForDropTarget:self.currentDragOperation.dropTargetView];
    if ([delegate respondsToSelector:@selector(dragOperation:didLeaveDropTarget:)]) {
        [delegate dragOperation:self.currentDragOperation didLeaveDropTarget:self.currentDragOperation.dropTargetView];
    }
}

- (BOOL)notifyShouldPositionInDropTarget {
    id<DNDDropTargetDelegate> delegate = [self.controller delegateForDropTarget:self.currentDragOperation.dropTargetView];
    if ([delegate respondsToSelector:@selector(dragOperation:shouldPositionDragViewInDropTarget:)]) {
        return [delegate dragOperation:self.currentDragOperation shouldPositionDragViewInDropTarget:self.currentDragOperation.dropTargetView];
    } else {
        return YES;
    }
}

- (void)notifyDropInTarget:(UIView *)dropTarget {
    [[self.controller delegateForDropTarget:dropTarget] dragOperation:self.currentDragOperation didDropInDropTarget:dropTarget];
}

- (void)notifyDragCancel {
    if ([self.dragDelegate respondsToSelector:@selector(dragOperationWillCancel:)]) {
        [self.dragDelegate dragOperationWillCancel:self.currentDragOperation];
    }
}

@end

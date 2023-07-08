//
//  DragDropable.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/09.
//

import UIKit

struct DragDropConfig {
    let clipsToBoundsWhileReordering: Bool
    let cornerRadii: Double
    let dargViewScale: Double
    let otherViewsScale: Double
    let temporaryViewAlpha: Double
    let dragHintSpacing: Double
    let longPressMinimumPressDuration: Double
    
    init(
        clipsToBoundsWhileReordering: Bool = false,
        cornerRadii: Double = 5.0,
        dargViewScale: Double = 1.1,
        otherViewsScale: Double = 0.97,
        temporaryViewAlpha: Double = 0.9,
        dragHintSpacing: Double = 5.0,
        longPressMinimumPressDuration: Double = 0.2
    ) {
        self.clipsToBoundsWhileReordering = clipsToBoundsWhileReordering
        self.cornerRadii = cornerRadii
        self.dargViewScale = dargViewScale
        self.otherViewsScale = otherViewsScale
        self.temporaryViewAlpha = temporaryViewAlpha
        self.dragHintSpacing = dragHintSpacing
        self.longPressMinimumPressDuration = longPressMinimumPressDuration
    }
}

private struct AssociatedKeys {
    static var isStatusDragging = "isStatusDragging"
    static var finalReorderFrame = "finalReorderFrame"
    static var originalPosition = "originalPosition"
    static var pointForReordering = "pointForReordering"
    static var actualView = "actualView"
    static var temporaryView = "temporaryView"
    static var temporaryViewForShadow = "temporaryViewForShadow"
}

protocol DragDropable {
    var dargDropDelegate: DragDropStackViewDelegate? { get }
    var config: DragDropConfig { get }
    
    func handleLongPress(_ gesture: UILongPressGestureRecognizer)
}

extension DragDropable where Self: UIStackView {
    var isStatusDragging: Bool {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.isStatusDragging) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &AssociatedKeys.isStatusDragging, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var finalReorderFrame: CGRect {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.finalReorderFrame) as? CGRect) ?? .zero }
        set { objc_setAssociatedObject(self, &AssociatedKeys.finalReorderFrame, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var originalPosition: CGPoint {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.originalPosition) as? CGPoint) ?? .zero }
        set { objc_setAssociatedObject(self, &AssociatedKeys.originalPosition, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var pointForReordering: CGPoint {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.pointForReordering) as? CGPoint) ?? .zero }
        set { objc_setAssociatedObject(self, &AssociatedKeys.pointForReordering, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var actualView: UIView? {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.actualView) as? UIView) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.actualView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var temporaryView: UIView? {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.temporaryView) as? UIView) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.temporaryView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    var temporaryViewForShadow: UIView? {
        get { (objc_getAssociatedObject(self, &AssociatedKeys.temporaryViewForShadow) as? UIView) }
        set { objc_setAssociatedObject(self, &AssociatedKeys.temporaryViewForShadow, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            handleBegan(gesture: gesture)
        case .changed:
            handleChanged(gesture: gesture)
        default:
            // ended, cancelled, failed
            handleEnded(gesture: gesture)
        }
    }
    
    func handleBegan(gesture: UILongPressGestureRecognizer) {
        isStatusDragging = true
        dargDropDelegate?.didBeginDrag()
        if let gestureView = gesture.view {
            actualView = gestureView
        }
        originalPosition = gesture.location(in: self)
        originalPosition.y -= config.dragHintSpacing
        pointForReordering = originalPosition
        prepareForReordering()
    }
    
    func prepareForReordering() {
        clipsToBounds = config.clipsToBoundsWhileReordering
        guard let actualView else { return }
        
        temporaryView = actualView.snapshotView(afterScreenUpdates: true)
        temporaryView?.frame = actualView.frame
        finalReorderFrame = actualView.frame
        if let temporaryView {
            addSubview(temporaryView)
        }
        
        actualView.alpha = 0
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { self.styleViewsForBeginDrag() },
            completion: nil
        )
    }
    
    func styleViewsForBeginDrag() {
        let scale = CGAffineTransform(scaleX: config.dargViewScale, y: config.dargViewScale)
        let translation = CGAffineTransform(translationX: 0, y: config.dragHintSpacing)
        temporaryView?.transform = scale.concatenating(translation)
        temporaryView?.alpha = config.temporaryViewAlpha
        
        let cornerRadiusAnimation = Animation.cornerRadius()
        temporaryView?.layer.add(cornerRadiusAnimation.animation, forKey: cornerRadiusAnimation.id)
        temporaryView?.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        guard let temporaryView else { return }
        temporaryViewForShadow = UIView(frame: temporaryView.frame)
        
        guard let temporaryViewForShadow else { return }
        insertSubview(temporaryViewForShadow, belowSubview: temporaryView)
        temporaryViewForShadow.layer.shadowColor = UIColor.black.cgColor
        temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: temporaryView.bounds, cornerRadius: config.cornerRadii).cgPath
        
        // Shadow animations
        let shadowOpacity = Animation
            .shadowOpacity()
        
        let shadowOffsetHeight = Animation
            .shadowOffsetHeight()
        
        let shadowRadius = Animation
            .shadowRadius()
        
        [shadowOpacity, shadowOffsetHeight, shadowRadius]
            .map(\.tupleAnimationWithID)
            .forEach(temporaryViewForShadow.layer.add)
        
        // Scale down and round other arranged subviews
        arrangedSubviews
            .filter { $0 != actualView }
            .forEach { subview in
                subview.layer.add(cornerRadiusAnimation.animation, forKey: cornerRadiusAnimation.id)
                subview.transform = CGAffineTransform(scaleX: config.otherViewsScale, y: config.otherViewsScale)
            }
    }
    
    func handleChanged(gesture: UILongPressGestureRecognizer) {
        // Drag the temporaryView
        let newLocation = gesture.location(in: self)
        let xOffset = newLocation.x - originalPosition.x
        let yOffset = newLocation.y - originalPosition.y
        let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
        
        // Replicate the scale that was initially applied in perpareForReordering:
        guard let temporaryView else { return }
        
        let scale = CGAffineTransform(scaleX: config.dargViewScale, y: config.dargViewScale)
        temporaryView.transform = scale.concatenating(translation)
        temporaryViewForShadow?.transform = translation
        
        // Use the midY of the temporaryView to determine the dragging direction, location
        // maxY and minY are used in the delegate call dargging
        let maxY = temporaryView.frame.maxY
        let midY = temporaryView.frame.midY
        let minY = temporaryView.frame.minY
        let index = arrangedSubviews
            .firstIndex(where: { $0 == actualView }) ?? 0
        
        if midY > pointForReordering.y {
            // Dragging the view down
            dargDropDelegate?.dargging(inUpDirection: false, maxY: maxY, minY: minY)
            
            if let nextView = arrangedSubviews[safe: index + 1], let actualView {
                if midY > nextView.frame.midY {
                    
                    // Swap the two arranged subviews
                    UIView.animate(withDuration: 0.2, animations: {
                        self.insertArrangedSubview(nextView, at: index)
                        self.insertArrangedSubview(actualView, at: index + 1)
                    })
                    finalReorderFrame = actualView.frame
                    pointForReordering.y = actualView.frame.midY
                }
            }
            
        } else {
            // Dragging the view up
            dargDropDelegate?.dargging(inUpDirection: true, maxY: maxY, minY: minY)
            
            if let previousView = arrangedSubviews[safe: index - 1], let actualView {
                if midY < previousView.frame.midY {
                    
                    // Swap the two arranged subviews
                    UIView.animate(withDuration: 0.2, animations: {
                        self.insertArrangedSubview(previousView, at: index)
                        self.insertArrangedSubview(actualView, at: index - 1)
                    })
                    finalReorderFrame = actualView.frame
                    pointForReordering.y = actualView.frame.midY
                    
                }
            }
        }
    }
    
    func handleEnded(gesture: UILongPressGestureRecognizer) {
        cleanupUpAfterReordering()
        isStatusDragging = false
        dargDropDelegate?.didEndDrop()
    }
    
    func cleanupUpAfterReordering() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { self.styleViewsForEndDrop() },
            completion: { _ in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow?.removeFromSuperview()
                self.temporaryView?.removeFromSuperview()
                self.actualView?.alpha = 1
                self.clipsToBounds = !self.config.clipsToBoundsWhileReordering
            }
        )
    }
    
    func styleViewsForEndDrop() {
        let cornerRadiusAnimation = Animation.cornerRadius()
        let animation = cornerRadiusAnimation.reversedAnimation
        let id = cornerRadiusAnimation.id
        
        // Return drag view to original appearance
        temporaryView?.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        temporaryView?.frame = finalReorderFrame
        temporaryView?.alpha = 1.0
        temporaryView?.layer.add(animation, forKey: id)
        
        // Shadow animations
        let shadowOpacity = Animation
            .shadowOpacity()
        
        let shadowOffsetHeight = Animation
            .shadowOffsetHeight()
        
        let shadowRadius = Animation
            .shadowRadius()
        
        if let temporaryViewForShadow {
            [shadowOpacity, shadowOffsetHeight, shadowRadius]
                .map(\.tupleReversedAnimationWithID)
                .forEach(temporaryViewForShadow.layer.add)
        }
        
        // Return other arranged subviews to original appearances
        arrangedSubviews
            .forEach { subview in
                UIView.animate(
                    withDuration: 0.3,
                    animations: {
                        subview.layer.add(animation, forKey: id)
                        subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
                    }
                )
            }
    }
}

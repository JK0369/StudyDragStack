//
//  DragDropStackView.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/07.
//

import UIKit

protocol DragDropStackViewDelegate {
    func didBeginDrag()
    func dargging(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat)
    func didEndDrop()
}

final class DragDropStackView: UIStackView, UIGestureRecognizerDelegate {
    // MARK: UI
    private var temporaryView: UIView!
    private var temporaryViewForShadow: UIView!
    private var actualView: UIView!
    
    // MARK: Property
    var dargDropDelegate: DragDropStackViewDelegate?
    var dragDropEnabled = false {
        didSet { gestures.forEach { $0.isEnabled = dragDropEnabled } }
    }
    private var gestures = [UILongPressGestureRecognizer]()
    
    private let config: DragDropConfig
    private var isStatusDragging = false
    private var finalReorderFrame: CGRect!
    private var originalPosition: CGPoint!
    private var pointForReordering: CGPoint!
    
    init(config: DragDropConfig = DragDropConfig()) {
        self.config = config
        super.init(frame: .zero)
    }
    
    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError()
    }
    
    // MARK: Method
    override func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        addLongPressGesture(view)
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        !isStatusDragging
    }
}


// MARK: - Priavte Method

private extension DragDropStackView {
    func addLongPressGesture(_ view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(DragDropStackView.handleLongPress(_:)))
        gesture.delegate = self
        gesture.minimumPressDuration = config.longPressMinimumPressDuration
        gesture.isEnabled = dragDropEnabled
        view.addGestureRecognizer(gesture)
        gestures.append(gesture)
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
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
        actualView = gesture.view!
        originalPosition = gesture.location(in: self)
        originalPosition.y -= config.dragHintSpacing
        pointForReordering = originalPosition
        prepareForReordering()
    }
    
    func prepareForReordering() {
        clipsToBounds = config.clipsToBoundsWhileReordering
        
        temporaryView = actualView.snapshotView(afterScreenUpdates: true)
        temporaryView.frame = actualView.frame
        finalReorderFrame = actualView.frame
        addSubview(temporaryView)
        
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
        temporaryView.transform = scale.concatenating(translation)
        temporaryView.alpha = config.temporaryViewAlpha
        
        let cornerRadiusAnimation = Animation.cornerRadius()
        temporaryView.layer.add(cornerRadiusAnimation.animation, forKey: cornerRadiusAnimation.id)
        temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        temporaryViewForShadow = UIView(frame: temporaryView.frame)
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
        let scale = CGAffineTransform(scaleX: config.dargViewScale, y: config.dargViewScale)
        temporaryView.transform = scale.concatenating(translation)
        temporaryViewForShadow.transform = translation
        
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
            
            if let nextView = arrangedSubviews[safe: index + 1] {
                if midY > nextView.frame.midY {
                    
                    // Swap the two arranged subviews
                    UIView.animate(withDuration: 0.2, animations: {
                        self.insertArrangedSubview(nextView, at: index)
                        self.insertArrangedSubview(self.actualView, at: index + 1)
                    })
                    finalReorderFrame = actualView.frame
                    pointForReordering.y = actualView.frame.midY
                }
            }
            
        } else {
            // Dragging the view up
            dargDropDelegate?.dargging(inUpDirection: true, maxY: maxY, minY: minY)
            
            if let previousView = arrangedSubviews[safe: index - 1] {
                if midY < previousView.frame.midY {
                    
                    // Swap the two arranged subviews
                    UIView.animate(withDuration: 0.2, animations: {
                        self.insertArrangedSubview(previousView, at: index)
                        self.insertArrangedSubview(self.actualView, at: index - 1)
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
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.config.clipsToBoundsWhileReordering
            }
        )
    }
    
    func styleViewsForEndDrop() {
        let cornerRadiusAnimation = Animation.cornerRadius()
        let animation = cornerRadiusAnimation.reversedAnimation
        let id = cornerRadiusAnimation.id
        
        // Return drag view to original appearance
        temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        temporaryView.frame = finalReorderFrame
        temporaryView.alpha = 1.0
        temporaryView.layer.add(animation, forKey: id)
        
        // Shadow animations
        let shadowOpacity = Animation
            .shadowOpacity()
        
        let shadowOffsetHeight = Animation
            .shadowOffsetHeight()
        
        let shadowRadius = Animation
            .shadowRadius()
        
        [shadowOpacity, shadowOffsetHeight, shadowRadius]
            .map(\.tupleReversedAnimationWithID)
            .forEach(temporaryViewForShadow.layer.add)
        
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

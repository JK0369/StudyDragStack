//
//  ReorderStackView.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/07.
//

import UIKit

struct DragDropConfig {
    let clipsToBoundsWhileReordering: Bool
    let cornerRadii: Double
    let temporaryViewScale: Double
    let otherViewsScale: Double
    let temporaryViewAlpha: Double
    let dragHintSpacing: Double
    let longPressMinimumPressDuration: Double
    
    init(
        clipsToBoundsWhileReordering: Bool = false,
        cornerRadii: Double = 5.0,
        temporaryViewScale: Double = 1.05,
        otherViewsScale: Double = 0.97,
        temporaryViewAlpha: Double = 0.9,
        dragHintSpacing: Double = 5.0,
        longPressMinimumPressDuration: Double = 0.2
    ) {
        self.clipsToBoundsWhileReordering = clipsToBoundsWhileReordering
        self.cornerRadii = cornerRadii
        self.temporaryViewScale = temporaryViewScale
        self.otherViewsScale = otherViewsScale
        self.temporaryViewAlpha = temporaryViewAlpha
        self.dragHintSpacing = dragHintSpacing
        self.longPressMinimumPressDuration = longPressMinimumPressDuration
    }
}

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
    let config: DragDropConfig
    var dargDropDelegate: DragDropStackViewDelegate?
    var reorderingEnabled = false {
        didSet {
            gestures.forEach { $0.isEnabled = reorderingEnabled }
        }
    }
    private var gestures = [UILongPressGestureRecognizer]()
    
    private var reordering = false
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
        return !reordering
    }
}


// MARK: - Priavte Method

private extension DragDropStackView {
    func addLongPressGesture(_ view: UIView) {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(DragDropStackView.handleLongPress(_:)))
        gesture.delegate = self
        gesture.minimumPressDuration = config.longPressMinimumPressDuration
        gesture.isEnabled = reorderingEnabled
        view.addGestureRecognizer(gesture)
        gestures.append(gesture)
    }
    
    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            handleBegan(gesture: gesture)
        case .changed:
            handleChanged(gesture: gesture)
        default: // ended, cancelled, failed
            handleEnded(gesture: gesture)
        }
    }
    
    func handleBegan(gesture: UILongPressGestureRecognizer) {
        reordering = true
        dargDropDelegate?.didBeginDrag()
        actualView = gesture.view!
        originalPosition = gesture.location(in: self)
        originalPosition.y -= config.dragHintSpacing
        pointForReordering = originalPosition
        prepareForReordering()
    }
    
    func prepareForReordering() {
        clipsToBounds = config.clipsToBoundsWhileReordering
        
        // Configure the temporary view
        temporaryView = actualView.snapshotView(afterScreenUpdates: true)
        temporaryView.frame = actualView.frame
        finalReorderFrame = actualView.frame
        addSubview(temporaryView)
        
        // Hide the actual view and grow the temporaryView
        actualView.alpha = 0
        
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { self.styleViewsForReordering() },
            completion: nil
        )
    }
    
    func handleChanged(gesture: UILongPressGestureRecognizer) {
        // Drag the temporaryView
        let newLocation = gesture.location(in: self)
        let xOffset = newLocation.x - originalPosition.x
        let yOffset = newLocation.y - originalPosition.y
        let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
        
        // Replicate the scale that was initially applied in perpareForReordering:
        let scale = CGAffineTransform(scaleX: config.temporaryViewScale, y: config.temporaryViewScale)
        temporaryView.transform = scale.concatenating(translation)
        temporaryViewForShadow.transform = translation
        
        // Use the midY of the temporaryView to determine the dragging direction, location
        // maxY and minY are used in the delegate call dargging
        let maxY = temporaryView.frame.maxY
        let midY = temporaryView.frame.midY
        let minY = temporaryView.frame.minY
        let index = indexOfArrangedSubview(actualView)
        
        if midY > pointForReordering.y {
            // Dragging the view down
            dargDropDelegate?.dargging(inUpDirection: false, maxY: maxY, minY: minY)
            
            if let nextView = getNextViewInStack(usingIndex: index) {
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
            
            if let previousView = getPreviousViewInStack(usingIndex: index) {
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
        reordering = false
        dargDropDelegate?.didEndDrop()
    }
    
    func cleanupUpAfterReordering() {
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { self.styleViewsForEndReordering() },
            completion: { _ in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.config.clipsToBoundsWhileReordering
            }
        )
    }
    
    func styleViewsForReordering() {
        let roundKey = "Round"
        let round = CABasicAnimation(keyPath: "cornerRadius")
        round.fromValue = 0
        round.toValue = config.cornerRadii
        round.duration = 0.1
        round.isRemovedOnCompletion = false
        round.fillMode = CAMediaTimingFillMode.forwards
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransform(scaleX: config.temporaryViewScale, y: config.temporaryViewScale)
        let translation = CGAffineTransform(translationX: 0, y: config.dragHintSpacing)
        temporaryView.transform = scale.concatenating(translation)
        temporaryView.alpha = config.temporaryViewAlpha
        temporaryView.layer.add(round, forKey: roundKey)
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
                subview.layer.add(round, forKey: roundKey)
                subview.transform = CGAffineTransform(scaleX: config.otherViewsScale, y: config.otherViewsScale)
            }
    }
    
    func styleViewsForEndReordering() {
        let squareKey = "Square"
        let square = CABasicAnimation(keyPath: "cornerRadius")
        square.fromValue = config.cornerRadii
        square.toValue = 0
        square.duration = 0.1
        square.isRemovedOnCompletion = false
        square.fillMode = CAMediaTimingFillMode.forwards
        
        // Return drag view to original appearance
        temporaryView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        temporaryView.frame = finalReorderFrame
        temporaryView.alpha = 1.0
        temporaryView.layer.add(square, forKey: squareKey)
        
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
        for subview in arrangedSubviews {
            UIView.animate(withDuration: 0.3, animations: {
                subview.layer.add(square, forKey: squareKey)
                subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
}


// MARK: - Helper Method

private extension DragDropStackView {
    func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        arrangedSubviews[safe: index - 1]
    }
    
    func getNextViewInStack(usingIndex index: Int) -> UIView? {
        arrangedSubviews[safe: index + 1]
    }
}

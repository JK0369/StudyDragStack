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

@objc
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
        didSet { setReorderingEnabled(reorderingEnabled) }
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
    
    func setReorderingEnabled(_ enabled: Bool) {
        for gesture in gestures {
            gesture.isEnabled = enabled
        }
    }
    
    func updateMinimumPressDuration() {
        for gesture in gestures {
            gesture.minimumPressDuration = config.longPressMinimumPressDuration
        }
    }
    
    @objc func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        
        if gr.state == .began {
            
            reordering = true
            dargDropDelegate?.didBeginDrag()
            
            actualView = gr.view!
            originalPosition = gr.location(in: self)
            originalPosition.y -= config.dragHintSpacing
            pointForReordering = originalPosition
            prepareForReordering()
            
        } else if gr.state == .changed {
            
            // Drag the temporaryView
            let newLocation = gr.location(in: self)
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
            
        } else if gr.state == .ended || gr.state == .cancelled || gr.state == .failed {
            
            cleanupUpAfterReordering()
            reordering = false
            dargDropDelegate?.didEndDrop()
        }
        
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
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForReordering()
            
            }, completion: nil)
    }
    
    func cleanupUpAfterReordering() {
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForEndReordering()
            
            }, completion: { (Bool) -> Void in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.config.clipsToBoundsWhileReordering
        })
        
    }
    
    
    // MARK:- View Styling Methods
    // ---------------------------------------------------------------------------------------------
    
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
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0
        shadowOpacity.toValue = 0.2
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 0
        shadowOffset.toValue = 50
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 0
        shadowRadius.toValue = 20
        shadowRadius.duration = 0.2
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = CAMediaTimingFillMode.forwards
        
        temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Scale down and round other arranged subviews
        for subview in arrangedSubviews {
            if subview != actualView {
                subview.layer.add(round, forKey: roundKey)
                subview.transform = CGAffineTransform(scaleX: config.otherViewsScale, y: config.otherViewsScale)
            }
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
        let shadowOpacityKey = "ShadowOpacity"
        let shadowOpacity = CABasicAnimation(keyPath: "shadowOpacity")
        shadowOpacity.fromValue = 0.2
        shadowOpacity.toValue = 0
        shadowOpacity.duration = 0.2
        shadowOpacity.isRemovedOnCompletion = false
        shadowOpacity.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowOffsetKey = "ShadowOffset"
        let shadowOffset = CABasicAnimation(keyPath: "shadowOffset.height")
        shadowOffset.fromValue = 50
        shadowOffset.toValue = 0
        shadowOffset.duration = 0.2
        shadowOffset.isRemovedOnCompletion = false
        shadowOffset.fillMode = CAMediaTimingFillMode.forwards
        
        let shadowRadiusKey = "ShadowRadius"
        let shadowRadius = CABasicAnimation(keyPath: "shadowRadius")
        shadowRadius.fromValue = 20
        shadowRadius.toValue = 0
        shadowRadius.duration = 0.4
        shadowRadius.isRemovedOnCompletion = false
        shadowRadius.fillMode = CAMediaTimingFillMode.forwards
        
        temporaryViewForShadow.layer.add(shadowOpacity, forKey: shadowOpacityKey)
        temporaryViewForShadow.layer.add(shadowOffset, forKey: shadowOffsetKey)
        temporaryViewForShadow.layer.add(shadowRadius, forKey: shadowRadiusKey)
        
        // Return other arranged subviews to original appearances
        for subview in arrangedSubviews {
            UIView.animate(withDuration: 0.3, animations: {
                subview.layer.add(square, forKey: squareKey)
                subview.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            })
        }
    }
    
    
    // MARK:- Stack View Helper Methods
    // ---------------------------------------------------------------------------------------------
    
    func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return arrangedSubviews[index - 1]
    }
    
    func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == arrangedSubviews.count - 1 { return nil }
        return arrangedSubviews[index + 1]
    }
}

//
//  ReorderStackView.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/07.
//

import UIKit

@objc
public protocol APStackViewReorderDelegate {
    @objc optional func didBeginDrag()
    @objc optional func dargging(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat)
    @objc optional func didEndDrop()
}

public class DragDropStackView: UIStackView, UIGestureRecognizerDelegate {
    public var reorderingEnabled = false {
        didSet {
            setReorderingEnabled(reorderingEnabled)
        }
    }
    public var reorderDelegate: APStackViewReorderDelegate?
    
    // Gesture recognizers
    fileprivate var longPressGRS = [UILongPressGestureRecognizer]()
    
    // Views for reordering
    fileprivate var temporaryView: UIView!
    fileprivate var temporaryViewForShadow: UIView!
    fileprivate var actualView: UIView!
    
    // Values for reordering
    fileprivate var reordering = false
    fileprivate var finalReorderFrame: CGRect!
    fileprivate var originalPosition: CGPoint!
    fileprivate var pointForReordering: CGPoint!
    
    // Appearance Constants
    public var clipsToBoundsWhileReordering = false
    public var cornerRadii: CGFloat = 5
    public var temporaryViewScale: CGFloat = 1.05
    public var otherViewsScale: CGFloat = 0.97
    public var temporaryViewAlpha: CGFloat = 0.9
    /// The gap created once the long press drag is triggered
    public var dragHintSpacing: CGFloat = 5
    public var longPressMinimumPressDuration = 0.2 {
        didSet {
            updateMinimumPressDuration()
        }
    }
    
    // MARK:- Reordering Methods
    // ---------------------------------------------------------------------------------------------
    override public func addArrangedSubview(_ view: UIView) {
        super.addArrangedSubview(view)
        addLongPressGestureRecognizerForReorderingToView(view)
    }
    
    fileprivate func addLongPressGestureRecognizerForReorderingToView(_ view: UIView) {
        let longPressGR = UILongPressGestureRecognizer(target: self, action: #selector(DragDropStackView.handleLongPress(_:)))
        longPressGR.delegate = self
        longPressGR.minimumPressDuration = longPressMinimumPressDuration
        longPressGR.isEnabled = reorderingEnabled
        view.addGestureRecognizer(longPressGR)
        
        longPressGRS.append(longPressGR)
    }
    
    fileprivate func setReorderingEnabled(_ enabled: Bool) {
        for longPressGR in longPressGRS {
            longPressGR.isEnabled = enabled
        }
    }
    
    fileprivate func updateMinimumPressDuration() {
        for longPressGR in longPressGRS {
            longPressGR.minimumPressDuration = longPressMinimumPressDuration
        }
    }
    
    @objc internal func handleLongPress(_ gr: UILongPressGestureRecognizer) {
        
        if gr.state == .began {
            
            reordering = true
            reorderDelegate?.didBeginDrag?()
            
            actualView = gr.view!
            originalPosition = gr.location(in: self)
            originalPosition.y -= dragHintSpacing
            pointForReordering = originalPosition
            prepareForReordering()
            
        } else if gr.state == .changed {
            
            // Drag the temporaryView
            let newLocation = gr.location(in: self)
            let xOffset = newLocation.x - originalPosition.x
            let yOffset = newLocation.y - originalPosition.y
            let translation = CGAffineTransform(translationX: xOffset, y: yOffset)
            // Replicate the scale that was initially applied in perpareForReordering:
            let scale = CGAffineTransform(scaleX: temporaryViewScale, y: temporaryViewScale)
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
                reorderDelegate?.dargging?(inUpDirection: false, maxY: maxY, minY: minY)
                
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
                reorderDelegate?.dargging?(inUpDirection: true, maxY: maxY, minY: minY)
                
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
            reorderDelegate?.didEndDrop?()
        }
        
    }
    
    fileprivate func prepareForReordering() {
        
        clipsToBounds = clipsToBoundsWhileReordering
        
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
    
    fileprivate func cleanupUpAfterReordering() {
        
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            
            self.styleViewsForEndReordering()
            
            }, completion: { (Bool) -> Void in
                // Hide the temporaryView, show the actualView
                self.temporaryViewForShadow.removeFromSuperview()
                self.temporaryView.removeFromSuperview()
                self.actualView.alpha = 1
                self.clipsToBounds = !self.clipsToBoundsWhileReordering
        })
        
    }
    
    
    // MARK:- View Styling Methods
    // ---------------------------------------------------------------------------------------------
    
    fileprivate func styleViewsForReordering() {
        
        let roundKey = "Round"
        let round = CABasicAnimation(keyPath: "cornerRadius")
        round.fromValue = 0
        round.toValue = cornerRadii
        round.duration = 0.1
        round.isRemovedOnCompletion = false
        round.fillMode = CAMediaTimingFillMode.forwards
        
        // Grow, hint with offset, fade, round the temporaryView
        let scale = CGAffineTransform(scaleX: temporaryViewScale, y: temporaryViewScale)
        let translation = CGAffineTransform(translationX: 0, y: dragHintSpacing)
        temporaryView.transform = scale.concatenating(translation)
        temporaryView.alpha = temporaryViewAlpha
        temporaryView.layer.add(round, forKey: roundKey)
        temporaryView.clipsToBounds = true // Clips to bounds to apply corner radius
        
        // Shadow
        temporaryViewForShadow = UIView(frame: temporaryView.frame)
        insertSubview(temporaryViewForShadow, belowSubview: temporaryView)
        temporaryViewForShadow.layer.shadowColor = UIColor.black.cgColor
        temporaryViewForShadow.layer.shadowPath = UIBezierPath(roundedRect: temporaryView.bounds, cornerRadius: cornerRadii).cgPath
        
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
                subview.transform = CGAffineTransform(scaleX: otherViewsScale, y: otherViewsScale)
            }
        }
    }
    
    fileprivate func styleViewsForEndReordering() {
        
        let squareKey = "Square"
        let square = CABasicAnimation(keyPath: "cornerRadius")
        square.fromValue = cornerRadii
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
    
    fileprivate func indexOfArrangedSubview(_ view: UIView) -> Int {
        for (index, subview) in arrangedSubviews.enumerated() {
            if view == subview {
                return index
            }
        }
        return 0
    }
    
    fileprivate func getPreviousViewInStack(usingIndex index: Int) -> UIView? {
        if index == 0 { return nil }
        return arrangedSubviews[index - 1]
    }
    
    fileprivate func getNextViewInStack(usingIndex index: Int) -> UIView? {
        if index == arrangedSubviews.count - 1 { return nil }
        return arrangedSubviews[index + 1]
    }
    
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return !reordering
    }

}


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

protocol DragDropable {
    var config: DragDropConfig { get }
    var isStatusDragging: Bool { get }
    var finalReorderFrame: CGRect? { get }
    var originalPosition: CGPoint? { get }
    var pointForReordering: CGPoint? { get }
}

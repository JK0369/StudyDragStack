//
//  AnimationType.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/08.
//

import UIKit

enum Animation {
    struct Config {
        let uniqID = UUID().uuidString
        let fromValue: Double
        let toValue: Double
        let duration: Double
        let isRemovedOnCompletion: Bool
        let fillMode: CAMediaTimingFillMode
        
        init(
            fromValue: Double,
            toValue: Double,
            duration: Double,
            isRemovedOnCompletion: Bool,
            fillMode: CAMediaTimingFillMode
        ) {
            self.fromValue = fromValue
            self.toValue = toValue
            self.duration = duration
            self.isRemovedOnCompletion = isRemovedOnCompletion
            self.fillMode = fillMode
        }
    }
    
    case shadowOpacity(
        Config = .init(
            fromValue: 0,
            toValue: 0.2,
            duration: 0.2,
            isRemovedOnCompletion: false,
            fillMode: .forwards
        )
    )
    case shadowOffsetHeight(
        Config = .init(
            fromValue: 0,
            toValue: 50,
            duration: 0.2,
            isRemovedOnCompletion: false,
            fillMode: .forwards
        )
    )
    case shadowRadius(
        Config = .init(
            fromValue: 0,
            toValue: 20,
            duration: 0.2,
            isRemovedOnCompletion: false,
            fillMode: .forwards
        )
    )
    
    var animation: CABasicAnimation {
        let basicAnimation = CABasicAnimation(keyPath: config.uniqID)
        basicAnimation.fromValue = config.fromValue
        basicAnimation.toValue = config.toValue
        basicAnimation.duration = config.duration
        basicAnimation.isRemovedOnCompletion = config.isRemovedOnCompletion
        basicAnimation.fillMode = config.fillMode
        return basicAnimation
    }
    
    /// from <-> to
    var reversedAnimation: CABasicAnimation {
        let basicAnimation = CABasicAnimation(keyPath: config.uniqID)
        basicAnimation.fromValue = config.toValue
        basicAnimation.toValue = config.fromValue
        basicAnimation.duration = config.duration
        basicAnimation.isRemovedOnCompletion = config.isRemovedOnCompletion
        basicAnimation.fillMode = config.fillMode
        return basicAnimation
    }
    
    var tupleAnimationWithID: (CABasicAnimation, String) {
        (animation, config.uniqID)
    }
    
    var tupleReversedAnimationWithID: (CABasicAnimation, String) {
        (reversedAnimation, config.uniqID)
    }
    
    private var config: Config {
        switch self {
        case
            .shadowOpacity(let config),
            .shadowOffsetHeight(let config),
            .shadowRadius(let config)
        :
            return config
        }
    }
    
    private var key: String {
        switch self {
        case .shadowOpacity:
            return "shadowOpacity"
        case .shadowOffsetHeight:
            return "shadowOffset.height"
        case .shadowRadius:
            return "shadowRadius"
        }
    }
}

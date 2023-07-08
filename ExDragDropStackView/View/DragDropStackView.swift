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

final class DragDropStackView: UIStackView, DragDropable {
    // MARK: Property
    var dargDropDelegate: DragDropStackViewDelegate?
    var dragDropEnabled = false {
        didSet { gestures.forEach { $0.isEnabled = dragDropEnabled } }
    }
    var gestures = [UILongPressGestureRecognizer]()
    
    let config: DragDropConfig
    
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
        addLongPressGestureForDragDrop(arrangedSubview: view)
    }
}

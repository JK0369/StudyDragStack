//
//  ViewController.swift
//  ExDragDropStackView
//
//  Created by 김종권 on 2023/07/07.
//

import UIKit

class ViewController: UIViewController, APStackViewReorderDelegate {
    
    let textField = UITextField()
    let sv = UIScrollView()
    let exampleView = ExampleView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        textField.placeholder = "input"
        
        view.addSubview(textField)
        view.addSubview(sv)
        sv.addSubview(exampleView)
        
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textField.topAnchor.constraint(equalTo: view.topAnchor, constant: 70),
        ])
        
        sv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sv.topAnchor.constraint(equalTo: textField.bottomAnchor),
        ])
        
        exampleView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            exampleView.leadingAnchor.constraint(equalTo: sv.leadingAnchor),
            exampleView.trailingAnchor.constraint(equalTo: sv.trailingAnchor),
            exampleView.bottomAnchor.constraint(equalTo: sv.bottomAnchor),
            exampleView.topAnchor.constraint(equalTo: sv.topAnchor),
            exampleView.widthAnchor.constraint(equalTo: sv.widthAnchor),
        ])
        
//        sv.snp.makeConstraints {
//            $0.edges.equalToSuperview()
//        }
//        exampleView.snp.makeConstraints {
//            $0.edges.width.equalToSuperview()
//        }
        
        self.exampleView.rStackView.reorderDelegate = self
    }
    
    // Delegate Methods
    func didBeginReordering() {
        print("Did begin reordering")
    }
    
    func didDragToReorder(inUpDirection up: Bool, maxY: CGFloat, minY: CGFloat) {
        print("Dragging: \(up ? "Up" : "Down")")
    }

    
    func didEndReordering() {
        print("Did end reordering")
    }
    
}

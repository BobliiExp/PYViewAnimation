//
//  ViewController.swift
//  CustomAnimation
//
//  Created by Bob Lee on 2019/3/21.
//  Copyright © 2019 Bob Lee. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var viewAnimation: PYViewAnimation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupData()
    }
    
    func setupUI() {
        let animation = PYViewAnimation.init(frame: CGRect.init(x: 100, y: 100, width: 250, height: 250))
        view.addSubview(animation)
        viewAnimation = animation
        
        let button = UIButton.init(frame: CGRect.init(x: 100, y: 450, width: 100, height: 40))
        button.setTitle("开始动画", for: .normal)
        button.setTitle("结束动画", for: .selected)
        button.backgroundColor = UIColor.blue
        button.addTarget(self, action: #selector(btnClicked(_:)), for: .touchUpInside)
        view.addSubview(button)
    }
    
    func setupData() {
        viewAnimation?.setupAnimationKey(.loading)
    }

    @objc func btnClicked(_ btn: UIButton) {
        btn.isSelected = !btn.isSelected
        
        if btn.isSelected {
            viewAnimation?.stopAnimating()
        } else {
            viewAnimation?.startAnimating()
        }
    }
}


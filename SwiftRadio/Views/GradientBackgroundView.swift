//
//  GradientBackgroundView.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2025-02-07.
//  Copyright © 2025 matthewfecher.com. All rights reserved.
//

import UIKit

class GradientBackgroundView: UIView {

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 1)
        layer.endPoint = CGPoint(x: 1, y: 0)
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        updateGradientColors()
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func updateGradientColors() {
        let color = Config.gradientColor
        gradientLayer.colors = [
            color.withAlphaComponent(0.2).cgColor,
            color.withAlphaComponent(0.4).cgColor,
            color.withAlphaComponent(0.8).cgColor,
            color.withAlphaComponent(0.1).cgColor
        ]
        gradientLayer.locations = [0.0, 0.35, 0.7, 1.0]
    }
}

//
//  VideoSegmentProgressBar.swift
//  WhaleCodingTest
//
//  Created by Chase Wang on 11/19/16.
//  Copyright © 2016 ocwang. All rights reserved.
//

import UIKit

class VideoSegmentProgressBar: UIView {
    
    // MARK: - Instance Vars
    
    fileprivate let progressViewEdgeInset: CGFloat = 1
    
    fileprivate var currentVideoSegmentProgressViewWidthConstraint: NSLayoutConstraint?
    
    fileprivate var videoSegmentProgressViews = [UIView]()
    
    var progressViewColor = UIColor.black
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        newVideoSegmentProgressView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        newVideoSegmentProgressView()
    }
    
    fileprivate func removeLastVideoSegmentProgressView() {
        videoSegmentProgressViews.removeLast().removeFromSuperview()
    }
}

// MARK: - Public Instance Methods

extension VideoSegmentProgressBar {
    func newVideoSegmentProgressView() {
        let newProgressView = UIView()
        newProgressView.translatesAutoresizingMaskIntoConstraints = false
        newProgressView.backgroundColor = progressViewColor
        
        addSubview(newProgressView)
        
        newProgressView.topAnchor.constraint(equalTo: topAnchor, constant: progressViewEdgeInset).isActive = true
        newProgressView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -progressViewEdgeInset).isActive = true
        currentVideoSegmentProgressViewWidthConstraint = newProgressView.widthAnchor.constraint(equalToConstant: 0)
        currentVideoSegmentProgressViewWidthConstraint!.isActive = true
        
        if videoSegmentProgressViews.isEmpty {
            newProgressView.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
        } else {
            let lastProgressView = videoSegmentProgressViews.last!
            newProgressView.leadingAnchor.constraint(equalTo: lastProgressView.trailingAnchor, constant: progressViewEdgeInset).isActive = true
        }
        
        videoSegmentProgressViews.append(newProgressView)
        setNeedsUpdateConstraints()
    }
    
    internal func lastVideoSegmentInvalidated() {
        removeLastVideoSegmentProgressView()
        newVideoSegmentProgressView()
    }
    
    internal func updateCurrentVideoSegmentProgressView(toWidth width: CGFloat) {
        currentVideoSegmentProgressViewWidthConstraint!.constant = width
        
        setNeedsUpdateConstraints()
        layoutIfNeeded()
    }
    
    internal func reset() {
        currentVideoSegmentProgressViewWidthConstraint = nil
        
        while !videoSegmentProgressViews.isEmpty {
            removeLastVideoSegmentProgressView()
        }
        
        newVideoSegmentProgressView()
    }
}

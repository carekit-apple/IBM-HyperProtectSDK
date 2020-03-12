//
//  SyncViewController.swift
//  CareSync
//
//  Created by Erik Hornberger on 3/11/20.
//  Copyright © 2020 Erik Hornberger. All rights reserved.
//

import UIKit
import CareKitStore

final class SyncViewController: UIViewController {
    
    let store: OCKSynchronizedStore
    let label = UILabel()
    
    init() {
        self.store = (UIApplication.shared.delegate as! AppDelegate).synchronizedStoreManager.store as! OCKSynchronizedStore
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        view.addSubview(label)
        
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            label.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        store.synchronize { [weak self] result in
            switch result {
            case .success:
                self?.label.text = "Success!\nSwipe down to dismiss!"
                
            case let .failure(error):
                self?.label.text = "Failure: \(error.localizedDescription)\nSwipe down to dismiss."
            }
        }
    }
}

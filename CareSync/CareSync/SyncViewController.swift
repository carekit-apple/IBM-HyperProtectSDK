import UIKit
import CareKitStore

final class SyncViewController: UIViewController {
    
    let store: OCKStore
    let label = UILabel()
    
    init() {
        self.store = (UIApplication.shared.delegate as! AppDelegate).synchronizedStoreManager.store as! OCKStore
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
        store.synchronize { [weak self] error in
            DispatchQueue.main.async {
                self?.label.text = error == nil ?
                    "Success!\nSwipe down to dismiss!" :
                    "Failure: \(error!.localizedDescription)\nSwipe down to dismiss."
            }
        }
    }
}

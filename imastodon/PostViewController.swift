import Foundation
import NorthLayout
import Ikemen
import SVProgressHUD

class PostViewController: UIViewController {
    private let client: Client

    private let contentView = UIView() ※ { v in
        v.backgroundColor = .white
    }

    private let postField = UITextView() ※ { tv in
    }

    init(client: Client) {
        self.client = client
        super.init(nibName: nil, bundle: nil)
        title = "Post"
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Toot", style: .done, target: self, action: #selector(post))
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.5)

        let autolayout = contentView.northLayoutFormat([:], ["message": postField])
        autolayout("H:|[message]|")
        autolayout("V:||[message]||")
        postField.contentInsetAdjustmentBehavior = .always

        let autolayoutVC = northLayoutFormat([:], ["content": contentView, "bottom": UIView() ※ {$0.isHidden = true}])
        autolayoutVC("H:|[content]|")
        autolayoutVC("V:||-128-[bottom]")
        autolayoutVC("V:|[content][bottom]")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        postField.becomeFirstResponder()
    }

    @objc private func cancel() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func post() {
        guard let status = postField.text else { return }
        SVProgressHUD.show()
        client.post(message: status)
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess {_ in
                self.view.endEditing(true)
                self.dismiss(animated: true)
            }
            .onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }
}

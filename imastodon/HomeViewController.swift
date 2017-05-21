import Foundation
import Eureka
import MastodonKit
import SVProgressHUD

class HomeViewController: FormViewController {
    let instanceAccount: InstanceAccout
    private var timelineSection = Section()

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(style: .plain)
        title = "Home@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        form +++ timelineSection
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        fetch()
    }

    private func fetch() {
        SVProgressHUD.show()
        let client = Client(baseURL: "https://" + instanceAccount.instance.uri, accessToken: instanceAccount.accessToken)
        client.home()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.timelineSection.removeAll(keepingCapacity: true)
                self.timelineSection.append(contentsOf: statuses.map { s in
                    LabelRow {
                        $0.title = "\(s.account.displayName): \(s.content)"
                        $0.cell.textLabel?.numberOfLines = 0
                    }
                })
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }
}

import BrightFutures

extension Client {
    func home() -> Future<[Status], AppError> {
        let promise = Promise<[Status], AppError>()
        run(Timelines.home()) { statuses, error in
            if let error = error {
                promise.failure(.mastodonKit(error))
                return
            }
            guard let statuses = statuses else {
                promise.failure(.mastodonKitNullPo)
                return
            }
            promise.success(statuses)
        }
        return promise.future
    }
}

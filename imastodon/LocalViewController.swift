import Foundation
import Eureka
import SVProgressHUD
import MastodonKit
import IKEventSource
import Ikemen

class LocalViewController: FormViewController {
    let instanceAccount: InstanceAccout
    private var timelineSection = Section()
    private var eventSource: EventSource?

    init(instanceAccount: InstanceAccout) {
        self.instanceAccount = instanceAccount
        super.init(style: .plain)
        title = "Local@\(instanceAccount.instance.title) \(instanceAccount.account.displayName)"
        form +++ timelineSection
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    deinit {
        eventSource?.close()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if timelineSection.isEmpty {
            fetch()
        }
        if eventSource == nil {
            reconnectEventSource()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    private func append(_ statuses: [Status]) {
        timelineSection.insert(contentsOf: statuses.map { s in
            StatusRow {$0.value = s}
                .onCellSelection { [unowned self] cell, row in self.didTap(status: s, cell: cell, row: row)}
        }, at: 0)

        if timelineSection.count > 100 {
            timelineSection.removeLast(timelineSection.count - 80)
        }
    }

    private func reconnectEventSource() {
        eventSource?.close()
        eventSource = EventSource(url: "https://" + instanceAccount.instance.uri + "/api/v1/streaming/public/local", headers: ["Authorization": "Bearer \(instanceAccount.accessToken)"]) ※ { es in
            es.onOpen { [weak es] in
                NSLog("%@", "EventSource opened: \(String(describing: es?.readyState))")
            }
            es.onError { [weak es, weak self] e in
                NSLog("%@", "EventSource error: \(String(describing: e))")
                es?.invalidate()
                self?.eventSource = nil

                guard e?.code != NSURLErrorCancelled else { return }
                DispatchQueue.main.async {
                    let ac = UIAlertController(title: "Stream Error", message: e?.localizedDescription, preferredStyle: .alert)
                    ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(ac, animated: true)
                }
            }
            es.onMessage { _ in // [weak self] id, event, data in
                // NSLog("%@", "EventSource onMessage: \(id), \(event), \(data)")
            }
            es.addEventListener("update") { [weak self] id, event, data in
                do {
                    let j = try JSONSerialization.jsonObject(with: data?.data(using: .utf8) ?? Data())
                    let status = try Status.decodeValue(j)
                    DispatchQueue.main.async {
                        self?.append([status])
                    }
                    // NSLog("%@", "EventSource event update: \(status)")
                } catch {
                    NSLog("%@", "EventSource event update, failed to parse with error \(error): \(String(describing: id)), \(String(describing: event)), \(String(describing: data))")
                    DispatchQueue.main.async {
                        // for debug, append error message
                        let errorAccount = Account(id: 0, username: "", acct: "", displayName: "error", note: "", url: "", avatar: "", avatarStatic: "", header: "", headerStatic: "", locked: false, createdAt: Date(), followersCount: 0, followingCount: 0, statusesCount: 0)
                        let errorStatus = Status(id: 0, uri: "", url: URL(string: "")!, account: errorAccount, inReplyToID: nil, inReplyToAccountID: nil, content: error.localizedDescription, createdAt: Date(), reblogsCount: 0, favouritesCount: 0, reblogged: nil, favourited: nil, sensitive: nil, spoilerText: "", visibility: .public, mediaAttachments: [], mentions: [], tags: [], application: nil, reblogWrapper: [])
                        self?.append([errorStatus])
                    }
                }
            }
        }
    }

    private func fetch() {
        SVProgressHUD.show()
        Client(instanceAccount).local()
            .onComplete {_ in SVProgressHUD.dismiss()}
            .onSuccess { statuses in
                self.timelineSection.removeAll(keepingCapacity: true)
                self.append(statuses)
            }.onFailure { e in
                let ac = UIAlertController(title: "Error", message: e.localizedDescription, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(ac, animated: true)
        }
    }

    private func didTap(status: Status, cell: BaseCell, row: BaseRow) {
    }
}

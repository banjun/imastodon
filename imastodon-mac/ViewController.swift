import Cocoa
import ReactiveSwift
import ReactiveSSE

private let token = ""

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        var req = URLRequest(url: URL(string: "https://imastodon.net/api/v1/streaming/public/local")!)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        ReactiveSSE(urlRequest: req).producer
            .filter {$0.type == "update"}
            .filterMap {$0.data.data(using: .utf8)}
            .filterMap {try? JSONDecoder().decode(Status.self, from: $0)}
            .startWithResult { r in
                switch r {
                case .success(let s):
                    NSLog("%@", "\(s.textContent)")
                case .failure(let e):
                    NSLog("%@", "\(e)")
                }
        }
    }
}


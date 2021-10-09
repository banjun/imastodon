import UIKit
import API

final class StatusPreviewingDelegate {
    let client: Client
    let context: (CGPoint) -> (status: Status, attributedText: NSAttributedString?, sourceRect: CGRect)?
    weak var vc: UIViewController?
    init(vc: UIViewController?, client: Client, context: @escaping (CGPoint) -> (status: Status, attributedText: NSAttributedString?, sourceRect: CGRect)?) {
        self.client = client
        self.context = context
        self.vc = vc
    }

    // NOTE: might be better if vc is cached on preview and re-used on commit transition
    func preview(for location: CGPoint) -> UIViewController? {
        guard let context = context(location) else { return nil }
        return StatusViewController(client: client, status: (context.status, context.attributedText), previewActionParentViewController: vc)
    }
}

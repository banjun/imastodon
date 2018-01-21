import UIKit
import API

final class StatusPreviewingDelegate: NSObject, UIViewControllerPreviewingDelegate {
    let client: Client
    let context: (CGPoint) -> (status: Status, attributedText: NSAttributedString?, sourceRect: CGRect)?
    weak var vc: UIViewController?
    init(vc: UIViewController?, client: Client, context: @escaping (CGPoint) -> (status: Status, attributedText: NSAttributedString?, sourceRect: CGRect)?) {
        self.client = client
        self.context = context
        self.vc = vc
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let context = context(location) else { return nil }
        previewingContext.sourceRect = context.sourceRect
        return StatusViewController(client: client, status: (context.status, context.attributedText), previewActionParentViewController: vc)
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        vc?.show(viewControllerToCommit, sender: nil)
    }
}

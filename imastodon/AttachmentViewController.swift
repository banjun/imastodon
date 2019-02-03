import UIKit
import Kingfisher
import Ikemen
import NorthLayout
import API

final class AttachmentViewController: UIViewController, UIGestureRecognizerDelegate {
    private let imageCache: ImageCache
    let attachment: Attachment
    let imageView = UIImageView() ※ { iv in
        iv.contentMode = .scaleAspectFit
    }

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(scale)) ※ {$0.delegate = self}
    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scale)) ※ {$0.delegate = self}

    init(attachment: Attachment, imageCache: ImageCache = .default) {
        self.attachment = attachment
        self.imageCache = imageCache
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(white: 0, alpha: 0.5)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(done)))
        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(pinchGestureRecognizer)

        let autolayout = northLayoutFormat([:], ["image": imageView])
        autolayout("H:|[image]|")
        autolayout("V:|[image]|")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        load()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        imageView.kf.cancelDownloadTask()
        hide()
    }

    func load() {
        let previewURL = URL(string: attachment.preview_url)
        let url = URL(string: attachment.url)
        
        var imageViewKf = imageView.kf
        imageViewKf.indicatorType = .activity
        if let previewURL = previewURL {
            imageCache.retrieveImage(forKey: previewURL.cacheKey, options: nil, callbackQueue: .mainCurrentOrAsync) { [weak imageView] r in
                imageView?.kf.setImage(
                    with: url ?? previewURL,
                    placeholder: r.value?.image ?? stubImage())
            }
        } else {
            imageViewKf.setImage(
                with: url ?? previewURL,
                placeholder: stubImage())
        }

        imageView.alpha = 0
        imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.imageView.transform = .identity
            self.imageView.alpha = 1
        }, completion: nil)
    }

    func hide() {
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
            self.imageView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            self.imageView.alpha = 0
        }, completion: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return gestureRecognizer === pinchGestureRecognizer && otherGestureRecognizer === panGestureRecognizer
    }

    @objc func scale() {
        guard pinchGestureRecognizer.state == .changed || panGestureRecognizer.state == .changed else {
            if imageView.transform.a < 1 {
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: [], animations: {
                    self.imageView.transform = .identity
                }, completion: nil)
            }
            return
        }
        let scale = pinchGestureRecognizer.scale
        let translation = panGestureRecognizer.translation(in: view)
        self.imageView.transform = imageView.transform // CGAffineTransform.identity
            .translatedBy(x: translation.x / imageView.transform.a, y: translation.y / imageView.transform.a)
            .scaledBy(x: scale, y: scale)
        panGestureRecognizer.setTranslation(.zero, in: view)
        pinchGestureRecognizer.scale = 1
    }

    @objc func done() {
        dismiss(animated: true)
    }
}

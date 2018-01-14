import UIKit
import Kingfisher
import Ikemen

final class HeaderImageView: UIView, UIScrollViewDelegate {
    let scrollView = UIScrollView() ※ {
        $0.bounces = true
        $0.showsHorizontalScrollIndicator = false
        $0.showsVerticalScrollIndicator = false
    }
    let imageView = UIImageView() ※ {_ in}
    private var imageKVO: NSKeyValueObservation?

    override open class var requiresConstraintBasedLayout: Bool {return true}

    override init(frame: CGRect) {
        super.init(frame: frame)

        scrollView.delegate = self
        scrollView.contentInsetAdjustmentBehavior = .never // the missing .vertical is what we need. adjust by manual contentInset and zoom scale

        let autolayout = northLayoutFormat([:], ["sv": scrollView])
        autolayout("H:|[sv]|")
        autolayout("V:|[sv]|")

        let contentLayout = scrollView.northLayoutFormat([:], ["image": imageView])
        contentLayout("H:|[image]|")
        contentLayout("V:|[image]|")

        imageKVO = imageView.observe(\.image) { [weak self] _, _ in
            self?.setNeedsLayout()
        }
    }

    required init?(coder aDecoder: NSCoder) {fatalError()}

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.contentInset.top = scrollView.safeAreaInsets.top

        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return }
        UIView.performWithoutAnimation {
            scrollView.layoutIfNeeded() // update scroll view contentSize
            let aspectFillScale = max(bounds.size.width / image.size.width,
                                      (bounds.size.height - scrollView.contentInset.top) / image.size.height)
            scrollView.minimumZoomScale = aspectFillScale
            scrollView.maximumZoomScale = aspectFillScale
            scrollView.zoomScale = aspectFillScale
        }
        scrollView.scrollContentToCenter(animated: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
}

extension UIScrollView {
    func scrollContentToCenter(animated: Bool) {
        setContentOffset(CGPoint(x: (contentSize.width - bounds.width) / 2,
                                 y: (contentSize.height - bounds.height - adjustedContentInset.top) / 2),
                         animated: animated)
    }
}

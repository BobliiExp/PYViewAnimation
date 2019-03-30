//
//  PYViewAnimation.swift
//
//  Created by Bob Lee on 2019/3/19.
//

import UIKit

/**
 帧动画
 应用：
 1.loading
 2.闪烁
 
 能力：
 1.根据json配置，加载图像帧
 2.播放帧动画
 3.支持轮播
 4.支持播放回调控制
 */

protocol PYViewAnimationDelegate : NSObjectProtocol {
    /// 即将展示第几帧图像
    func willDisplayFrame(_ index: Int, animator: PYViewAnimation)
    /// 已经展示到第几帧
    func didDisplayedFrame(_ index: Int, animator: PYViewAnimation)
    /// 动画已结束
    func didAnimateEnd(_ animator: PYViewAnimation)
}

class PYViewAnimation: UIImageView {
    
    // MARK: - properties
    
    // public
    /** 停止动画时显示的指定图片 */
    var imageWhileStopAnimating: CGImage?
    /** 动画停止到指定帧，默认是最后一帧 */
    var indexWhileStopAnimating: Int?
    /** 设置图标颜色 */
    var customTintColor: UIColor?
    /** 外部关心动画情况者 */
    weak var delegate: PYViewAnimationDelegate?
    /** 期望大小，建议使用，此值建议配置到json中 */
    var sizeExpected: CGSize {
        var size: CGSize?
        if let config = _imageConfig {
            size = config.size
        }
        
        return size ?? CGSize.init(width: 100, height: 100)
    }
    var partial: String?
    /** 用户配置key统一部分 */
    var animationType: PYAnimationViewType!
    
    //    override var tintColor: UIColor! 支持tint
    
    // private
    private var _isAnimating: Bool = false
    override var isAnimating: Bool {
        return _isAnimating
    }
    /** 根据key装载的图片序列，图像放到了super.animationImages中 */
    private weak var _imageConfig: PYAnimationConfig?
    private var _imageCache: [CGImage]?
    /** 根据屏幕刷新来控制动画切换 */
    private var _displayLink: CADisplayLink?
    /** 用于图像绘制的层 */
    private var _layerAnimate: CALayer?
    /** 用户配置key补充的部分：eg: jsonKey = ic_loading; partialKey = home; finalKey = ic_loading_home；此情况主要用于完全相同配置的两个动画，对应的图片序列名称不同 */
    /** 图像帧配置json中的key */
    private var _jsonKey: String? {
        if let hk: PYAnimationViewType = animationType {
            if let pk = partial {
                return hk.rawValue + pk
            }
            
            return hk.rawValue
        }
        
        return nil
    }
    /** 当前动画执行到第几帧 */
    private var _currentIndex: Int = 0
    /** 当前帧展示时长 */
    private weak var _currentImage: PYAnimationImage?
    /** 整个动画播放一轮时长 */
    private var _durationAnimation: CFTimeInterval = 0
    /** 切换帧后的时间间隔，每次切换置零 */
    private var _durationSpan: CFTimeInterval = 0
    /** 当前已经循环了几次 */
    private var _loopCount: Int = 0
    private var hasClean: Bool = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.contentMode = .scaleAspectFit
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cleanSelf()
    }
    
    func cleanSelf() {
        if hasClean { return }
        hasClean = true
        _displayLink?.isPaused = true
        _displayLink?.invalidate()
        _imageCache?.removeAll()
    }
    
    /// 配置动画关键配置的key
    func setupAnimationKey(_ key: PYAnimationViewType) { setupAnimationKey(key, partial: nil) }
    func setupAnimationKey(_ key: PYAnimationViewType, partial: String?) {
        animationType = key
        self.partial = partial
        _durationSpan = 0
        _durationAnimation = 0
        _isAnimating = false
        _currentIndex = 0
        animationRepeatCount = 0
        
        if _displayLink == nil {
            _displayLink = CADisplayLink.init(target: self, selector: #selector(handleDisplayChanged))
            _displayLink?.add(to: RunLoop.main, forMode: .common)
        }
        
        _displayLink?.isPaused = true
        
        if _layerAnimate == nil {
            _layerAnimate = CALayer.init()
            layer.addSublayer(_layerAnimate!)
        }
        
        // 装载数据
        if let config = PYViewAnimation.parseAnimation(key.rawValue, partial: partial, tintColor: customTintColor) {
            _imageConfig = config
            _imageCache = []
            indexWhileStopAnimating = config.stopAtIndex
            
            for image in config.imageAnimation {
                if let img = image.image {
                    _imageCache?.append(img)
                }
            }
        }
    }
    
    override func layoutSublayers(of layer: CALayer) {
        if layer != self.layer { return }
        
        // 此处设置自己的layer大小
        _layerAnimate?.bounds = self.bounds
        _layerAnimate?.position = CGPoint.init(x: self.bounds.width/2, y: self.bounds.height/2)
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        
        cleanSelf()
    }
    
    // MARK: - 动画逻辑
    
    @objc private func handleDisplayChanged() {
        guard let link = _displayLink, let images = _imageCache else {
            cleanSelf()
            return
        }
        
        guard let _ = superview else {
            cleanSelf()
            return
        }
        
        guard let curImage = _currentImage else {
            return
        }
        
        _durationSpan += link.duration
        
        if _durationSpan > curImage.duration {
            link.isPaused = true
            
            _durationSpan = 0
            _currentIndex += 1
            
            if _currentIndex >= images.count  {
                _loopCount += 1
                if animationRepeatCount>0 && _loopCount >= animationRepeatCount {
                    animationEnd()
                    return
                }
                
                _currentIndex = 0
            }
            
            if isAnimating {
                animationLoop()
            }
        }
    }
    
    private func animationEnd() {
        _isAnimating = false
        _displayLink?.isPaused = true
        
        if let imgEnd = imageWhileStopAnimating {
            _layerAnimate?.contents = imgEnd
        } else if let indexEnd = indexWhileStopAnimating, let imgEnd = _imageCache?[indexEnd] {
            _layerAnimate?.contents = imgEnd
        }
        self.delegate?.didAnimateEnd(self)
    }
    
    private func animationLoop() {
        if !_isAnimating { return }
        
        guard let image = _imageConfig?.imageAnimation[_currentIndex], let img = _imageCache?[_currentIndex], _isAnimating else {
            animationEnd()
            return
        }
        
        self.delegate?.willDisplayFrame(_currentIndex, animator: self)
        _layerAnimate?.contents = img
        _currentImage = image
        self.delegate?.didDisplayedFrame(_currentIndex, animator: self)
        
        if _isAnimating {
            _displayLink?.isPaused = false
        }
    }
    
}

/// 动画控制
extension PYViewAnimation {
    /// 开始动画
    override func startAnimating() {
        if let _ = _imageCache, !_isAnimating {
            if let caches = _imageCache, _currentIndex >= caches.count {
                _currentIndex = 0
            }
            // 在没有重置数据时，每次开始保持上一次索引
            _isAnimating = true
            animationLoop()
        }
    }
    
    /// 手动停止动画
    override func stopAnimating() {
        if _isAnimating {
            animationEnd()
        }
    }
}

/// 解析json，常量定义
extension PYViewAnimation {
    
    enum PYAnimationViewType: String {
        case loading = "ic_loading"
        case effect_applied = "ic_effect_applied"
    }
    
    static private var allAnimationConfigs: [String:PYAnimationConfig]?
    
    private static func parseAnimation(_ key: String, partial: String?, tintColor: UIColor?) -> PYAnimationConfig? {
        var config: PYAnimationConfig?
        
        let finalKey = key + (partial ?? "")
        
        guard let path = Bundle.main.path(forResource: "animation", ofType: "json") else {
            return nil
        }
        
        if allAnimationConfigs == nil {
            var jsonData: Data?
            do {
                jsonData = try Data.init(contentsOf: URL.init(fileURLWithPath: path))
            } catch { return config }
            
            guard let jData = jsonData else { return config }
            
            // 解析
            guard let dic: [String: Any] = (try? JSONSerialization.jsonObject(with: jData , options: .mutableContainers)) as? [String: Any] else {
                print("数据格式不正确")
                return config
            }
            
            allAnimationConfigs = [:]
            
            // 只解析标准情况
            for (k, v) in dic {
                if let stuff: [Any] = v as? [Any] {
                    let temp = PYAnimationConfig.init(stuff, key: k, partial: nil, tintColor: nil)
                    if temp.isValid() {
                        allAnimationConfigs?[k] = temp
                    }
                }
            }
        }
        
        if let temp = allAnimationConfigs?[finalKey] {
            config = temp
            
        } else if let temp = allAnimationConfigs?[key], let part = partial {
            // 需要重新组合partial
            if let nConfig: PYAnimationConfig = temp.copy() as? PYAnimationConfig {
                nConfig.imageAnimation = nConfig.imageAnimation.map({ (image) -> PYAnimationImage in
                    image.partial = part
                    image.tintColor = tintColor
                    return image
                });
                
                allAnimationConfigs?[finalKey] = nConfig
                config = nConfig
            }
        }
        
        return config
    }
    
    /// 获取动画展示大小
    static func getAnimationSize(_ key: String, partial: String = "") -> CGSize? {
        if let config = parseAnimation(key, partial: partial, tintColor: nil) {
            return config.size
        }
        
        return nil
    }
}


class PYAnimationConfig: NSObject, NSCopying {
    var imageAnimation: [PYAnimationImage]!
    var size: CGSize?
    var stopAtIndex: Int?
    
    override private init() {
        super.init()
    }
    
    init(_ arr: [Any], key: String, partial: String?, tintColor: UIColor?) {
        super.init()
        
        if arr.count>0 {
            imageAnimation = []
            
            var parseIndex = 0
            if let spec: [Int] = arr.first as? [Int] {
                // 解析大小
                size = CGSize.init()
                for index in (0..<spec.count) {
                    if index == 0 { size?.width = CGFloat(spec[index]) }
                    else if index == 1 { size?.height = CGFloat(spec[index]) }
                    else if index == 2 { stopAtIndex = spec[index] }
                }
                
                parseIndex = 1
            }
            
            for index in (parseIndex..<arr.count) {
                var count = 1
                if let stuff: String = arr[index] as? String {
                    var config: String = stuff
                    // 解析倍数
                    if config.contains("*") {
                        let mutiple = config.components(separatedBy: "*")
                        config = mutiple.first!
                        if mutiple.count>1 {
                            if let c = Int(mutiple.last!) {
                                count =  c
                            }
                        }
                    }
                    
                    while count > 0 {
                        let span = config.components(separatedBy: ":")
                        if span.count == 2 {
                            let from = span[0]
                            let duration = Int(span[1])
                            var start: Int?
                            var end: Int?
                            
                            if from.contains("~") {
                                let frames = from.components(separatedBy: "~")
                                if frames.count == 2 {
                                    start = Int(frames[0])
                                    end = Int(frames[1])
                                }
                            } else {
                                start = Int(from)
                                end = start
                            }
                            
                            if let begin = start, let finish = end, let dur = duration {
                                var index = begin
                                
                                while true {
                                    let image = PYAnimationImage.init(key, partial: partial, index:index , duration: dur, tintColor: tintColor)
                                    
                                    imageAnimation?.append(image)
                                    
                                    index = index + (begin > finish ? -1 : 1)
                                    
                                    if begin > finish {
                                        if index < finish { break }
                                    } else {
                                        if index > finish { break }
                                    }
                                    
                                    if abs(index) > 100 { break }
                                }
                            }
                        }
                        
                        count -= 1
                    }
                }
            }
        }
    }
    
    func isValid() -> Bool {
        return imageAnimation != nil
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let config = PYAnimationConfig.init()
        config.imageAnimation = imageAnimation.map{( $0.copy() as! PYAnimationImage )}
        config.size = size
        config.stopAtIndex = stopAtIndex
        return config
    }
}

/// 目前只考虑包里面的图像
class PYAnimationImage: NSObject, NSCopying {
    var tintColor: UIColor?
    /** 图像在png中认为的序列，非播放序列 */
    private var _indexOfFrame: Int = 0
    var duration: CFTimeInterval = 0
    var key: String!
    var partial: String?
    /** 图像，每次需要动画时动态解析出来，不要缓存 */
    var image: CGImage? {
        var temp: CGImage?
        
        let imageName = key + (partial ?? "") + String(format: "%03d", _indexOfFrame)
        
        if let img = UIImage.init(contentsOfFile:key + "/" + imageName) {
            temp = img.cgImage
        } else if let img = UIImage.init(named: imageName) {
            temp = img.cgImage
        } else if let img = UIImage.init(contentsOfFile: imageName) {
            temp = img.cgImage
        } else {
            if let path = Bundle.main.path(forResource: imageName, ofType: "png"), let img = UIImage.init(contentsOfFile: path) {
                temp = img.cgImage
            }
        }
        
        return temp
    }
    
    override private init() {
        super.init()
    }
    
    init(_ key: String, partial: String?, index: Int, duration: Int, tintColor: UIColor?) {
        super.init()
        self.key = key
        self.partial = partial
        _indexOfFrame = index
        self.duration = Double(duration)/1000.0 as CFTimeInterval
        self.tintColor = tintColor
    }
    
    func copy(with zone: NSZone? = nil) -> Any {
        let animation = PYAnimationImage.init()
        animation.tintColor = tintColor
        animation.duration = duration
        animation.key = key
        animation.partial = partial
        animation._indexOfFrame = _indexOfFrame
        return animation
    }
}


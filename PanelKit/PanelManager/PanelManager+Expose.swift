//
//  PanelManager+Expose.swift
//  PanelKit
//
//  Created by Louis D'hauwe on 24/02/2017.
//  Copyright © 2017 Silver Fox. All rights reserved.
//

import Foundation

private var exposeOverlayViewKey: UInt8 = 0
private var exposeOverlayTapRecognizerKey: UInt8 = 0
private var exposeEnterTapRecognizerKey: UInt8 = 0

extension PanelManager {

	var exposeOverlayView: UIVisualEffectView {
		get {
			return associatedObject(self, key: &exposeOverlayViewKey) {
				return UIVisualEffectView(effect: nil)
			}
		}
		set {
			associateObject(self, key: &exposeOverlayViewKey, value: newValue)
		}
	}

	var exposeOverlayTapRecognizer: BlockGestureRecognizer {
		get {
			return associatedObject(self, key: &exposeOverlayTapRecognizerKey) {

				let gestureRecognizer = UITapGestureRecognizer()

				let blockRecognizer = BlockGestureRecognizer(view: exposeOverlayView, recognizer: gestureRecognizer, closure: {

					if self.isInExpose {
						self.exitExpose()
					}
				})

				return blockRecognizer
			}
		}
		set {
			associateObject(self, key: &exposeOverlayTapRecognizerKey, value: newValue)
		}
	}

	var exposeEnterTapRecognizer: BlockGestureRecognizer {
		get {
			return associatedObject(self, key: &exposeEnterTapRecognizerKey) {

				let tapGestureRecognizer = UITapGestureRecognizer()
				tapGestureRecognizer.numberOfTapsRequired = 2
				tapGestureRecognizer.numberOfTouchesRequired = 3

				let blockRecognizer = BlockGestureRecognizer(view: panelContentWrapperView, recognizer: tapGestureRecognizer) {

					self.toggleExpose()

				}

				return blockRecognizer
			}
		}
		set {
			associateObject(self, key: &exposeEnterTapRecognizerKey, value: newValue)
		}
	}

}

public extension PanelManager {

	var exposeOverlayBlurEffect: UIBlurEffect {
		return UIBlurEffect(style: .light)
	}

	func enableTripleTapExposeActivation() {

		_ = exposeEnterTapRecognizer

	}

	func toggleExpose() {

		if isInExpose {
			exitExpose()
		} else {
			enterExpose()
		}

	}

	var isInExpose: Bool {

		for panel in panels {
			if panel.isInExpose {
				return true
			}
		}

		return false
	}

	func enterExpose() {

		guard !isInExpose else {
			return
		}

		addExposeOverlayViewIfNeeded()

		let exposePanels = panels.filter { (p) -> Bool in
			return p.isPinned || p.isFloating
		}

		guard !exposePanels.isEmpty else {
			return
		}

		willEnterExpose()

		let (panelFrames, scale) = calculateExposeFrames(with: exposePanels)

		for panelFrame in panelFrames {
			panelFrame.panel.frameBeforeExpose = panelFrame.panel.view.frame
			updateFrame(for: panelFrame.panel, to: panelFrame.exposeFrame)
		}

		exposeOverlayView.isUserInteractionEnabled = true

		UIView.animate(withDuration: 0.3, delay: 0.0, options: [], animations: {

			self.exposeOverlayView.effect = self.exposeOverlayBlurEffect

			self.panelContentWrapperView.layoutIfNeeded()

			for panelFrame in panelFrames {

				panelFrame.panel.view.transform = CGAffineTransform(scaleX: scale, y: scale)

			}

		})

	}

	func exitExpose() {

		guard isInExpose else {
			return
		}

		let exposePanels = panels.filter { (p) -> Bool in
			return p.isInExpose
		}

		guard !exposePanels.isEmpty else {
			return
		}

		willExitExpose()

		for panel in exposePanels {
			if let frameBeforeExpose = panel.frameBeforeExpose {
				updateFrame(for: panel, to: frameBeforeExpose)
				panel.frameBeforeExpose = nil
			}
		}

		exposeOverlayView.isUserInteractionEnabled = false

		UIView.animate(withDuration: 0.3, delay: 0.0, options: [], animations: {

			self.exposeOverlayView.effect = nil

			self.panelContentWrapperView.layoutIfNeeded()

			for panel in exposePanels {

				panel.view.transform = .identity

			}

		})

	}

}

extension PanelManager {

	func addExposeOverlayViewIfNeeded() {

		if exposeOverlayView.superview == nil {

			exposeOverlayView.translatesAutoresizingMaskIntoConstraints = false

			panelContentWrapperView.addSubview(exposeOverlayView)
			panelContentWrapperView.insertSubview(exposeOverlayView, aboveSubview: panelContentView)

			exposeOverlayView.topAnchor.constraint(equalTo: panelContentView.topAnchor).isActive = true
			exposeOverlayView.bottomAnchor.constraint(equalTo: panelContentView.bottomAnchor).isActive = true
			exposeOverlayView.leadingAnchor.constraint(equalTo: panelContentWrapperView.leadingAnchor).isActive = true
			exposeOverlayView.trailingAnchor.constraint(equalTo: panelContentWrapperView.trailingAnchor).isActive = true

			exposeOverlayView.alpha = 1.0

			exposeOverlayView.isUserInteractionEnabled = false

			panelContentWrapperView.layoutIfNeeded()

			let _ = exposeOverlayTapRecognizer
		}

	}

	func calculateExposeFrames(with panels: [PanelViewController]) -> ([PanelExposeFrame], CGFloat) {

		let panelFrames: [PanelExposeFrame] = panels.map { (p) -> PanelExposeFrame in
			return PanelExposeFrame(panel: p)
		}

		distribute(panelFrames)

		guard let unionFrame = unionRect(with: panelFrames) else {
			return (panelFrames, 1.0)
		}

		print("unionFrame: \(unionFrame)")

		for r in panelFrames {

			r.exposeFrame.origin.x -= unionFrame.origin.x
			r.exposeFrame.origin.y -= unionFrame.origin.y

		}

		var normalizedUnionFrame = unionFrame
		normalizedUnionFrame.origin.x = 0.0
		normalizedUnionFrame.origin.y = 0.0

		print("normalizedUnionFrame: \(normalizedUnionFrame)")

		let padding: CGFloat = 44.0

		let scale = min(1.0, min(((panelContentView.frame.width - padding) / unionFrame.width), ((panelContentView.frame.height - padding) / unionFrame.height)))

		print("scale: \(scale)")

		var scaledNormalizedUnionFrame = normalizedUnionFrame
		scaledNormalizedUnionFrame.size.width *= scale
		scaledNormalizedUnionFrame.size.height *= scale

		print("scaledNormalizedUnionFrame: \(scaledNormalizedUnionFrame)")

		for r in panelFrames {

			r.exposeFrame.origin.x *= scale
			r.exposeFrame.origin.y *= scale

			let width = r.exposeFrame.size.width
			let height = r.exposeFrame.size.height

			r.exposeFrame.origin.x -= width * (1.0 - scale) / 2
			r.exposeFrame.origin.y -= height * (1.0 - scale) / 2

			// Center

			r.exposeFrame.origin.x += (max(panelContentView.frame.width - scaledNormalizedUnionFrame.width, 0.0)) / 2.0
			r.exposeFrame.origin.y += (max(panelContentView.frame.height - scaledNormalizedUnionFrame.height, 0.0)) / 2.0
			r.exposeFrame.origin.y += panelContentView.frame.origin.y

		}

		return (panelFrames, scale)

	}

	func doFramesIntersect(_ frames: [PanelExposeFrame]) -> Bool {

		for r1 in frames {

			for r2 in frames {
				if r1 === r2 {
					continue
				}

				if numberOfIntersections(of: r1, with: [r2]) > 0 {
					return true
				}

			}

		}

		return false

	}

	func numberOfIntersections(of frame: PanelExposeFrame, with frames: [PanelExposeFrame]) -> Int {

		var intersections = 0

		let r1 = frame

		for r2 in frames {
			if r1 === r2 {
				continue
			}

			let r1InsetFrame = r1.exposeFrame.insetBy(dx: -20.0, dy: -20.0)
			if r1InsetFrame.intersects(r2.exposeFrame) {
				intersections += 1
			}

		}

		return intersections
	}

	func unionRect(with frames: [PanelExposeFrame]) -> CGRect? {

		guard var rect = frames.first?.exposeFrame else {
			return nil
		}

		for r in frames {

			rect = rect.union(r.exposeFrame)

		}

		return rect

	}

	func distribute(_ frames: [PanelExposeFrame]) {

		var frames = frames

		var stack = [PanelExposeFrame]()

		while doFramesIntersect(frames) {

			var sortedFrames = frames.sorted(by: { (r1, r2) -> Bool in
				let n1 = numberOfIntersections(of: r1, with: frames)
				let n2 = numberOfIntersections(of: r2, with: frames)
				return n1 > n2
			})

			let mostIntersected = sortedFrames[0]

			stack.append(mostIntersected)

			frames.remove(at: frames.index(where: { (r) -> Bool in
				r === mostIntersected
			})!)

		}

		while !stack.isEmpty {

			let last = stack.popLast()!

			frames.append(last)

			guard let unionRect = self.unionRect(with: frames) else {
				break
			}

			let g = CGPoint(x: unionRect.midX, y: unionRect.midY)

			let deltaX = max(1.0, last.panel.view.center.x - g.x)
			let deltaY = max(1.0, last.panel.view.center.y - g.y)

			while numberOfIntersections(of: last, with: frames) > 0 {

				last.exposeFrame.origin.x += deltaX / 20.0
				last.exposeFrame.origin.y += deltaY / 20.0

			}

		}

	}

}

class PanelExposeFrame {

	let panel: PanelViewController
	var exposeFrame: CGRect

	init(panel: PanelViewController) {
		self.panel = panel
		self.exposeFrame = panel.view.frame
	}

}

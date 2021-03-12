////
// 🦠 Corona-Warn-App
//

import UIKit
import AVFoundation
import OpenCombine

class CheckinQRCodeScannerViewController: UIViewController {

	// MARK: - Init

	init(
		didScanCheckin: @escaping (Checkin) -> Void,
		dismiss: @escaping () -> Void
	) {
		self.didScanCheckin = didScanCheckin
		self.viewModel = CheckinQRCodeScannerViewModel()
		self.dismiss = dismiss
		super.init(nibName: nil, bundle: nil)
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Overrides

	override func viewDidLoad() {
		super.viewDidLoad()
		setupView()
		setupViewModel()
		setupNavigationBar()
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		setNeedsPreviewMaskUpdate()
		updatePreviewMaskIfNeeded()
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		viewModel.deactivateScanning()
	}

	// MARK: - Private

	@IBOutlet private weak var instructionLabel: ENALabel!
	@IBOutlet private weak var focusView: QRScannerFocusView!

	private let didScanCheckin: (Checkin) -> Void
	private let dismiss: () -> Void

	private let viewModel: CheckinQRCodeScannerViewModel
	private var previewLayer: AVCaptureVideoPreviewLayer! { didSet { setNeedsPreviewMaskUpdate() } }
	private var needsPreviewMaskUpdate: Bool = true

	private func setupView() {
		navigationItem.title = AppStrings.Checkin.QRScanner.title
		view.backgroundColor = .enaColor(for: .background)
		instructionLabel.text = AppStrings.Checkin.QRScanner.instruction

		instructionLabel.layer.shadowColor = UIColor.enaColor(for: .textPrimary1Contrast).cgColor
		instructionLabel.layer.shadowOpacity = 1
		instructionLabel.layer.shadowRadius = 3
		instructionLabel.layer.shadowOffset = .init(width: 0, height: 0)
	}
	
	private func setupNavigationBar() {
		if #available(iOS 13.0, *) {
			navigationController?.overrideUserInterfaceStyle = .dark
		}
		navigationController?.navigationBar.tintColor = .enaColor(for: .textContrast)
		navigationController?.navigationBar.shadowImage = UIImage()
		if let image = UIImage.with(color: UIColor(white: 0, alpha: 0.5)) {
			navigationController?.navigationBar.setBackgroundImage(image, for: .default)
		}

		let cancelItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didPressDismiss))
		cancelItem.accessibilityIdentifier = AccessibilityIdentifiers.General.cancelButton
		navigationItem.leftBarButtonItem = cancelItem

		let flashButton = UIButton(type: .custom)
		flashButton.imageView?.contentMode = .center
		flashButton.addTarget(self, action: #selector(didToggleFlash), for: .touchUpInside)
		flashButton.setImage(UIImage(named: "flash-off"), for: .normal)
		flashButton.setImage(UIImage(named: "bolt.fill"), for: .selected)
		flashButton.accessibilityLabel = AppStrings.ExposureSubmissionQRScanner.flashButtonAccessibilityLabel
		flashButton.accessibilityIdentifier = AccessibilityIdentifiers.ExposureSubmissionQRScanner.flash
		flashButton.accessibilityTraits = [.button]
		navigationItem.rightBarButtonItem = UIBarButtonItem(customView: flashButton)
	}

	@objc
	private func didPressDismiss() {
		dismiss()
	}
	
	@objc
	private func didToggleFlash() {
		viewModel.toggleFlash(completion: { [weak self] in
			DispatchQueue.main.async {
				self?.updateToggleFlashAccessibility()
			}
		})
	}
	
	private func updateToggleFlashAccessibility() {
		guard let flashButton = navigationItem.rightBarButtonItem?.customView as? UIButton else {
			return
		}

		flashButton.accessibilityCustomActions?.removeAll()

		switch viewModel.torchMode {
		case .notAvailable:
			flashButton.isEnabled = false
			flashButton.isSelected = false
			flashButton.accessibilityValue = nil
		case .lightOn:
			flashButton.isEnabled = true
			flashButton.isSelected = true
			flashButton.accessibilityValue = AppStrings.ExposureSubmissionQRScanner.flashButtonAccessibilityOnValue
			flashButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: AppStrings.ExposureSubmissionQRScanner.flashButtonAccessibilityDisableAction, target: self, selector: #selector(didToggleFlash))]
		case .ligthOff:
			flashButton.isEnabled = true
			flashButton.isSelected = false
			flashButton.accessibilityValue = AppStrings.ExposureSubmissionQRScanner.flashButtonAccessibilityOffValue
			flashButton.accessibilityCustomActions = [UIAccessibilityCustomAction(name: AppStrings.ExposureSubmissionQRScanner.flashButtonAccessibilityEnableAction, target: self, selector: #selector(didToggleFlash))]
		}
	}

	private func setupViewModel() {
		guard let captureSession = viewModel.captureSession else {
			Log.debug("Failed to setup captureSession", log: .checkin)
			return
		}
		viewModel.startCaptureSession()

		previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
		previewLayer.frame = view.layer.bounds
		previewLayer.videoGravity = .resizeAspectFill
		view.layer.insertSublayer(previewLayer, at: 0)

		viewModel.onSuccess = { [weak self] checkin in
			guard let self = self else {
				return
			}
			AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
			self.viewModel.deactivateScanning()
			self.didScanCheckin(checkin)
		}

		viewModel.onError = { [weak self] error in
			switch error {
			// for the moment we always show the same alert
			case .cameraPermissionDenied:
				DispatchQueue.main.async {
					self?.dismiss()
				}
			case .codeNotFound:
				self?.showErrorAlert()
			case .other:
				self?.showErrorAlert()
			}
		}
	}

	private func showErrorAlert() {

		viewModel.deactivateScanning()

		let alert = UIAlertController(
			title: AppStrings.Checkin.QRScanner.Error.title,
			message: AppStrings.Checkin.QRScanner.Error.description,
			preferredStyle: .alert
		)
		alert.addAction(
			UIAlertAction(
				title: AppStrings.Common.alertActionCancel,
				style: .cancel,
				handler: { [weak self] _ in
					self?.dismiss()
				}
			)
		)
		alert.addAction(UIAlertAction(title: AppStrings.Common.alertActionOk, style: .default, handler: { [weak self] _ in
			self?.viewModel.activateScanning()
		}))

		DispatchQueue.main.async { [weak self] in
			self?.present(alert, animated: true)
		}
	}
	private func setNeedsPreviewMaskUpdate() {
		guard needsPreviewMaskUpdate else { return }
		needsPreviewMaskUpdate = true

		DispatchQueue.main.async(execute: updatePreviewMaskIfNeeded)
	}

	private func updatePreviewMaskIfNeeded() {
		guard needsPreviewMaskUpdate,
			  let previewLayer = previewLayer,
			  focusView.backdropOpacity > 0 else {
			needsPreviewMaskUpdate = false
			self.previewLayer?.mask = nil
			return
		}

		let backdropColor = UIColor(white: 0, alpha: 1 - max(0, min(focusView.backdropOpacity, 1)))
		let focusPath = UIBezierPath(roundedRect: focusView.frame, cornerRadius: focusView.layer.cornerRadius)

		let backdropPath = UIBezierPath(cgPath: focusPath.cgPath)
		backdropPath.append(UIBezierPath(rect: view.bounds))

		let backdropLayer = CAShapeLayer()
		backdropLayer.path = UIBezierPath(rect: view.bounds).cgPath
		backdropLayer.fillColor = backdropColor.cgColor

		let backdropLayerMask = CAShapeLayer()
		backdropLayerMask.fillRule = .evenOdd
		backdropLayerMask.path = backdropPath.cgPath
		backdropLayer.mask = backdropLayerMask

		let throughHoleLayer = CAShapeLayer()
		throughHoleLayer.path = UIBezierPath(cgPath: focusPath.cgPath).cgPath

		previewLayer.mask = CALayer()
		previewLayer.mask?.addSublayer(throughHoleLayer)
		previewLayer.mask?.addSublayer(backdropLayer)
	}
}

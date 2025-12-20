//
//  QrCodeController.swift
//  Cser2022
//
//  Copyright © 2021 High Sierra. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

class QrCodeController: UIViewController {
    
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    var isSendNotif = false
    var scanType: String = "barcode"
    var isMultiple: Bool = false
    var scanResults: [String] = []
    private var statusLabel: UILabel?
    @IBOutlet weak var qrCodeView: UIView!
    @IBOutlet weak var btBack: UIImageView!
    @IBOutlet weak var btFlash: UIImageView!
    
    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
    private lazy var barcodeTypes: [AVMetadataObject.ObjectType] = {
        return supportedCodeTypes.filter { $0 != .qr }
    }()
    @objc func onBack(_ ges: UITapGestureRecognizer) {
        if isMultiple {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "SCAN_BARCODE_RESULT"), object: nil, userInfo: ["codes" : scanResults])
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func onFlash(_ ges: UITapGestureRecognizer) {
        toggleFlash()
    }
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        guard device.hasTorch else { return }

        do {
            try device.lockForConfiguration()

            if (device.torchMode == AVCaptureDevice.TorchMode.on) {
                device.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    try device.setTorchModeOn(level: 1.0)
                } catch {
                    print(error)
                }
            }

            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let gesBack = UITapGestureRecognizer(target: self, action: #selector(onBack(_:)))
        gesBack.numberOfTapsRequired = 1
        gesBack.numberOfTouchesRequired = 1
        btBack.addGestureRecognizer(gesBack)
        btBack.isUserInteractionEnabled = true
        
        let gesFlash = UITapGestureRecognizer(target: self, action: #selector(onFlash(_:)))
        gesFlash.numberOfTapsRequired = 1
        gesFlash.numberOfTouchesRequired = 1
        btFlash.addGestureRecognizer(gesFlash)
        btFlash.isUserInteractionEnabled = true
        
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.numberOfLines = 2
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.alpha = 0
        label.layer.zPosition = 2
        statusLabel = label
        
        
        
        // Get the back-facing camera for capturing videos
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get the camera device")
            return
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Set the input device on the capture session
            captureSession.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
//            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
            if scanType == "qrcode" {
                captureMetadataOutput.metadataObjectTypes = [.qr]
            } else if scanType == "barcode" {
                captureMetadataOutput.metadataObjectTypes = barcodeTypes
            } else {
                captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            }
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            qrCodeView.layer.addSublayer(videoPreviewLayer!)
            if let label = statusLabel {
                qrCodeView.addSubview(label)
                qrCodeView.bringSubviewToFront(label)
            }
            
            // Start video capture
            captureSession.startRunning()
            
            
            // Initialize QR Code Frame to highlight the QR Code
            qrCodeFrameView = UIView()

            if let qrcodeFrameView = qrCodeFrameView {
                qrcodeFrameView.layer.borderColor = UIColor.yellow.cgColor
                qrcodeFrameView.layer.borderWidth = 2
                qrCodeView.addSubview(qrcodeFrameView)
                qrCodeView.bringSubviewToFront(qrcodeFrameView)
            }
            
        } catch {
            // If any error occurs, simply print it out and don't continue anymore
            print(error)
            return
        }
    }
    
}

extension QrCodeController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
//            messageLabel.text = "No QR code is detected"
            return
        }
        
        // Get the metadata object
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if let code = metadataObj.stringValue, !code.isEmpty {
                if isMultiple {
                    if scanResults.contains(code) {
                        showStatus("Mã \(code) đã có")
                    } else {
                        scanResults.append(code)
                        showStatus("Đã ghi nhận mã \(code)")
                    }
                    return
                }
                if (!isSendNotif) {
                    isSendNotif = true
                    if isMultiple {
                        showStatus("Đã ghi nhận mã \(code)")
                    }
                    let notifName = scanType == "qrcode" ? "QRCODE" : "SCAN_BARCODE_RESULT"
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: notifName) , object: nil, userInfo: ["code" : code])
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        }
    }
}

private extension QrCodeController {
    func showStatus(_ message: String) {
        guard let label = statusLabel else { return }
        label.text = message
        let padding: CGFloat = 12
        let maxWidth = qrCodeView.bounds.width - 32
        let size = label.sizeThatFits(CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        let labelWidth = min(maxWidth, size.width + padding * 2)
        let labelHeight = size.height + padding
        let yPos = max(16, qrCodeView.bounds.height - 50 - labelHeight)
        label.frame = CGRect(
            x: (qrCodeView.bounds.width - labelWidth) / 2,
            y: yPos,
            width: labelWidth,
            height: labelHeight
        )
        label.alpha = 1
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(hideStatus), object: nil)
        perform(#selector(hideStatus), with: nil, afterDelay: 1.2)
    }
    
    @objc func hideStatus() {
        statusLabel?.alpha = 0
    }
}

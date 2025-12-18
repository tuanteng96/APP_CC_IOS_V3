//
//  AttachmentHandler.swift
//  Cser21
//
//  Created by Hung-Catalina on 3/21/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//


import UIKit
import AVKit
//import AssetsLibrary
import Photos
import MobileCoreServices

enum AttachmentType: String {
    case camera, video, photoLibrary
}

enum AttachmentMenu {
    case camera, video, photoLibrary, document
}

class AttachmentHandler: NSObject {
    
    // MARK: - Internal Properties
    
    static let shared = AttachmentHandler()
    fileprivate var currentVC: UIViewController?
    var actionSheetController: UIAlertController?
    
    var imagePickedBlock: ((UIImage) -> Void)?
    var videoPickedBlock: ((NSURL) -> Void)?
    var filePickedBlock: ((URL) -> Void)?
    
   
    var captionVideo = false

    public func showCamera(vc: UIViewController  ){
        currentVC = vc;
        self.openCamera()
    }
   
    
    func openCamera( ) {
        DispatchQueue.main.async { () -> Void in
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let myPickerController = UIImagePickerController()
                myPickerController.delegate = self
                myPickerController.sourceType = .camera
                
                if(self.captionVideo) {
                    myPickerController.mediaTypes = [kUTTypeMovie as String]
                }
                
                self.currentVC?.present(myPickerController, animated: true, completion: nil)
            }
        }
    }
    
    
    
    func photoLibrary() {
        DispatchQueue.main.async { () -> Void in
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let myPickerController = UIImagePickerController()
                myPickerController.delegate = self
                myPickerController.sourceType = .photoLibrary
                self.currentVC?.present(myPickerController, animated: true, completion: nil)
            }
        }
    }
    
    
    
    func videoLibrary() {
        DispatchQueue.main.async { () -> Void in
            
            if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                let myPickerController = UIImagePickerController()
                myPickerController.delegate = self
                myPickerController.sourceType = .photoLibrary
                myPickerController.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
                self.currentVC?.present(myPickerController, animated: true, completion: nil)
            }
        }
    }
    
    func documentPicker() {
        DispatchQueue.main.async { () -> Void in
            let importMenu = UIDocumentMenuViewController(documentTypes: [String(kUTTypePDF)], in: .import)
            importMenu.delegate = self
            importMenu.modalPresentationStyle = .formSheet
            self.currentVC?.present(importMenu, animated: true, completion: nil)
        }
    }
}

// MARK: - Private Methods

extension AttachmentHandler {
    
   
    
}

// MARK: - UIImagePicker Delegate

extension AttachmentHandler: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            let fixedImage = image.fixOrientation()
            self.imagePickedBlock?(fixedImage)
        } else {
        }
        // To handle video
        if let videoUrl = info[UIImagePickerController.InfoKey.mediaURL] as? NSURL {
            //trying compression of video
            let data = NSData(contentsOf: videoUrl as URL)!
            print("File size before compression: \(Double(data.length / 1048576)) mb")
            self.videoPickedBlock?(videoUrl)
        } else {
        }
        currentVC?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        currentVC?.dismiss(animated: true, completion: nil)
    }
    
}

// MARK: - UIDocumentPicker Delegate

extension AttachmentHandler: UIDocumentPickerDelegate, UIDocumentMenuDelegate {
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        currentVC?.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.filePickedBlock?(url)
    }
    
    //    Method to handle cancel action.
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        currentVC?.dismiss(animated: true, completion: nil)
    }
    
}

extension UIImage {
    func fixOrientation() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}

//
//  ImageUtil.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/8/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//
import UIKit
import Foundation
class ImageUtil{
    var app21: App21? = nil
    func execute(result: Result) -> Void {
        DispatchQueue.global().async(execute: {
            
            do{
                let d = DownloadFileTask();
                let decoder = JSONDecoder()
                
                let info = try decoder.decode(ImageUtilInfo.self, from: result.params!.data(using: .utf8)!)
                let data = d.localToData(filePath: info.path)
                
                let image = UIImage(data: data)
                //let _image = image?.rotate(radians: CGFloat(info.degrees) * CGFloat(Double.pi) / 180 )
                let _image = image?.rotate(radians: Float(info.degrees) * Float(Double.pi) / 180 )
               
                let ext = String( d.getName(path: info.path).split(separator: ".").last!).lowercased()
               
                let _data = ext == "png" ? _image!.pngData() : _image!.jpegData(compressionQuality: 1);
                let name = d.getName(path: info.path)
                let filename = d.getDocumentsDirectory().appendingPathComponent(name)
                
                //let path = filename.path
                
                //try _data!.write(to: filename)
                let e =  try self.dataToFile(data: _data!, path: filename)
                result.success = e == nil ;
                if(e != nil)
                {
                    result.error = e?.localizedDescription;
                }
                self.app21?.App21Result(result: result)
            }
            catch{
                result.success = false;
                result.error = error.localizedDescription;
                self.app21?.App21Result(result: result)
            }
        })
        
    }
    
    func dataToFile(data: Data, path: URL)  throws -> Error? {
        do{
            try data.write(to: path)
            return nil
        }
        catch{
            return error
        }
    }
}

class ImageUtilInfo : Codable{
    var degrees: Float = 0
    var path: String = ""
}
extension UIImage {
    
    func rotate(radians: Float) -> UIImage? {
        var newSize = CGRect(origin: CGPoint.zero, size: self.size).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!

        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}

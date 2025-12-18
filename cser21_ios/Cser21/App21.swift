//
//  App21.swift
//  Cser21
//
//  Created by Hung-Catalina on 3/21/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//
import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import Photos
import AudioToolbox
import KeychainSwift
import FirebaseMessaging



class App21 : NSObject, CLLocationManagerDelegate
{
    var caller:  ViewController
    init(viewController: ViewController)
    {
        caller = viewController;
        
    }
    
    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    

    //MARK: - App21Result
    func App21Result(result: Result) -> Void {
        do {
           result.raw = nil;
            
           let jsonEncoder = JSONEncoder()
           let jsonData = try jsonEncoder.encode(result)
           let json = String(data: jsonData, encoding: String.Encoding.utf8)
           //chuyen ve base64 -> khong bi loi ky tu dac biet
           let base64 = json?.base64Encoded();
           DispatchQueue.main.async(execute: {
               self.caller.evalJs(str: "App21Result('BASE64:" + base64! + "')");
           })
        } catch  {
            //
            NSLog("App21Result -> " + error.localizedDescription);
        }
        
    }
    
    
    //MARK: - call
    func call(jsonStr: String) -> Void {
        let result = Result()

        do {
            let data = jsonStr.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

            result.sub_cmd = json?["sub_cmd"] as? String
            result.sub_cmd_id = json?["sub_cmd_id"] as? Int ?? 0

            // ⚠️ params của bạn có lúc là String, có lúc là Object -> ép về String cho chắc
            if let pStr = json?["params"] as? String {
                result.params = pStr
            } else if let pObj = json?["params"] {
                if JSONSerialization.isValidJSONObject(pObj),
                   let pData = try? JSONSerialization.data(withJSONObject: pObj, options: []),
                   let pStr = String(data: pData, encoding: .utf8) {
                    result.params = pStr
                }
            }

            // 2024/12/18
            result.raw = jsonStr

            let cmd = result.sub_cmd ?? ""
            let selector = Selector(cmd + "WithResult:")

            // ✅ check method tồn tại thật sự (đừng dùng hashValue)
            if !self.responds(to: selector) {
                result.success = false
                result.error = cmd + " NOT FOUND"
                App21Result(result: result)
                return
            }

            // ✅ Những lệnh đụng UI phải chạy MAIN thread
            let uiCommands: Set<String> = [
                "CHOOSE_IMAGES",
                "CHOOSE_FILES",
                "CAMERA",
                "RECORD_VIDEO",
                "OPEN_QRCODE",
                "BACKGROUND",
                "STATUS_BAR_COLOR",
                "WV_VISIBLE"
            ]

            if uiCommands.contains(cmd) {
                self.performSelector(onMainThread: selector, with: result, waitUntilDone: false)
            } else {
                self.performSelector(inBackground: selector, with: result)
            }

        } catch {
            result.success = false
            result.error = error.localizedDescription
            App21Result(result: result)
        }
    }
    
    func logSize(_ label: String, _ bytes: Int) {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb >= 1 {
            NSLog("📦 \(label): \(String(format: "%.2f", mb)) MB")
        } else {
            NSLog("📦 \(label): \(String(format: "%.2f", kb)) KB")
        }
    }
    
    //MARK: - BACKGROUND
    @objc func BACKGROUND(result: Result) -> Void {
        //
        result.success = true;
        App21Result(result: result);
        DispatchQueue.main.async { // Correct
            self.caller.setBackground(params: result.params)
        }
    }
    
    //MARK: - STATUS BAR COLOR
    @objc func STATUS_BAR_COLOR(result: Result) -> Void {
        //
        result.success = true;
        App21Result(result: result);
        DispatchQueue.main.async { // Correct
            self.caller.changeStatusBarColor(params: result.params)
        }
    }
    
    //MARK: - CHOOSE IMAGES
    @objc func CHOOSE_IMAGES(result: Result) -> Void {
        NSLog("📥 CHOOSE_IMAGES params: %@", result.params ?? "nil")

        guard let params = result.params, let jsonData = params.data(using: .utf8) else {
            result.success = false
            result.error = "params is nil"
            self.App21Result(result: result)
            return
        }

        // ===== Parse params =====
        var isMultiple = true
        var shouldCompress = false
        var maxSide: CGFloat = 1280
        var maxKB: Int = 350
        var ext: String = "png"
        var pref: String = "IMG"
        var accept: String? = "image/*"

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                NSLog("📦 CHOOSE_IMAGES params dict: %@", dict)

                accept = dict["accept"] as? String
                isMultiple = (dict["isMultiple"] as? Bool) ?? true
                shouldCompress = (dict["isCompressed"] as? Bool) ?? false

                if let side = dict["maxSide"] as? Double { maxSide = CGFloat(side) }
                else if let side = dict["maxSide"] as? Int { maxSide = CGFloat(side) }

                if let kb = dict["maxKB"] as? Int { maxKB = kb }
                else if let kb = dict["maxKB"] as? Double { maxKB = Int(kb) }

                if let e = dict["ext"] as? String, !e.isEmpty { ext = e.lowercased() }
                if let p = dict["pref"] as? String, !p.isEmpty { pref = p }
            }
        } catch {
            result.success = false
            result.error = "Parse JSON ERROR: \(error.localizedDescription)"
            self.App21Result(result: result)
            return
        }

        // ✅ Nếu nén: luôn dùng JPG để tránh PNG phình size
        if shouldCompress { ext = "jpg" }

        NSLog("📌 CHOOSE_IMAGES config -> accept=%@ isMultiple=%@ isCompressed=%@ maxSide=%d maxKB=%d ext=%@ pref=%@",
              (accept ?? "nil"),
              isMultiple.description,
              shouldCompress.description,
              Int(maxSide),
              maxKB,
              ext,
              pref)

        DispatchQueue.main.async {
            // xin quyền photo cho chắc (nhất là iOS < 14 dùng UIImagePicker)
            self._PERMISSION(permission: .photoLibrary, result: result, ok: { _ in

                // ✅ nếu ViewController bạn chưa có accept param thì đổi lại call cũ
                self.caller.presentMultiImagePicker(isMulti: isMultiple, accept: accept, completion: { imagePaths in
                    NSLog("🖼️ Picked \(imagePaths.count) images")

                    var out: [String] = []
                    out.reserveCapacity(imagePaths.count)

                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let folder = docs.appendingPathComponent("ImagePicker", isDirectory: true)
                    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

                    let formatter = DateFormatter()
                    formatter.dateFormat = "ddMMyyyyHHmmss"

                    for (idx, url) in imagePaths.enumerated() {

                        // ===== Không nén -> copy như cũ =====
                        if !shouldCompress {
                            let src = DownloadFileTask().saveURL2(
                                url: url,
                                suffix: "ImagePicker-\(url.lastPathComponent)"
                            )
                            out.append(src)
                            continue
                        }

                        // ===== Nén =====
                        guard let image = UIImage(contentsOfFile: url.path) else {
                            NSLog("⚠️ Cannot load UIImage from: %@", url.path)
                            // fallback copy
                            let src = DownloadFileTask().saveURL2(url: url, suffix: "ImagePicker-\(url.lastPathComponent)")
                            out.append(src)
                            continue
                        }

                        let fixed = image.fixedOrientation()

                        // log size before (jpeg quality 1.0)
                        if let before = fixed.jpegData(compressionQuality: 1.0) {
                            self.logSize("Picker[\(idx)] original", before.count)
                        } else {
                            NSLog("📦 Picker[%d] original: (jpegData nil)", idx)
                        }

                        let resized = fixed.resized(maxSide: maxSide)

                        if let afterResize = resized.jpegData(compressionQuality: 1.0) {
                            self.logSize("Picker[\(idx)] after resize (maxSide=\(Int(maxSide)))", afterResize.count)
                        }

                        guard let finalData = resized.jpegData(maxKB: maxKB) else {
                            NSLog("⚠️ Compress fail Picker[\(idx)] -> fallback copy")
                            let src = DownloadFileTask().saveURL2(url: url, suffix: "ImagePicker-\(url.lastPathComponent)")
                            out.append(src)
                            continue
                        }

                        self.logSize("Picker[\(idx)] after compress (maxKB=\(maxKB))", finalData.count)

                        // lưu file thật
                        let fileName = "\(pref)-\(formatter.string(from: Date()))-\(idx).\(ext)"
                        let fileURL = folder.appendingPathComponent(fileName)

                        do {
                            try finalData.write(to: fileURL, options: .atomic)

                            if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                               let size = attr[.size] as? Int {
                                self.logSize("Picker[\(idx)] saved real", size)
                                NSLog("Saved path: %@", fileURL.path)
                            }

                            out.append("local://\(fileURL.path)")
                        } catch {
                            NSLog("⚠️ Write fail Picker[\(idx)] -> fallback copy: %@", error.localizedDescription)
                            let src = DownloadFileTask().saveURL2(url: url, suffix: "ImagePicker-\(url.lastPathComponent)")
                            out.append(src)
                        }
                    }

                    result.success = true
                    result.data = JSON(out)
                    self.App21Result(result: result)
                })
            })
        }
    }

    
    //MARK: - CHOOSE FILES
    @objc func CHOOSE_FILES(result: Result) -> Void {
        NSLog("📥 CHOOSE_FILES params: %@", result.params ?? "nil")

        guard let params = result.params, let jsonData = params.data(using: .utf8) else {
            result.success = false
            result.error = "params is nil"
            self.App21Result(result: result)
            return
        }

        var isMultiple = false
        var accept: String = "*/*" // ví dụ: "application/pdf", "image/*", "*/*"

        do {
            if let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                NSLog("📦 CHOOSE_FILES params dict: %@", dict)

                isMultiple = (dict["isMultiple"] as? Bool) ?? false
                if let a = dict["accept"] as? String {
                    accept = a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
            }
        } catch {
            result.success = false
            result.error = "Parse JSON ERROR: \(error.localizedDescription)"
            self.App21Result(result: result)
            return
        }

        NSLog("📌 CHOOSE_FILES config -> accept=%@ isMultiple=%@",
              accept, isMultiple.description)

        DispatchQueue.main.async {
            // xin quyền photoLibrary không cần cho document, nhưng giữ luồng giống các hàm khác nếu bạn muốn
            self.caller.presentDocumentPicker(isMultiple: isMultiple, accept: accept) { filePaths in
                NSLog("📄 Picked \(filePaths.count) files")

                var out: [String] = []
                out.reserveCapacity(filePaths.count)

                for url in filePaths {
                    // Copy về local (giống cách cũ), nhưng trả ra local scheme URL cho chắc upload
                    let savedAbsPath = DownloadFileTask().saveURL2(
                        url: url,
                        suffix: "FilePicker-\(url.lastPathComponent)"
                    )

                    // Nếu saveURL2 đã trả sẵn local://... thì append luôn
                    // Nếu nó trả abs path thì convert sang local scheme
                    if savedAbsPath.hasPrefix("local://") {
                        out.append(savedAbsPath)
                    } else {
                        out.append(DownloadFileTask.toLocalSchemeUrl(savedAbsPath))
                    }
                }

                result.success = true
                result.data = JSON(out)
                self.App21Result(result: result)
            }
        }
    }
    
    //MARK: - REBOOT
    @objc func REBOOT(result: Result) -> Void {
        //
        result.success = true;
        App21Result(result: result);
        
        let miliSecond = Int(result.params ?? "0") ?? 0;
        let s = miliSecond/1000;
        DispatchQueue.main.asyncAfter(deadline:.now() + Double(s)) {
            self.caller.reloadStoryboard();
        }
    }
    
    
    //MARK: - CAMERA
    @objc func CAMERA(result: Result) -> Void {
        DispatchQueue.main.async {
            self._PERMISSION(permission: PermissionName.camera, result: result, ok: { (_: String) -> Void in
                NSLog("ok->openCamera")

                // ===== 1) LẤY PARAMS STRING (ưu tiên result.params, fallback từ result.raw.params object) =====
                var paramsStr: String? = result.params

                if (paramsStr == nil || paramsStr == ""), let raw = result.raw,
                   let rawData = raw.data(using: .utf8),
                   let root = (try? JSONSerialization.jsonObject(with: rawData, options: [])) as? [String: Any],
                   let paramsObj = root["params"] {

                    if let pData = try? JSONSerialization.data(withJSONObject: paramsObj, options: []),
                       let pStr = String(data: pData, encoding: .utf8) {
                        paramsStr = pStr
                    }
                }

                NSLog("📥 CAMERA paramsStr: %@", paramsStr ?? "nil")

                // ===== 2) PARSE CONFIG =====
                var shouldCompress = false
                var maxSide: CGFloat = 1600
                var maxKB: Int = 500
                var pref: String = "IMG"
                var ext: String = "png" // default theo JS bạn đang set

                if let p = paramsStr, let data = p.data(using: .utf8) {
                    do {
                        if let dict = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            NSLog("📦 CAMERA params dict: %@", dict)

                            shouldCompress = (dict["isCompressed"] as? Bool) ?? false

                            if let side = dict["maxSide"] as? Double { maxSide = CGFloat(side) }
                            else if let side = dict["maxSide"] as? Int { maxSide = CGFloat(side) }

                            if let kb = dict["maxKB"] as? Int { maxKB = kb }
                            else if let kb = dict["maxKB"] as? Double { maxKB = Int(kb) }

                            if let pPref = dict["pref"] as? String, !pPref.isEmpty { pref = pPref }
                            if let pExt = dict["ext"] as? String, !pExt.isEmpty { ext = pExt.lowercased() }
                        }
                    } catch {
                        NSLog("❌ CAMERA params JSON parse error: %@", error.localizedDescription)
                    }
                }

                // ✅ Nếu nén: ép ext về jpg để tránh PNG phình size
                if shouldCompress { ext = "jpg" }

                NSLog("📌 CAMERA config -> isCompressed=%@ maxSide=%d maxKB=%d pref=%@ ext=%@",
                      shouldCompress.description, Int(maxSide), maxKB, pref, ext)

                // ===== 3) OPEN CAMERA =====
                AttachmentHandler.shared.showCamera(vc: self.caller)

                AttachmentHandler.shared.imagePickedBlock = { image in
                    NSLog("📸 CAMERA imagePickedBlock called")
                    result.success = true

                    // Fix orientation luôn
                    let fixed = image.fixedOrientation()

                    // Log size gốc (để khỏi “mất logSize lúc đầu”)
                    if let original = fixed.jpegData(compressionQuality: 1.0) {
                        self.logSize("Camera original", original.count)
                    } else {
                        NSLog("📦 Camera original: (jpegData nil)")
                    }

                    // ===== 4) KHÔNG NÉN -> dùng cơ chế cũ =====
                    if !shouldCompress {
                        let src = DownloadFileTask().save(
                            image: fixed,
                            opt: self.paramsToDic(params: paramsStr) // giữ opt cũ
                        )
                        result.data = JSON(src)
                        self.App21Result(result: result)
                        return
                    }

                    // ===== 5) NÉN: resize + compress =====
                    let resized = fixed.resized(maxSide: maxSide)

                    if let afterResize = resized.jpegData(compressionQuality: 1.0) {
                        self.logSize("Camera after resize (maxSide=\(Int(maxSide)))", afterResize.count)
                    }

                    guard let finalData = resized.jpegData(maxKB: maxKB) else {
                        NSLog("❌ Compress failed -> fallback save original")
                        let src = DownloadFileTask().save(image: fixed, opt: self.paramsToDic(params: paramsStr))
                        result.data = JSON(src)
                        self.App21Result(result: result)
                        return
                    }

                    self.logSize("Camera after compress (maxKB=\(maxKB))", finalData.count)

                    // ===== 6) GHI THẲNG finalData RA FILE .JPG (KHÔNG ĐI QUA save(image:) để khỏi encode lại PNG) =====
                    let formatter = DateFormatter()
                    formatter.dateFormat = "ddMMyyyyHHmmss"
                    let fileName = "\(pref)-\(formatter.string(from: Date())).\(ext)"

                    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                    let fileURL = docs.appendingPathComponent(fileName)

                    do {
                        try finalData.write(to: fileURL, options: .atomic)

                        // Log size file thật trên disk
                        if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                           let size = attr[.size] as? Int {
                            self.logSize("Saved file size (real)", size)
                            NSLog("Saved path: %@", fileURL.path)
                        }

                        // Trả về đúng format local:///... để PostFileToServer đọc
                        // (Bạn đang log Upload path dạng local:///var/... nên giữ y hệt)
                        let localPath = "local://\(fileURL.path)"
                        result.data = JSON(localPath)
                        self.App21Result(result: result)
                        return

                    } catch {
                        NSLog("❌ Write compressed file error: %@", error.localizedDescription)
                        // fallback
                        let src = DownloadFileTask().save(image: fixed, opt: self.paramsToDic(params: paramsStr))
                        result.data = JSON(src)
                        self.App21Result(result: result)
                        return
                    }
                }
            })
        }
    }

    
    var record21: Record21? = nil
    //MARK: - RECORD_AUDIO
    @objc func RECORD_AUDIO(result: Result) -> Void {
        if(record21 == nil) {
            record21 = Record21()
        }
        record21!.RecordAudio(result: result, app21: self)
    }
    
    //MARK: - RECORD_VIDEO
    @objc func RECORD_VIDEO(result: Result) -> Void {
        //
        DispatchQueue.main.async(execute: {
            // self.caller.openCamera(result: result);
            self._PERMISSION(permission: PermissionName.video,result: result, ok:{(mess: String) -> Void in
                //go
                NSLog("ok->openCamera");
                
                
                AttachmentHandler.shared.captionVideo = true
                AttachmentHandler.shared.showCamera(vc: self.caller);
                
                AttachmentHandler.shared.videoPickedBlock = { (video) in
                    /* get your image here */
                    //Use image name from bundle to create NSData
                    // let image : UIImage = UIImage(named:"imageNameHere")!
                    //Now use image to create into NSData format
                    //let imageData:NSData = image.pngData()! as NSData
                    
                    //let strBase64 = imageData.base64EncodedString(options: .lineLength64Characters)
                    result.success = true
                    

                    
                    let src = DownloadFileTask().saveURL(url: video as URL, suffix: "RECORD_VIDEO.mp4");
                    result.data = JSON(src);
                    self.App21Result(result: result);
                }
                
            })
        })
    }
    
    
    
    
    //MARK: - LOCATION
    @objc func LOCATION(result: Result) -> Void {
        /*
        result.success = true;
        let loc21 = Loction21()
        loc21.app21 = self
        loc21.run(result: result)
        */
        caller.locationCallback = {(loc: CLLocationCoordinate2D?, status: CLAuthorizationStatus? ) in
            result.success = loc != nil
            if(loc != nil)
            {
                let d: [String: Double] = [
                    "lat": loc!.latitude,
                    "lng": loc!.longitude
                ]
                
                result.data = JSON(d)
            }
            self.App21Result(result: result);
        }
        caller.requestLoction()
    }
    
    
    //MARK: - DOWNLOAD
    @objc func DOWNLOAD(result: Result) -> Void
    {
        DownloadFileTask().load(src: result.params!, success: { (absPath: String) -> Void in
//
            result.success = true;

            //result.data = JSON(absPath);
            result.data = JSON(DownloadFileTask.toLocalSchemeUrl(absPath));
            self.App21Result(result: result)
            
        }) { (mess: String)  -> Void in
            //
            result.success = false;
            result.error = mess;
            self.App21Result(result: result)
        }
    }
    
    //MARK: - BASE64
    @objc func BASE64(result: Result) -> Void
    {
        DispatchQueue.global().async {
            do
            {
                let decoder = JSONDecoder()
                
                let rq = try decoder.decode(Base64Require.self, from: result.params!.data(using: .utf8)!)
                
                
                let b64 = DownloadFileTask().toBase64(src: rq.path)
                result.success = b64 != nil
                // Bounce back to the main thread to update the UI
                DispatchQueue.main.async {
                    self.App21Result(result: result)
                    self.caller.evalJs(str: rq.callback! + "('" + b64! + "')")
                }
                
                
            }catch{
                result.success = false
                result.error = error.localizedDescription
                // Bounce back to the main thread to update the UI
                DispatchQueue.main.async {
                     self.App21Result(result: result)
                }
            }
        }
        
       
        
    }
        
    
    
    
    //MARK: - CLEAR_DOWNLOAD
    @objc func CLEAR_DOWNLOAD(result: Result) -> Void
    {
        DownloadFileTask().clear(param: result.params ?? "",callback: {(ok: String,error: String?) -> Void in
            if(error != nil)
            {
                result.success = false;
                result.error = error;
            }else{
                result.success = true;
            }
            
            self.App21Result(result: result);
        })
       
    }
    
    @objc func GET_NETWORK_TYPE(result: Result) -> Void {
        caller.locationCallback = { (loc: CLLocationCoordinate2D?, status: CLAuthorizationStatus?) in
                if let _ = loc {
                    // ✅ Gọi async để lấy WiFi info
                    WiFiManager.getWiFiInfo { wifiInfo in
                        if wifiInfo.isEmpty {
                            result.success = true
                            result.data = "NO WIFI"
                        } else {
                            result.success = true
                            result.data = JSON(wifiInfo)
                            print("📲 [GET_NETWORK_TYPE] WiFi Info: \(wifiInfo)")
                        }
                        self.App21Result(result: result)
                    }
                } else if status == .restricted || status == .denied {
                    result.success = true
                    result.data = "Bạn đã từ chối quyền vị trí. Vui lòng bật trong Cài đặt để sử dụng tính năng này."
                    self.App21Result(result: result)
                }
            }
            caller.requestLoction()
    }
    

    //MARK: - GET_DOWNLOADED
    @objc func GET_DOWNLOADED(result: Result) -> Void
    {
        result.data = JSON(DownloadFileTask().getlist());
        result.success = true;
        App21Result(result: result);
    }
    
    
    //MARK: - DELETE_FILE (result.result = 1 file)
    @objc func DELETE_FILE(result: Result) -> Void
    {
        let mess = DownloadFileTask().deletePath(path: result.params!)
        result.success = mess == "" ?  true : false;
        if(mess != "")
        {
            result.error = mess;
        }
        App21Result(result: result);
        
    }
    
    
    //MARK: - POST_TO_SERVER
    @objc func POST_TO_SERVER(result: Result) -> Void
    {
        let p = PostFileToServer();
        p.app21 = self;
        p.execute(result: result);
    }
    
    //MARK: - IMAGE_ROTATE
    @objc func IMAGE_ROTATE(result: Result) -> Void
    {
        let iu = ImageUtil();
        iu.app21 = self;
        iu.execute(result: result);
    }
    
    func paramsToDic(params: String?) -> [String:String]
    {
        var d = [String:String]();
        if(params != nil)
        {
            for seg in (params?.split(separator: ","))!
            {
                let arr = seg.split(separator: ":")
                d[String(describing: arr[0])] = arr.count > 1 ? String(describing: arr[1]) : "";
            }
        }
        return d;
    }
    
    func reject(result: Result, resson: String)
    {
        NSLog(resson)
        result.success = false;
        result.error = resson
        App21Result(result: result)
    }
    //MARK: - _PERMISSION
    //permission:camera, video, photoLibrary
    func _PERMISSION(permission: PermissionName, result: Result, ok: @escaping (_ mess: String) -> Void) {

        func okMain(_ msg: String) {
            DispatchQueue.main.async { ok(msg) }
        }
        func rejectMain(_ reason: String) {
            DispatchQueue.main.async { self.reject(result: result, resson: reason) }
        }

        switch permission {

        case .photoLibrary:
            let status: PHAuthorizationStatus
            if #available(iOS 14, *) {
                status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            } else {
                status = PHPhotoLibrary.authorizationStatus()
            }

            switch status {
            case .authorized, .limited:
                NSLog("photoLibrary authorized")
                okMain("authorized")

            case .notDetermined:
                if #available(iOS 14, *) {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { st in
                        if st == .authorized || st == .limited {
                            okMain("access_given")
                        } else {
                            rejectMain("permission_denied")
                        }
                    }
                } else {
                    PHPhotoLibrary.requestAuthorization { st in
                        if st == .authorized {
                            okMain("access_given")
                        } else {
                            rejectMain("permission_denied")
                        }
                    }
                }

            case .denied:
                rejectMain("permission_denied")

            case .restricted:
                rejectMain("permission_restricted")

            @unknown default:
                rejectMain("permission_unknown")
            }

        case .camera, .video:
            // camera + record video đều dùng quyền .video
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .authorized:
                NSLog("camera/video authorized")
                okMain("authorized")

            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    granted ? okMain("access_given") : rejectMain("permission_denied")
                }

            case .denied:
                rejectMain("permission_denied")

            case .restricted:
                rejectMain("permission_restricted")

            @unknown default:
                rejectMain("permission_unknown")
            }
        }
    }
    
    //MARK: - SET_BADGE
        @objc func SET_BADGE(result: Result) -> Void
        {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber -= 1
            }
            
        }
    
    //MARK: - REMOVE_BADGE
    @objc func REMOVE_BADGE(result: Result) -> Void
    {
        DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    //MARK: - GET_LOCATION
    @objc func GET_LOCATION(result: Result) -> Void {
        caller.locationCallback = { [weak self] (loc: CLLocationCoordinate2D?, status: CLAuthorizationStatus?) in
            guard let self = self else { return }

            if let location = loc {
                // ✅ Có tọa độ
                let data: [String: Double] = [
                    "latitude": location.latitude,
                    "longitude": location.longitude
                ]

                result.success = true
                result.data = JSON(data)
                print("📍 Vị trí hiện tại: lat=\(location.latitude), lng=\(location.longitude)")
            } else {
                // ❌ Không có tọa độ hoặc bị từ chối quyền
                if status == .denied || status == .restricted {
                    result.success = false
                    result.error = "Vui lòng cấp quyền định vị trong Cài đặt để tiếp tục."
                    result.data = ""
                    print("⚠️ Người dùng đã từ chối quyền định vị.")
                } else {
                    result.success = false
                    result.error = "Không thể lấy vị trí. Vui lòng thử lại."
                    result.data = ""
                    print("⚠️ Không thể lấy tọa độ (chưa xác định).")
                }
            }

            self.App21Result(result: result)
        }

        // 🚀 Bắt đầu yêu cầu Location
        caller.requestLoction()
    }

    //MARK: - OPEN_QRCODE
    @objc func OPEN_QRCODE(result: Result) -> Void
    {
        self.caller.qrCodeResult = result
        DispatchQueue.main.async {
            self.caller.show(self.caller.storyboard!.instantiateViewController(withIdentifier: "QrCodeController"), sender: self)
            
        }
    }
    
    
    enum PermissionName: String{
        case camera, video, photoLibrary
    }
    
    
    //MARK: - NOTI
    @objc func NOTI(result: Result) -> Void
    {
        do{
            let decoder = JSONDecoder()
            let noti21 = try decoder.decode(Noti21.self, from: result.params!.data(using: .utf8)!)
            let svn = SERVER_NOTI();
            svn.app21 = self;
            svn.noti(noti21: noti21)
            result.success = true
        }
        catch{
            result.success = false
            result.error = error.localizedDescription
            
        }
        self.App21Result(result: result)
        
    }
    
    
    //MARK: - NOTI_DATA
    @objc func NOTI_DATA(result: Result) -> Void
    {
        do{
            if(result.params != nil){
                let decoder = JSONDecoder()
                let params = try decoder.decode(NOTI_DATA_PARAMS.self, from: result.params!.data(using: .utf8)!)
                if(params.reset == true)
                {
                    UserDefaults.standard.removeObject(forKey: "NotifedData");
                    result.data = JSON("reseted")
                }
                result.success = true
            }
            else{
                let data =  UserDefaults.standard.dictionary(forKey: "NotifedData");
                var d = [String:String]()
                if(data != nil){
                    for (k,v) in data!{
                        
                        let a = k
                        if let b = v as? String {
                            d[a] = b
                        }
                        else {
                            // nothing to do
                        }
                    }
                }
                result.data = JSON(d);
                result.success = true
            }
            
        }
        catch{
            result.error = error.localizedDescription;
            result.success = false
        }
        App21Result(result: result)
        
    }
    
    
    
    
    //MARK: - GET_SERVER_NOTI
    @objc func GET_SERVER_NOTI(result: Result) -> Void{
        SERVER_NOTI().run(result: result, callback: { (_ error: Error?) in
            result.success = error == nil
            if(error != nil)
            {
                result.error = error?.localizedDescription
            }
            self.App21Result(result: result)
        })
    }
    
    
    //MARK: - VIBRATOR
    @objc func VIBRATOR(result: Result) -> Void{
        AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
        result.success = true;
        App21Result(result: result)
    }
    
    
    //MARK: - SEND_SMS
    @objc func SEND_SMS(result: Result) -> Void{
        
        result.success = false;
        result.error = "NO_SUPPORT";
        App21Result(result: result)
    }
    
    
    //MARK: - GET_PHONE
    @objc func GET_PHONE(result: Result) -> Void{
        result.success = false;
        result.error = "NO_SUPPORT";
        App21Result(result: result)
    }
    
    
    //MARK: - ALARM_NOTI
    @objc func ALARM_NOTI(result: Result) -> Void{
        
        // Fetch data once an hour.
        // UIApplication.shared.setMinimumBackgroundFetchInterval(3600)
        
        let parser = JSON.parse(SERVER_NOTI_Config.self, from: result.params!);
        
        if(parser.0 != nil)
        {
            UserDefaults.standard.set(result.params, forKey: SERVER_NOTI.BackgroundFetchConfig)
        }
        result.success = parser.1 == nil;
        result.error = parser.1;
        App21Result(result: result)
    }
    
    
    //MARK: - BROWSER
    @objc func BROWSER(result: Result) -> Void{
        
        if(result.params != "" && result.params != nil)
        {
            caller.open_link(url: result.params!)
        }
        
        App21Result(result: result)
    }
    
    //MARK: - MOTION_SHAKE
    @objc func MOTION_SHAKE(result: Result) -> Void{
        
        DispatchQueue.main.async(execute: {
            self.caller.isMotionShake = true
            self.caller.becomeFirstResponder() // To get shake gesture
            self.caller.motionShakeCallback = {(_ motion: UIEvent.EventSubtype, event: UIEvent?)  in
                self.caller.isMotionShake = false
                result.data = JSON(motion.rawValue)
                self.App21Result(result: result)
            }
        })
        
        
    }
    
    //MARK: - SHARE SOCIAL
    @objc func SHARE_SOCIAL(result: Result) -> Void {
        //
        result.success = false;
        if let jsonData = result.params?.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: jsonData, options: [])
                if let jsonObject = json as? [String: Any] {
                    
                    let images = jsonObject["Images"] as? [String]
                    let text = jsonObject["Content"] as? String
                    
                    DispatchQueue.main.asyncAfter(deadline:.now()) {
                        self.caller.shareImages(images: images ?? [], text: text ?? "", completeShare: {
                            result.success = true
                            result.params = ""
                            result.data = "Share thành công"
                            self.App21Result(result: result);
                        })
                    }
                    
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }
        
    }
    
    // MARK: - CLEAR_FCM_TOKEN
    @objc func CLEAR_FCM_TOKEN(result: Result) -> Void {
        Messaging.messaging().deleteToken { error in
            
            if let error = error {
                result.success = false
                result.error = "Không thể xoá FCM token: \(error.localizedDescription)"
            } else {
                // Nếu bạn có lưu token trong UserDefaults thì xoá luôn
                UserDefaults.standard.removeObject(forKey: "FirebaseNotiToken")
                UserDefaults.standard.synchronize()
                
                result.success = true
                result.data = "Đã xoá FCM token thành công"
            }
            
            self.App21Result(result: result)
        }
    }
    
    
    //MARK: - WV_VISIBLE
    @objc func WV_VISIBLE(result: Result) -> Void
    {
        DispatchQueue.main.async(execute: {
            result.success = true;
            self.caller.wv.isHidden = result.params == "0";
            self.App21Result(result: result)
        })
    }
    
    
    //MARK: - GET_TEXT
    @objc func GET_TEXT(result: Result) -> Void
    {
        result.success = true
        let d = DownloadFileTask();
        
        let text = d.GET_TEXT(path: result.params!);
        result.data = JSON(text);
        
        App21Result(result: result);
       
    }
    
    @objc func CHECK_ICLOUD_STATUS(result: Result) -> Void {
        let fileManager = FileManager.default
        let cloudStore = NSUbiquitousKeyValueStore.default

        // --- 1️⃣ Kiểm tra có đăng nhập iCloud không ---
        guard fileManager.ubiquityIdentityToken != nil else {
            result.success = false
            result.data = "❌ iCloud Drive chưa bật hoặc chưa cấp quyền cho ứng dụng này. Vào Settings → [Tên bạn] → iCloud → iCloud Drive và bật quyền cho app."
            self.App21Result(result: result)
            return
        }

        // --- 2️⃣ Kiểm tra quyền iCloud Drive / đồng bộ app ---
        // Dù không dùng file container, ta vẫn có thể test qua synchronize()
        let syncOK = cloudStore.synchronize()
        if !syncOK {
            result.success = false
            result.data = "⚠️ iCloud Drive chưa bật hoặc chưa cấp quyền cho ứng dụng này. Vào Settings → [Tên bạn] → iCloud → iCloud Drive và bật quyền cho app."
            self.App21Result(result: result)
            return
        }

        // --- 3️⃣ Kiểm tra dữ liệu iCloud khả dụng ---
        let dict = cloudStore.dictionaryRepresentation
        print("☁️ iCloud Key-Value Store keys:", dict.keys)

        result.success = true
        result.data = "✅ iCloud và iCloud Drive hoạt động bình thường.\nĐăng nhập & quyền truy cập OK."
        self.App21Result(result: result)
    }
    
    @objc func GET_INFO(result: Result) {
        let Devices = DeviceIdManager.shared.getStableDeviceId()
        
        print("DeviceId: \(Devices.deviceId)")
        print("Source: \(Devices.source)")
        print("Saved in: \(Devices.savedIn.joined(separator: ", "))")
        print("Detail log:\n\(Devices.detailLog.joined(separator: "\n"))")

        var info = "IOS,deviceId:\(Devices.deviceId)"
        info += ",systemName:\(UIDevice.current.systemName)"
        info += ",systemVersion:\(UIDevice.current.systemVersion)"
        info += ",localizedModel:\(UIDevice.current.localizedModel)"
        info += ",model:\(UIDevice.current.model)"
        info += ",name:\(UIDevice.current.name)"
        info += ",savedIn:\(Devices.savedIn.joined(separator: " | "))"
        info += ",detailLog:\(Devices.detailLog.joined(separator: " | "))"

        result.data = JSON(info)
        result.success = true
        App21Result(result: result)
    }

    
//    @objc func GET_INFO(result: Result) {
//        let keychain = KeychainSwift()
//        keychain.synchronizable = true   // đồng bộ giữa các thiết bị iCloud Keychain
//        let cloudStore = NSUbiquitousKeyValueStore.default
//        let key = "vn.idezs.deviceid"
//        
//        var deviceId: String?
//        var savedToCloud = false
//        
//        func finalize() {
//            var info = "IOS,deviceId:\(deviceId ?? "unknown")"
//            info += ",systemName:\(UIDevice.current.systemName)"
//            info += ",systemVersion:\(UIDevice.current.systemVersion)"
//            info += ",localizedModel:\(UIDevice.current.localizedModel)"
//            info += ",model:\(UIDevice.current.model)"
//            info += ",name:\(UIDevice.current.name)"
//            if savedToCloud { info += ",asyncCloud:1" }
//            
//            result.data = JSON(info)
//            result.success = true
//            App21Result(result: result)
//        }
//        
//        // --- 1️⃣ Ưu tiên Keychain ---
//        if let kcId = keychain.get(key), !kcId.isEmpty {
//            deviceId = kcId
//            print("✅ Lấy deviceId từ Keychain: \(kcId)")
//            finalize()
//            return
//        }
//        
//        // --- 2️⃣ Kiểm tra iCloud KVStore nếu Keychain trống ---
//        if FileManager.default.ubiquityIdentityToken != nil,
//           FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil { // iCloud Drive bật
//            cloudStore.synchronize()
//            
//            if let cloudId = cloudStore.string(forKey: key), !cloudId.isEmpty {
//                deviceId = cloudId
//                keychain.set(cloudId, forKey: key)
//                savedToCloud = true
//                print("☁️ Lấy deviceId từ iCloud KVStore: \(cloudId)")
//                finalize()
//                return
//            }
//            
//            // --- Nếu iCloud chưa có → tạo mới sau khi đồng bộ tối đa 2 giây ---
//            DispatchQueue.global().async {
//                let startTime = Date()
//                while Date().timeIntervalSince(startTime) < 2.0 {
//                    cloudStore.synchronize()
//                    if let cloudId = cloudStore.string(forKey: key), !cloudId.isEmpty {
//                        deviceId = cloudId
//                        keychain.set(cloudId, forKey: key)
//                        savedToCloud = true
//                        print("☁️ Lấy deviceId từ iCloud sau sync: \(cloudId)")
//                        break
//                    }
//                    Thread.sleep(forTimeInterval: 0.2)
//                }
//                
//                DispatchQueue.main.async {
//                    if deviceId == nil {
//                        let newId = UUID().uuidString
//                        deviceId = newId
//                        keychain.set(newId, forKey: key)
//                        cloudStore.set(newId, forKey: key)
//                        cloudStore.synchronize()
//                        savedToCloud = true
//                        print("🆕 Tạo deviceId mới và đồng bộ iCloud: \(newId)")
//                    }
//                    finalize()
//                }
//            }
//            return
//        }
//        
//        // --- 3️⃣ Không có Keychain và iCloud tắt → tạo mới ---
//        let newId = UUID().uuidString
//        deviceId = newId
//        keychain.set(newId, forKey: key)
//        print("🆕 Tạo deviceId mới (iCloud tắt): \(newId)")
//        finalize()
//    }

    
    static func OS_INFO() -> String {
        var   info = "IOS";
        info += ",systemName:" + UIDevice.current.systemName
        info += ",systemVersion:" + UIDevice.current.systemVersion
        info += ",localizedModel:" + UIDevice.current.localizedModel
        info += ",model:" + UIDevice.current.model
        return info
    }
    
    //MARK: - TEL
    @objc func TEL(result: Result) -> Void
    {
        result.success = true
        let number = result.params
        let _url = "tel://" + number!
        if let url = URL(string: _url) {
            DispatchQueue.main.async(execute: {
                UIApplication.shared.open(url)
            })
            
        }
        App21Result(result: result);
    }
    //MARK: - SHARE_OPEN
    @objc func SHARE_OPEN(result: Result) -> Void
    {
        result.success = true
        
        let _url = result.params!
        if let url = URL(string: _url) {
            DispatchQueue.main.async(execute: {
                UIApplication.shared.open(url)
            })
            
        }
        App21Result(result: result);
        
    }
    
    //19/03/2022 hung
    //MARK: - KEY
    @objc func KEY(result: Result) -> Void
    {
        let data = (result.params?.data(using: .utf8))

        if data != nil {
            if let json = try? JSON(data: data!){
                let key = json["key"].stringValue
                if json["value"].exists(){
                    let value = json["value"].stringValue
                    let defaults = UserDefaults.standard
                    defaults.set(value, forKey: key)
                }else{
                    let defaults = UserDefaults.standard
                    let v = defaults.string(forKey: key)
                    if v != nil {
                        result.data = JSON(v!)
                    }

                    result.success = true
                }
            }
        }



        //let jo = try? JSONSerialization.jsonObject(with: data, options: [])

        App21Result(result: result);

    }
    
    //21/10/2024
    //MARK: XPRINT
    var xpz: XPZ? = nil;
    @objc func downForPrint(url: String?) -> URL?
    {
        if(goc == nil)
        {
            goc = GetORCached();
        }

        return goc?.downUrl(urlStr: url)!.absPath ;
    }

    @objc func XPRINT_Connected(host: String?, port: Int)
    {
        if(xpz == nil)
        {
            xpz = XPZ();
            xpz?.app21 = self;
        }
        xpz?.onConected(ip: host!, port: port)

    }
    @objc func XPrint_Error(err: String) -> Void
    {
        if(xpz == nil)
        {
            xpz = XPZ();
            xpz?.app21 = self;
        }
        xpz?.onError(err: err)
    }

    @objc func XPRINT_CLEAR(result: Result) -> Void
    {
        if(xpz == nil)
        {
            xpz = XPZ();
            xpz?.app21 = self;
        }
        xpz?.clear();
        result.success = true;
        App21Result(result: result);
    }

    @objc func XPRINT(result: Result) -> Void
    {
        if(xpz == nil)
        {
            xpz = XPZ();
            xpz?.app21 = self;
        }
        result.error = "KHONG_XU_LY";
        do
        {

            var data = (result.params?.data(using: .utf8));

            if(data == nil)
            {
                if(result.params == nil)
                {
                    let dataRaw = result.raw?.data(using: .utf8);
                    if let jsonRaw = try? JSON(data: dataRaw!){
                        data  = try jsonRaw["params"].rawData();
                        //data = (rawParams.data(using: .utf8));

                    }
                }
            }

            if data != nil {
                if let json = try? JSON(data: data!){
                    var ipAddress: String? = nil;
                    var pr: XPZParam? = nil;
                    var port: Int? = nil;

                    if(json["ipAddress"].exists())
                    {
                        ipAddress = json["ipAddress"].stringValue;
                    }
                    if(json["port"].exists())
                    {
                        port = json["port"].intValue;
                    }

                    if(port == nil || port == 0)
                    {
                        port = 9100;
                    }

                    let decoder = JSONDecoder()
                    if(json["param"].exists())
                    {
                        let prStr = json["param"].rawString();
                        let d1 = prStr!.data(using: .utf8)!;
                        pr = try decoder.decode(XPZParam.self, from: d1)
                    }




                    if(ipAddress == nil)
                    {
                       throw Error21.runtimeError("ipAddress is null")
                    }
                    if(pr == nil)
                    {
                       throw Error21.runtimeError("param is null")
                    }

                    var items = pr!.items;
                    for item in items!
                    {
                        if( item.self.imageUrl != nil)
                        {
                            item.self.imageLocalPath = downForPrint(url: item.self.imageUrl);
                        }
                    }


                    xpz?.result = result;
                    xpz?.printParam(ipAddress: ipAddress!, port: port!, param: pr!);
                    result.error = nil;
                    return;
                }
            }
        }catch
        {
            result.error = error.localizedDescription;
            result.success = false;
        }

        App21Result(result: result);
    }

    //MARK: STORE_TEXT
    @objc func STORE_TEXT(result: Result) -> Void
    {
        do
        {
            let data = (result.params?.data(using: .utf8));
            if data != nil {
                if let json = try? JSON(data: data!){
                    var name: String? = nil;

                    let fileManager = FileManager.default


                    if(json["name"].exists())
                    {
                        name = json["name"].stringValue;
                    }

                    if(name == nil)
                    {
                        throw Error21.runtimeError("name is null");
                    }

                    let fileName = "STORE_TEXT_" + name!;

                    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first{

                        let fileUrl = dir.appendingPathComponent(fileName);
                        if(json["value"].exists())
                        {
                            var value = json["value"].stringValue;
                            try value.write(to: fileUrl, atomically: false, encoding:.utf8)
                        }
                        else{
                            let text = try String(contentsOf: fileUrl, encoding: .utf8)
                            result.data = JSON(text);
                        }

                    }


                    result.success = true;
                    App21Result(result: result);
                }
            }
        }catch
        {
            result.error = error.localizedDescription;
            result.success = false;
            App21Result(result: result);
        }
    }

    //MARK: GET_OR_CACHED
    var goc: GetORCached? = nil;
    @objc func GET_OR_CACHED(result: Result) -> Void
    {


        do
        {
            let data = (result.params?.data(using: .utf8))
            if data != nil {
                if let json = try? JSON(data: data!){
                    let url: String? = json["url"].stringValue;
                    var type = 0;
                    var returnType = 0;

                    if(json["type"].exists())
                    {
                        type = json["type"].intValue;
                    }
                    if(json["returnType"].exists())
                    {
                        returnType = json["returnType"].intValue;
                    }

                    if(url == nil || url!.isEmpty) {
                        throw Error21.runtimeError("url is null");

                    }

                    if( goc == nil)
                    {
                        goc = GetORCached();
                    }
                    goc?.handle(url: url!, type: type, returnType: returnType, result: result, app21: self)
                }
            }

        }
        catch
        {
            result.error = error.localizedDescription;
            result.success = false;
            App21Result(result: result);
        }




        //let jo = try? JSONSerialization.jsonObject(with: data, options: [])

        App21Result(result: result);

    }
    
    //MARK: START_SCRIPT
    @objc func START_SCRIPT(result: Result) -> String?
    {
        let name = "START_SCRIPT.js";
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        {
            var path = dir.appendingPathComponent(name);
            var _: String? = nil;
            var text: String? = nil;
            do
            {
                if(result.params ==  nil || result.params == "")
                {
                    text = try String(contentsOf: path, encoding: .utf8);
                    result.data = JSON(text!);
                }else{
                    try result.params!.write(to: path, atomically: true, encoding: .utf8);
                    result.data = JSON("saved")
                }
            }catch{
                result.success = false;
                App21Result(result: result);
                return nil;
            }
            
            result.success = true;
            App21Result(result: result);
            return text;
            
        }else{
            result.success = false;
            App21Result(result: result);
        }
        return nil;
    }
    //het 21/10/2024
    
}



//MARK: - class:Result
class Result : NSObject {
    var success = true
    var data: JSON? = nil
    var error: String? = ""
    
    var sub_cmd: String? = ""
    var sub_cmd_id: Int = 0
    var params: String? = ""
    //2024/12/18
    var raw:String? = nil
    
    enum CodingKeys:String, CodingKey {
        case success
        case data
        case error
        case sub_cmd
        case sub_cmd_id
        case params
    }
}
extension Result: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        try container.encode(error, forKey: .error)
        if(data != nil)
        {
           
           try container.encode(data, forKey: .data)
           
        }
        try container.encode(sub_cmd, forKey: .sub_cmd)
        try container.encode(params, forKey: .params)
        try container.encode(sub_cmd_id, forKey: .sub_cmd_id)
    }
}


extension String {
//: ### Base64 encoding a string
    func base64Encoded() -> String? {
    
        if let data = self.data(using: .utf8) {
            return data.base64EncodedString()
        }
        return nil
    }

//: ### Base64 decoding a string
    func base64Decoded() -> String? {
        if let data = Data(base64Encoded: self) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
enum Error21 : Error {
   case runtimeError(String)
}

class Base64Require : Codable{
    var path: String?;
    var callback: String?;
}

class NOTI_DATA_PARAMS : Codable
{
    var reset: Bool? = false
}


struct DeviceIdStatus {
    let deviceId: String
    let source: String
    let savedIn: [String]
    let detailLog: [String]
}

class DeviceIdManager {

    static let shared = DeviceIdManager()
    private init() {}

    private let keychainKey = "vn.idezs"
    private let iCloudKey = "deviceId"
    private let documentFileName = "deviceid.txt"
    private let appGroupSuite = "group.vn.ids.shared"
    
    private let queue = DispatchQueue(label: "com.deviceid.manager.serial")

    // MARK: Main function
    func getStableDeviceId() -> DeviceIdStatus {
        return queue.sync {
            var logs: [String] = []
            logs.append("🔍 Start getStableDeviceId()")

            // 1️⃣ Load from all storages
            var savedIn: [String] = []
            let keychainId = normalize(getFromKeychain())
            let iCloudId = normalize(getFromICloud())
            let documentId = normalize(getFromDocuments())
            let sharedId = normalize(getFromShared())

            if keychainId != nil { savedIn.append("Keychain") }
            if iCloudId != nil { savedIn.append("iCloud") }
            if documentId != nil { savedIn.append("Documents") }
            if sharedId != nil { savedIn.append("Shared") }

            logs.append("➡️ Keychain: \(keychainId ?? "nil")")
            logs.append("➡️ iCloud: \(iCloudId ?? "nil")")
            logs.append("➡️ Documents: \(documentId ?? "nil")")
            logs.append("➡️ Shared: \(sharedId ?? "nil")")

            // 2️⃣ Conflict check
            let ids = [keychainId, iCloudId, documentId, sharedId].compactMap { $0 }
            let uniqueIds = Array(Set(ids))
            if uniqueIds.count > 1 {
                logs.append("⚠️ Conflict detected! Different IDs found: \(uniqueIds)")
            }

            // 3️⃣ Select priority source: Keychain > iCloud > Documents > Shared
            let sourceId = keychainId ?? iCloudId ?? documentId ?? sharedId
            var deviceId: String
            var source: String
            if let id = sourceId {
                deviceId = id
                if keychainId != nil { source = "Keychain" }
                else if iCloudId != nil { source = "iCloud" }
                else if documentId != nil { source = "Documents" }
                else { source = "Shared" }
                logs.append("✅ Using existing UUID from \(source)")
            } else {
                deviceId = UUID().uuidString
                source = "new"
                logs.append("🆕 Generated new UUID")
            }

            // 4️⃣ Migrate to missing storage
            if keychainId != deviceId { saveToKeychain(deviceId, logs: &logs) }
            if iCloudId != deviceId { saveToICloud(deviceId, logs: &logs) }
            if documentId != deviceId { saveToDocuments(deviceId, logs: &logs) }
            if sharedId != deviceId { saveToShared(deviceId, logs: &logs) }

            // 5️⃣ Update savedIn after migration
            var currentSaved: [String] = []
            if getFromKeychain() != nil { currentSaved.append("Keychain") }
            if getFromICloud() != nil { currentSaved.append("iCloud") }
            if getFromDocuments() != nil { currentSaved.append("Documents") }
            if getFromShared() != nil { currentSaved.append("Shared") }

            logs.append("🏁 End getStableDeviceId()")
            
            return DeviceIdStatus(
                deviceId: deviceId,
                source: source,
                savedIn: currentSaved,
                detailLog: logs
            )
        }
    }

    // MARK: Normalize UUID
    private func normalize(_ str: String?) -> String? {
        guard let s = str?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return UUID(uuidString: s)?.uuidString
    }
}

// MARK: - iCloud
extension DeviceIdManager {
    private func saveToICloud(_ id: String, logs: inout [String]) {
        let store = NSUbiquitousKeyValueStore.default
        store.set(id, forKey: iCloudKey)
        if store.synchronize() {
            logs.append("☁️ Saved to iCloud")
        } else {
            logs.append("❌ Failed saving to iCloud")
        }
    }
    private func getFromICloud() -> String? {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        return store.string(forKey: iCloudKey)
    }
}

// MARK: - Keychain
extension DeviceIdManager {
    private func getFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let id = String(data: data, encoding: .utf8) { return id }
        return nil
    }
    private func saveToKeychain(_ id: String, logs: inout [String]) {
        let data = id.data(using: .utf8)!
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess { logs.append("🔐 Saved to Keychain") }
        else { logs.append("❌ Failed saving to Keychain: \(status)") }
    }
}

// MARK: - Documents
extension DeviceIdManager {
    private var documentsURL: URL? {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(documentFileName)
    }
    private func getFromDocuments() -> String? {
        guard let url = documentsURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }
    private func saveToDocuments(_ id: String, logs: inout [String]) {
        guard let url = documentsURL else { return }
        do {
            try id.write(to: url, atomically: true, encoding: .utf8)
            logs.append("💾 Saved to Documents")
        } catch {
            logs.append("❌ Failed saving to Documents: \(error)")
        }
    }
}

// MARK: - Shared UserDefaults (App Group)
extension DeviceIdManager {
    private func getFromShared() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else { return nil }
        return defaults.string(forKey: keychainKey)
    }
    private func saveToShared(_ id: String, logs: inout [String]) {
        guard let defaults = UserDefaults(suiteName: appGroupSuite) else { return }
        defaults.set(id, forKey: keychainKey)
        defaults.synchronize()
        logs.append("🗂 Saved to Shared UserDefaults")
    }
}






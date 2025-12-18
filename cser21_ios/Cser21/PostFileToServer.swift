//import Foundation
//import Alamofire
//
//class PostFileToServer {
//    var app21: App21? = nil
//    
//    func execute(result: Result) -> Void {
//        do {
//            let decoder = JSONDecoder()
//            let pinfo = try decoder.decode(PostInfo.self, from: result.params!.data(using: .utf8)!)
//            
//            let url = pinfo.server ?? "" /* your API url */
//            
//            let headers: HTTPHeaders = [
//                /* "Authorization": "your_access_token",  in case you need authorization header */
//                "Content-type": "multipart/form-data"
//                //"Bearer": pinfo.token ?? ""
//            ]
//            
//            let down = DownloadFileTask()
//            let fn = down.getName(path: pinfo.path!)
//            let data = down.localToData(filePath: pinfo.path!)
//            
//            AF.upload(multipartFormData: { multipartFormData in
//                multipartFormData.append(data,
//                    withName: String(pinfo.path!.split(separator: ".").last ?? "file"),
//                    fileName: fn,
//                    mimeType: "file/*")
//            }, to: url, headers: headers)
//            .uploadProgress { progress in
//                print("Upload Progress: \(progress.fractionCompleted)")
//            }
//            .responseString { response in
//                switch response.result {
//                case .success(let value):
//                    print("SUCCESS")
//                    result.success = true
//                    result.data = JSON(value)
//                    self.app21?.App21Result(result: result)
//                    
//                case .failure(let error):
//                    print("Error in upload: \(error.localizedDescription)")
//                    result.success = false
//                    result.error = error.localizedDescription
//                    self.app21?.App21Result(result: result)
//                }
//            }
//            
//        } catch {
//            print("Error decoding PostInfo: \(error)")
//            result.success = false
//            result.error = error.localizedDescription
//            self.app21?.App21Result(result: result)
//        }
//    }
//}
//
//class PostInfo: Codable {
//    var server: String?
//    var path: String?
//    var token: String?
//}

import Foundation
import Alamofire
import MobileCoreServices

class PostFileToServer {
    var app21: App21? = nil

    func execute(result: Result) -> Void {
        do {
            let decoder = JSONDecoder()
            let pinfo = try decoder.decode(PostInfo.self, from: result.params!.data(using: .utf8)!)

            let url = pinfo.server ?? ""
            guard !url.isEmpty else {
                result.success = false
                result.error = "server is empty"
                self.app21?.App21Result(result: result)
                return
            }

            let rawPath = (pinfo.path ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawPath.isEmpty else {
                result.success = false
                result.error = "path is empty"
                self.app21?.App21Result(result: result)
                return
            }

            // ✅ parse mọi kiểu path
            let fileURL = toFileURL(rawPath)

            let fileName = fileURL.lastPathComponent
            let mime = mimeType(for: fileURL.path)

            print("📥 Raw path:", rawPath)
            print("📤 Upload abs path:", fileURL.path)
            print("📄 File name:", fileName)
            print("📎 MIME:", mime)

            // log size on disk
            if let attr = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attr[.size] as? Int {
                print("📦 File real bytes:", size, "(~\(String(format: "%.2f", Double(size)/1024)) KB)")
            } else {
                print("⚠️ Cannot read file attributes at:", fileURL.path)
            }

            // read bytes
            let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
            print("📦 Upload bytes:", data.count, "(~\(String(format: "%.2f", Double(data.count)/1024)) KB)")

            let headers: HTTPHeaders = [
                "Content-type": "multipart/form-data"
            ]

            AF.upload(multipartFormData: { form in
                form.append(
                    data,
                    withName: "file",      // ✅ key backend expect
                    fileName: fileName,    // ✅ tên file thật
                    mimeType: mime
                )
            }, to: url, headers: headers)
            .uploadProgress { progress in
                print("Upload Progress:", progress.fractionCompleted)
            }
            .responseString { response in
                switch response.result {
                case .success(let value):
                    print("SUCCESS")
                    result.success = true
                    result.data = JSON(value)
                    self.app21?.App21Result(result: result)

                case .failure(let error):
                    print("Error in upload:", error.localizedDescription)
                    result.success = false
                    result.error = error.localizedDescription
                    self.app21?.App21Result(result: result)
                }
            }

        } catch {
            print("Error decoding PostInfo:", error)
            result.success = false
            result.error = error.localizedDescription
            self.app21?.App21Result(result: result)
        }
    }

    // ✅ Convert input string (local://, file:/, file:///, plain path) -> file URL
    private func toFileURL(_ input: String) -> URL {
        let s = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1) local:// -> file://
        if s.hasPrefix("local:///") {
            let fixed = "file:///" + String(s.dropFirst("local:///".count))
            if let u = URL(string: fixed) { return u }
        }
        if s.hasPrefix("local://") {
            let fixed = "file://" + String(s.dropFirst("local://".count))
            if let u = URL(string: fixed) { return u }
        }

        // 2) file:///... -> URL(string:)
        if s.hasPrefix("file:///") {
            if let u = URL(string: s) { return u }
        }

        // 3) file:/var/... (thiếu //) -> sửa thành file:///var/...
        if s.hasPrefix("file:/") && !s.hasPrefix("file:///") {
            let pathPart = s.replacingOccurrences(of: "file:", with: "")
            let fixedPath = normalizePlainPath(pathPart)
            return URL(fileURLWithPath: fixedPath)
        }

        // 4) plain absolute path /var/...
        return URL(fileURLWithPath: normalizePlainPath(s))
    }

    // ✅ đảm bảo path bắt đầu bằng "/" và bỏ rác
    private func normalizePlainPath(_ input: String) -> String {
        var p = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // nếu ai đó gửi "file:" lẫn trong path
        if p.hasPrefix("file:") { p = p.replacingOccurrences(of: "file:", with: "") }

        // tránh trường hợp "///var/..." hoặc "//var/..."
        while p.hasPrefix("//") { p = String(p.dropFirst()) }

        if !p.hasPrefix("/") { p = "/" + p }
        return p
    }

    private func mimeType(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        default: return "image/*"
        }
    }
}

class PostInfo: Codable {
    var server: String?
    var path: String?
    var token: String?
}


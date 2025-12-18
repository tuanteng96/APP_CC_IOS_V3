//
//  WiffiManager.swift
//  ezsspa
//
//  Created by HUNG on 15/01/2024.
//  Copyright © 2024 High Sierra. All rights reserved.
//

import Foundation
import SystemConfiguration.CaptiveNetwork
import NetworkExtension

class WiFiManager {
    /// Lấy thông tin WiFi (SSID, BSSID) — hỗ trợ iOS 12–18+
    static func getWiFiInfo(completion: @escaping ([String: Any]) -> Void) {
        var wifiInfo = [String: Any]()
        print("📡 [WiFi Debug] Bắt đầu kiểm tra Wi-Fi...")

        // MARK: - Cách 1: Dùng CNCopyCurrentNetworkInfo
        if let interfaces = CNCopySupportedInterfaces() as? [String], !interfaces.isEmpty {
            print("✅ [WiFi Debug] Các interface Wi-Fi tìm thấy: \(interfaces)")
            
            for interface in interfaces {
                print("🔎 [WiFi Debug] Đang đọc thông tin từ interface: \(interface)")
                if let info = CNCopyCurrentNetworkInfo(interface as CFString) as NSDictionary? {
                    let ssid = info[kCNNetworkInfoKeySSID as String] as? String ?? ""
                    let bssid = info[kCNNetworkInfoKeyBSSID as String] as? String ?? ""
                    
                    if !ssid.isEmpty {
                        wifiInfo["SSID"] = ssid
                        wifiInfo["BSSID"] = bssid
                        print("📶 [WiFi Debug] CNCopyCurrentNetworkInfo thành công → SSID: \(ssid), BSSID: \(bssid)")
                        completion(wifiInfo)
                        return
                    }
                } else {
                    print("⚠️ [WiFi Debug] CNCopyCurrentNetworkInfo trả về nil cho interface \(interface)")
                }
            }
        } else {
            print("⚠️ [WiFi Debug] Không tìm thấy interface Wi-Fi nào.")
        }

        // MARK: - Cách 2: Thử NEHotspotNetwork (iOS 14+)
        if #available(iOS 14.0, *) {
            print("🔄 [WiFi Debug] Đang thử NEHotspotNetwork.fetchCurrent() ...")
            NEHotspotNetwork.fetchCurrent { network in
                if let network = network {
                    wifiInfo["SSID"] = network.ssid
                    wifiInfo["BSSID"] = network.bssid
                    print("📡 [WiFi Debug] NEHotspotNetwork.fetchCurrent thành công → SSID: \(network.ssid), BSSID: \(network.bssid)")
                } else {
                    print("""
                    ❌ [WiFi Debug] NEHotspotNetwork.fetchCurrent trả về nil.
                    👉 Có thể do:
                       1️⃣ Chưa kết nối Wi-Fi thật.
                       2️⃣ “Địa chỉ bảo mật” đang bật.
                       3️⃣ Chưa cấp quyền Vị trí hoặc “Vị trí chính xác” bị tắt.
                       4️⃣ Thiếu entitlement: com.apple.developer.networking.wifi-info = true
                       5️⃣ App chưa được sign đúng provisioning.
                       6️⃣ Đang chạy trên Simulator (không hỗ trợ Wi-Fi).
                    """)
                }
                completion(wifiInfo)
            }
        } else {
            print("⚠️ [WiFi Debug] NEHotspotNetwork.fetchCurrent không khả dụng trên iOS < 14.")
            completion(wifiInfo)
        }
    }
}


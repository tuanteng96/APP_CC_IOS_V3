//
//  Record21.swift
//  Cser21
//
//  Created by Hung-Catalina on 4/22/20.
//  Copyright © 2020 High Sierra. All rights reserved.
//

import Foundation
import AVFoundation


class Record21 : NSObject  {
    
    
    static let shared = Record21()
    
    var recordingSession: AVAudioSession?
    var recorder: AVAudioRecorder?
    var meterTimer: Timer?
    var recorderApc0: Float = 0
    var recorderPeak0: Float = 0
    //PLayer
    var player: AVAudioPlayer?
    
   
   
    var result: Result? = nil
    var app21: App21? = nil
    var audioFilename:URL? = nil
    
    
   
    
    func _PERMISSION(callback: @escaping () -> ())  {
        recordingSession = AVAudioSession.sharedInstance()

        do {
            try recordingSession!.setCategory(.playAndRecord, mode: .default)
            try recordingSession!.setActive(true)
            recordingSession!.requestRecordPermission() { [unowned self] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        callback()
                    } else {
                        self._error(Error21.runtimeError("permission_denied"))
                    }
                }
            }
        } catch {
            self._error(Error21.runtimeError("permission_error"))
        }
    }
    
    func startRecording()
    {
        audioFilename = DownloadFileTask().filenameFrom(suffix: "RECORD_AUDIO.m4a")

        

       
       // let audioURL = URL.init(fileURLWithPath: audioFilename!.path)
        let recordSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC,
                                             AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                                             AVNumberOfChannelsKey: 1,
                                             AVSampleRateKey: 12000]
        
        do {
            recorder = try AVAudioRecorder.init(url: audioFilename!, settings: recordSettings)
            recorder?.delegate = self
            recorder?.isMeteringEnabled = true
            recorder?.prepareToRecord()
            recorder?.record()
            self.meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (timer: Timer) in
                //Update Recording Meter Values so we can track voice loudness
                if let recorder = self.recorder {
                    recorder.updateMeters()
                    self.recorderApc0 = recorder.averagePower(forChannel: 0)
                    self.recorderPeak0 = recorder.peakPower(forChannel: 0)
                }
            })
           
            self._success()
            
        } catch {
            self._error(error)
        }
        
    }
    
    func stopRecording() {
        finishRecording()
    }
    
    func playing()
    {
        do {
            //let audioURL = URL.init(fileURLWithPath: audioFilename!.path)
            try player = AVAudioPlayer.init(contentsOf: audioFilename!)
        } catch {
            
        }
        player?.prepareToPlay()
        player?.play()
        player?.volume = 1.0
        player?.delegate = self
    }
    
    func stopPlaying()
    {
        if(player != nil)
        {
            player?.stop();
            player = nil
        }
    }
    
    func finishRecording() {
        if(recorder != nil){
            recorder!.stop()
        }
        recorder = nil
    }
    func _error(_ error: Error?) {
        result?.success = false
        if(error != nil){
            result?.error = error?.localizedDescription
        }
        app21?.App21Result(result: result!)
    }
    func _success() {
        result?.success = true;
        app21?.App21Result(result: result!)
    }
    func RecordAudio(result: Result,app21: App21) -> Void{
        do
        {
            self.app21 = app21
            self.result = result
            
            let parser = JSON.parse(RecordInfo.self, from: result.params!)
            if parser.1 != nil{
                
                self.result!.error = parser.1
                
                _error(nil)
                return
            }
            
            let recordInfo: RecordInfo = parser.0!
            
            switch recordInfo.action {
            case "record":
                _PERMISSION {
                    self.startRecording()
                   
                }
                //
                break;
            case "record_stop":
                stopRecording()
               _success()
                //
                break;
            case "play":
                playing()
                _success()
                //
                break;
            case "play_stop":
                stopPlaying();
                _success()
                //
                break;
            default:
                //
            break;
            }
            
            
        }catch{
            _error(error)
        }
    }
}
class RecordInfo : Decodable{
    var action: String = "";
    var filename: String? = nil;
}
 //MARK:- Audio Recorder Delegate

extension Record21: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        
        print("AudioManager Finish Recording")
        
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        //print("Encoding Error", /error?.localizedDescription)
    }
    
}
//MARK:- Audio Player Delegates

extension Record21: AVAudioPlayerDelegate {
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                     successfully flag: Bool) {
        
        player.stop()
        
        print("Finish Playing")
        
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer,
                                        error: Error?) {
        
        //print(/error?.localizedDescription)
        
    }
    
}


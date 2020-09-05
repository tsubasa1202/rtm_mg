//
//  VideoChatViewController.swift
//  Agora iOS Tutorial
//
//  Created by James Fang on 7/14/16.
//  Copyright © 2016 Agora.io. All rights reserved.
//

import UIKit
import AgoraRtcKit
import AgoraRtmKit
import SVProgressHUD
import Alamofire
import SDWebImage
import Reachability
import Firebase
import SwiftyJSON
import SDWebImagePDFCoder

class VideoKYCViewController: UIViewController {
    @IBOutlet weak var localVideo: UIView!
    @IBOutlet weak var remoteVideo: UIView!
    @IBOutlet weak var controlButtons: UIView!
    @IBOutlet weak var localVideoMutedBg: UIImageView!
    @IBOutlet weak var localVideoMutedIndicator: UIImageView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var videoMuteButton: UIButton!
    @IBOutlet weak var noMicrophoneView: UIImageView!
    @IBOutlet weak var networkUnstableLabel: UILabel!
    @IBOutlet weak var testLiveRoomLabel: UILabel!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var banUserButton: UIButton!
    @IBOutlet weak var beautyEffectButton: UIButton!
    @IBOutlet weak var localGuideTextLabel: UILabel!
    @IBOutlet weak var acceptButton: UIButton!
    @IBOutlet weak var informationButton: UIButton!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var certificateImageView: UIImageView!
    
    var agoraKit: AgoraRtcEngineKit!
    var userId: String!
    var castId: String!
    var eventId: String!
    var liveId: String!
    var timer : Timer!
    var endTime: String?
    var KYCVideoChannelName: String = ""
    var laneRTMChannelName: String = ""
    var voiceOnly = false // 配信者の映像をユーザーがから見たときにOFFにする
    var userVoiceOnly = false // ユーザーの映像を配信者から見たときにOFFにする
    var isUser = true // 配信者の映像をユーザーから見たときにOFFにする
    var castImage = appDelegate.dummyUseriamgeUrl
    var userImage = appDelegate.dummyUseriamgeUrl
    var channelProfile = "broadcast"
    var diffEndTime: Double!
    var isLowVideoQuality = false
    var isLocalVideoMuted = false
    var isRemoteVideoMuted = false
    var isInVisibleUserVideoFromCast = false
    var isAppBackground = false
    var netWorkBadCount = 0
    var joinEightCount = 0 // joinしてから8が表示される回数
    var isTestLive = false
    var testNormalCount : Int = 30 // テストルームでの待機時間
    var InputStr:String! // 通報コメント

    var showNetworkUnstableLabel = true // バックエンドでネットワーク不安定のラベルを表示するか切り替え
    var acceptNetworkQualityInVideo = 3 // バックエンドでネットワーク不安定のラベルを表示する基準を切り替え
    let PROHIBIT_SCREENRECORDING_TITLE = "画面録画禁止"
    let PROHIBIT_SCREENRECORDING_MESSAGE = "画面録画は禁止です。画面録画を停止してから再度入室してください。"
    let PROHIBIT_SCREENSHOT_TITLE = "スクリーンショット禁止"
    let PROHIBIT_SCREENSHOT_MESSAGE = "スクリーンショットは禁止です。再入室は可能ですが、繰り返し行った場合アカウントを停止します。"
    var isProhibitScreenshot = false
    var banOkAction: UIAlertAction!
    let MINIMUM_BAN_COMMENT = 5
    var localTapped = false
    var isStarted = false
    var rtmChannel: AgoraRtmChannel?
    let KYC_UID: UInt = 2
    let INFORMATION_UID: UInt = 3
    let defaultImage = "https://image.withlive.jp/images/group/default_group_image.png"
    

    #if DEBUG_MG
    let AppID: String = ""
    #else
    let AppID: String = ""
    #endif


    override func viewDidLoad() {
        super.viewDidLoad()
        AgoraRtm.updateKit(delegate: self)
        // Do any additional setup after loading the view, typically from a nib.
        self.backgroundImageView.image = Setting.backgroundImage
        
        self.laneRTMChannelName = "\(castId!)_\(eventId!)"
        print("laneRTMChannelName: \(laneRTMChannelName)")
    
        // ナビゲーションを透明にする処理
        self.navigationController!.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController!.navigationBar.shadowImage = UIImage()
        self.navigationItem.hidesBackButton = true //戻るボタンを表示しなし
        self.localVideo.isUserInteractionEnabled = true
        self.localVideo.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.viewTapped(_:))))
        
        self.certificateImageView.clipsToBounds = true
        self.certificateImageView.isUserInteractionEnabled = true
        self.certificateImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.certificateHide(_:))))
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.certificateShow))
        view.addGestureRecognizer(tapGestureRecognizer)
        view.isUserInteractionEnabled = true
        
        // デフォルトでフィルターON
        // beautyButtonTapped(beautyEffectButton)
        self.networkUnstableLabel.isHidden = true
        self.localGuideTextLabel.text = "タップして拡大"
        self.localGuideTextLabel.backgroundColor = UIColor.black
        self.localGuideTextLabel.alpha = 0.3
        self.localGuideTextLabel.layer.masksToBounds = true
        self.localGuideTextLabel.layer.cornerRadius = self.localGuideTextLabel.frame.height * 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
           //  self.localGuideTextLabel.isHidden = false
        }
        
        self.acceptButton.isHidden = true
        self.informationButton.isHidden = true
        
        hideVideoMuted()
        initializeAgoraEngine()
        setupVideo()
        setupLocalVideo()
            
        Api.requestAPI(nil, .get, Api.kyc, ["event_id" : eventId!], self){ res in
            let result = res["result"]
            if result.count > 0 {
                self.liveId = result[0]["live_id"].string!
                self.KYCVideoChannelName = result[0]["channel_kyc"].string!
                self.userNameLabel.text = "liveID: " + self.liveId
                    + "\n" +  result[0]["cast_name"].string! + " " +  result[0]["part"].string!
                    + "\n" +  result[0]["campaign_name"].string!
                    + "\n" +  String(result[0]["serials_count"].int!) + "枚"
                    + "\n\n" + result[0]["user_name"].string!
                
                if let nameSign = result[0]["name_sign"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(nameSign)"
                }
                
                if let address = result[0]["address"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(address)"
                }
                
                if let birthday = result[0]["birthday"].string {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n\(birthday)"
                }
                
                if let typhoon = result[0]["typhoon"].string, typhoon == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【台風】※"
                }
                
                if let parent = result[0]["parent"].string, parent == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【保護者】※\n" + result[0]["parent_name"].string!
                }
                
                if let user_image = result[0]["user_image"].string {
                    let PDFCoder = SDImagePDFCoder.shared
                    SDImageCodersManager.shared.addCoder(PDFCoder)
                    self.certificateImageView.sd_setImage(with: URL(string: user_image))
                }else{
                    self.certificateImageView.sd_setImage(with: URL(string: self.defaultImage))
                }
                self.joinChannel(result[0]["channel_kyc"].string!)
            }else{
                // 1秒おきに接続者を探す
                self.acceptButton.isHidden = true
                self.informationButton.isHidden = true
                self.skipButton.isHidden = true
                SVProgressHUD.setDefaultMaskType(.none)
                SVProgressHUD.show(withStatus: "現在、認証待機ユーザーがいませんので、接続待機中です。")
                self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTimer(timer:)), userInfo: nil, repeats: true)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        AgoraRtm.kit?.login(byToken: nil, user: Util.randomString(length: 10)) { [unowned self] (errorCode) in
            guard (errorCode == .ok || errorCode == .alreadyLogin) else {
                // print("login error: \(errorCode.rawValue)")
                return
            }
            self.createChannel(self.laneRTMChannelName)
        }
        
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        return .portrait
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    /// 画面が閉じる直前に呼ばれる
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // タイマーを停止する
        if let workingTimer = timer{
            workingTimer.invalidate()
        }
        
        SVProgressHUD.dismiss()
        if liveId != nil {
            Api.requestAPI(nil, .delete, "\(Api.connection)/\(liveId!)", nil, self){_ in}
        }
        
    }
    
    @objc func certificateHide(_ sender: UITapGestureRecognizer){
        self.certificateImageView.isHidden = true
    }
    
    @objc func certificateShow(_ sender: UITapGestureRecognizer){
        self.certificateImageView.isHidden = false
    }
    
    @objc func updateTimer(timer: Timer) {
        Api.requestAPI(nil, .get, Api.kyc, ["event_id" : eventId!], self){ res in
            let result = res["result"]
            if result.count > 0 {
                self.acceptButton.isHidden = true
                self.informationButton.isHidden = true
                self.skipButton.isHidden = false
                self.certificateImageView.isHidden = false
                self.liveId = result[0]["live_id"].string!
                self.KYCVideoChannelName = result[0]["channel_kyc"].string!
                self.userNameLabel.text = "liveID: " + self.liveId
                + "\n" +  result[0]["cast_name"].string! + " " + result[0]["part"].string!
                + "\n" +  result[0]["campaign_name"].string!
                + "\n" +  String(result[0]["serials_count"].int!) + "枚"
                + "\n\n" + result[0]["user_name"].string!
                
                if let nameSign = result[0]["name_sign"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(nameSign)"
                }
                
                if let address = result[0]["address"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(address)"
                }
                
                if let birthday = result[0]["birthday"].string {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n\(birthday)"
                }
                
                if let typhoon = result[0]["typhoon"].string, typhoon == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【台風】※"
                }
                
                if let parent = result[0]["parent"].string, parent == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【保護者】※\n" + result[0]["parent_name"].string!
                }
                
                if let user_image = result[0]["user_image"].string {
                    let PDFCoder = SDImagePDFCoder.shared
                    SDImageCodersManager.shared.addCoder(PDFCoder)
                    self.certificateImageView.sd_setImage(with: URL(string: user_image))
                }else{
                    self.certificateImageView.sd_setImage(with: URL(string: self.defaultImage))
                }
                self.joinChannel(result[0]["channel_kyc"].string!)
                self.timer.invalidate()
            }
        }
        
    }
    
    func forceLeave(title: String, message: String){
        leaveChannel()
        if appDelegate.topViewController() != nil {
            Util.viewAlertNoMove(title: title, message: message, vc: appDelegate.topViewController()!)
        }else{
            SVProgressHUD.showError(withStatus: message)
            SVProgressHUD.dismiss(withDelay: 3)
        }
    }
    
    func getFileData(_ filePath: URL) -> Data? {
        let fileData: Data?
        do {
            fileData = try Data(contentsOf: filePath)
        } catch {
            // ファイルデータの取得でエラーの場合
            fileData = nil
        }
        return fileData
    }
    
    func postAgoraLogFile(_ errorType: String?){
        // The default log file location is at Library/caches/agorasdk.log.
        let file_name = "agorasdk.log"
        if let dir = FileManager.default.urls( for: .cachesDirectory, in: .userDomainMask ).first {
            let path_file_name = dir.appendingPathComponent( file_name )
            let filedata = getFileData(path_file_name)
            
            if let logData = filedata {
                let date = Date()
                let format = DateFormatter()
                format.dateFormat = "yyyy-MM-dd-HH:mm:ss"
                format.timeZone   = TimeZone(identifier: "Asia/Tokyo")
                Api.uploadLog(headers: nil, imageData: logData, fileName: "\(format.string(from: date))", type:"text", channel: self.KYCVideoChannelName, errorType: errorType){_ in}
            }
        }
    }
    
    @objc func viewTapped(_ sender: UITapGestureRecognizer){
        let scale = self.view.frame.size.height / self.localVideo.frame.size.height
        let targetX = (self.view.bounds.width  -  self.localVideo.frame.size.width) / 2
        let targetY = (self.view.bounds.height - self.localVideo.frame.size.height) / 2
        let transferX = targetX - self.localVideo.frame.origin.x
        let transferY = targetY - self.localVideo.frame.origin.y
        if(!localTapped){
            let trans1 = CGAffineTransform(scaleX: scale , y: scale)
            let trans2 = CGAffineTransform(translationX: transferX, y:transferY)
            let trans3 = trans1.concatenating(trans2);
            localVideo.transform = trans3
            localTapped = true
        }else{
            let trans1 = CGAffineTransform(scaleX: 1/scale , y: 1/scale)
            let trans2 = CGAffineTransform(translationX: -transferX, y:-transferY)
            let trans3 = trans1.concatenating(trans2);
            localVideo.transform = trans3
            localTapped = false
        }
        
        self.localGuideTextLabel.text = localTapped ? "タップして縮小" : "タップして拡大"
    }
    
    @IBAction func beautyButtonTapped(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        let options = AgoraBeautyOptions()
        options.lighteningContrastLevel = .normal
        options.lighteningLevel = 0.7
        options.smoothnessLevel = 1.0
        options.rednessLevel = 0.3
        agoraKit.setBeautyEffectOptions(sender.isSelected, options: options)
        beautyEffectButton?.setImage(sender.isSelected ? #imageLiteral(resourceName: "btn_beautiful_cancel") : #imageLiteral(resourceName: "btn_beautiful"), for: .normal)
    }

    
    func initializeAgoraEngine() {
        agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: AppID, delegate: self)
        
        if let dir = FileManager.default.urls( for: .cachesDirectory, in: .userDomainMask ).first {
            let filePath = dir.appendingPathComponent("agorasdk.log")
            let path: String = filePath.path
            agoraKit.setLogFile(path)
        }
        // print("channelProfile: \(self.channelProfile)")
        if(self.channelProfile == "broadcast"){
            // print("channelProfile is broadcast")
            agoraKit.setChannelProfile(.liveBroadcasting)
            agoraKit.setClientRole(.broadcaster)
        }
    }

    func setupVideo() {
        // print("isLowVideoQuality: \(isLowVideoQuality)")
        let videoSize = self.isLowVideoQuality ? AgoraVideoDimension320x180 : AgoraVideoDimension640x360
        agoraKit.enableVideo()  // Default mode is disableVideo
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: videoSize,
                                                                             frameRate: .fps15,
                                                                             bitrate: AgoraVideoBitrateStandard,
                                                                             orientationMode: .adaptative))
    }
    
    @IBAction func accept(_ sender: Any) {
        
        let alert: UIAlertController = UIAlertController(title: "確認", message: "本人認証しますか？", preferredStyle:  UIAlertController.Style.alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.show()
            self.processAfterrButtonPush(command: "accept", param: [:])
        })
        let cancelAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
        })
        
        alert.addAction(cancelAction)
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    
    @IBAction func goInformationCenter(_ sender: Any) {
        
        
        let alert: UIAlertController = UIAlertController(title: "確認", message: "本人認証を承認せず、インフォーメーションに送ります。", preferredStyle:  UIAlertController.Style.alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.show()
          let param = [
                "information_center" : true
            ]
            self.processAfterrButtonPush(command: "decline", param: param)
        })
        let cancelAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
        })
        
        alert.addAction(cancelAction)
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)

    }
    
    @IBAction func skip(_ sender: Any) {
        
        let alert: UIAlertController = UIAlertController(title: "確認", message:"認証待機列の一番後ろにまわします。宜しいですか？", preferredStyle:  UIAlertController.Style.alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
            
            SVProgressHUD.setDefaultMaskType(.clear)
            SVProgressHUD.show()
            let param = [
                "kyc_skip" : true
            ]
            self.processAfterrButtonPush(command: nil, param: param)
        })
        let cancelAction: UIAlertAction = UIAlertAction(title: "キャンセル", style: UIAlertAction.Style.default, handler:{
            (action: UIAlertAction!) -> Void in
        })
        
        alert.addAction(cancelAction)
        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
        

    }
    
    func processAfterrButtonPush(command: String?, param: Parameters){
        
        Api.requestAPI(nil, .put, "\(Api.kyc)/\(liveId!)", param, self){ res in
            if command != nil {
                let message = AgoraRtmMessage()
                message.text = "\(command!)\(self.liveId!)"
                AgoraRtm.kit?.send(message, toPeer: self.liveId!, completion: { (sendResult) in
                    print("sendResult \(sendResult.rawValue)")
                    if sendResult == .ok {
                        self.leaveAndGoNext(res: res["result"])
                    }else{
                        // 相手がメッセージを受信できなかったので、KYCフラグをキャンセル
                        SVProgressHUD.dismiss()
                        Api.requestAPI(nil, .delete, "\(Api.kyc)/\(self.liveId!)", nil, self){_ in
                            Util.viewAlertNoMove(title: "エラー", message: "相手に信号が送信できませんでした。もう一度やり直してください。", vc: self)
                        }
                    }
                    
                })
            }else{
                self.leaveAndGoNext(res: res["result"])
            }
        }
    }
    
    func leaveAndGoNext(res: JSON?){
        self.agoraKit.leaveChannel { (agoraChannelStatus) in
            self.acceptButton.isHidden = true
            self.informationButton.isHidden = true
            print("agoraChannelStatus: \(agoraChannelStatus)")
            self.postAgoraLogFile(nil)
            
            let msg = AgoraRtmMessage()
            msg.text = "finish_kyc"
            self.rtmChannel?.send(msg, completion: nil) // レーンにKYCが進んだことを通知
            
             for subview in self.remoteVideo.subviews {
                 subview.removeFromSuperview()
             }
            
            if res != JSON.null {
                self.acceptButton.isHidden = true
                self.informationButton.isHidden = true
                self.skipButton.isHidden = false
                self.certificateImageView.isHidden = false
                self.liveId = res!["live_id"].string!
                self.KYCVideoChannelName = res!["channel_kyc"].string!
                self.userNameLabel.text = "liveID: " + self.liveId
                + "\n" +  res!["cast_name"].string! + " " +  res!["part"].string!
                + "\n" +  res!["campaign_name"].string!
                + "\n" +  String(res!["serials_count"].int!) + "枚"
                + "\n\n" + res!["user_name"].string!
                
                if let nameSign = res!["name_sign"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(nameSign)"
                }
                
                if let address = res!["address"].string {
                    self.userNameLabel.text = self.userNameLabel.text! + "\n\(address)"
                }
                
                if let birthday = res!["birthday"].string {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n\(birthday)"
                }
                if let typhoon = res!["typhoon"].string, typhoon == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【台風】※"
                }
                if let parent = res!["parent"].string, parent == "1" {
                       self.userNameLabel.text = self.userNameLabel.text! + "\n※【保護者】※\n" +  res!["parent_name"].string!
                }
                if let user_image = res!["user_image"].string {
                    let PDFCoder = SDImagePDFCoder.shared
                    SDImageCodersManager.shared.addCoder(PDFCoder)
                    self.certificateImageView.sd_setImage(with: URL(string: user_image))
                }else{
                    self.certificateImageView.sd_setImage(with: URL(string: self.defaultImage))
                }
                self.joinChannel(res!["channel_kyc"].string!)
            }else{
                SVProgressHUD.dismiss()
                // 1秒おきに接続者を探す
                self.userNameLabel.text = ""
                self.certificateImageView.sd_setImage(with: URL(string: ""))
                SVProgressHUD.setDefaultMaskType(.none)
                self.acceptButton.isHidden = true
                self.informationButton.isHidden = true
                self.skipButton.isHidden = true
                SVProgressHUD.setDefaultMaskType(.none)
                SVProgressHUD.show(withStatus: "現在、認証待機ユーザーがいませんので、接続待機中です。")
                self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.updateTimer(timer:)), userInfo: nil, repeats: true)
            }
             
        }
    }
    
    
    func setupLocalVideo() {
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0
        videoCanvas.view = localVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupLocalVideo(videoCanvas)
    }
    
    func handleError(message: String, dialogMessage: String? = nil){
        print(message)
        let parameters: Parameters = [
            "channel_name" : self.KYCVideoChannelName,
            "message": message,
            ]
        Api.requestAPI(nil, .post, Api.liveLogiOS, parameters, self){_ in }
        
        var errorDialogMessage = "Wi-Fiに接続中の場合は4Gに切り替えて再入室してください。4Gの場合はWi-Fiに切り替えるか、iPhoneの電源を入れ直すなどをして再入室してください。"
        if let reachability = try? Reachability() {
            if reachability.connection == .wifi{
                errorDialogMessage = "4G、または別のWi-Fiに切り替えて再入室してください。"
            }else if(reachability.connection == .cellular){
                errorDialogMessage = "Wi-Fiに切り替えるか、iPhoneの電源を入れ直すなどをして再入室してください。"
            }
        }
        
        if dialogMessage != nil {
            errorDialogMessage = dialogMessage!
        }
        let alert: UIAlertController = UIAlertController(title: "接続失敗", message: errorDialogMessage, preferredStyle:  UIAlertController.Style.alert)
        let defaultAction: UIAlertAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler:{
            // ボタンが押された時の処理を書く
            (action: UIAlertAction!) -> Void in
            self.leaveChannel()
        })
        alert.addAction(defaultAction)
        postAgoraLogFile(message)
        self.present(alert, animated: true, completion: nil)
    }
    
    func handleErrorNoAlert(message: String, postLog: Bool,  addParam: Parameters?){
        // print(message)
        var parameters: Parameters = [
            "channel_name" : self.KYCVideoChannelName,
            "message": message,
            "isLocalVideoMuted": isLocalVideoMuted,
            "isAppBackground" : isAppBackground,
            "netWorkBadCount": netWorkBadCount,
            "isTestLive": isTestLive
        ]
        
        if(addParam != nil){
            parameters.merge(addParam!) { (current, _) in current }
        }
        Api.requestAPI(nil, .post, Api.liveLogiOS, parameters, self){_ in }
        if(postLog){
            postAgoraLogFile(message)
        }
    }
    
    func joinChannel(_ channel: String) {
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)

        let code = agoraKit.joinChannel(byToken: nil, channelId: channel, info: nil, uid: KYC_UID, joinSuccess: nil)
        print("join_channel: \(channel)")
        
        muteLocalVideo(mute: true) // 認証のデフォルトはビデオなし
        videoMuteButton.isSelected = true

        SVProgressHUD.dismiss()
        if code == 0 {
            UIApplication.shared.isIdleTimerDisabled = true // スリープにしない
        } else {
            DispatchQueue.main.async(execute: {
                self.handleError(message: "Join channel failed: \(code)")
            })
        }
    }
    
    @IBAction func didClickHangUpButton(_ sender: UIButton) {
        leaveChannel()
    }
    
    func leaveChannel() {
        agoraKit.leaveChannel(nil)
        hideControlButtons()
        UIApplication.shared.isIdleTimerDisabled = false // スリープにしないを解除
        remoteVideo.removeFromSuperview()
        localVideo.removeFromSuperview()
        postAgoraLogFile(nil)
        
        rtmChannel?.leave { (error) in
            // print("leave channel error: \(error.rawValue)")
        }
        
        AgoraRtm.kit?.logout(completion: { (error) in
            // print("AgoraRtm.kit.logout error: \(error.rawValue)")
        })
        
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func hideControlButtons() {
        controlButtons.isHidden = true
    }
    
    @objc func hideNetworkUnstableLable() {
        networkUnstableLabel.isHidden = true
    }

    
    func resetHideButtonsTimer() {
        VideoChatViewController.cancelPreviousPerformRequests(withTarget: self)
        // perform(#selector(hideControlButtons), with:nil, afterDelay:8)
    }

    
    @IBAction func didClickVideoMuteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        muteLocalVideo(mute: sender.isSelected)
    }
    
    @IBAction func didClickAudioMuteButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        muteLocalAudio(mute: sender.isSelected)
    }
    
    func muteLocalAudio(mute: Bool){
        agoraKit.muteLocalAudioStream(mute)
    }
    
    func muteLocalVideo(mute: Bool){
        agoraKit.muteLocalVideoStream(mute)
        // localVideo.isHidden = mute
        // localVideoMutedBg.isHidden = !mute
        // localVideoMutedIndicator.isHidden = !mute
        isLocalVideoMuted = mute
        resetHideButtonsTimer()
    }
    
    func hideVideoMuted() {
        localVideoMutedBg.isHidden = true
        localVideoMutedIndicator.isHidden = true
    }
    
    @IBAction func didClickSwitchCameraButton(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        agoraKit.switchCamera()
        resetHideButtonsTimer()
    }
    
    func getNetworkErrorMessage() -> String{
        var message = "ネットワーク不安Conversion to Swift 4.2 is available定\nネットワークを切り替えて下さい"
        
        if let reachability = try? Reachability() {
            if reachability.connection == .wifi{
                message = "ネットワーク不安定\n「4G」に切り替えて下さい"
            }else if(reachability.connection == .cellular){
                message = "ネットワーク不安定\n「Wi-Fi」に切り替えて下さい"
            }
        }
        return message
    }
        
    func changeTextField (sender: NSNotification) {
        let textField = sender.object as! UITextField
        if Util.countString(str: textField.text) >= MINIMUM_BAN_COMMENT {
            banOkAction.isEnabled = true
        }else{
            banOkAction.isEnabled = false
        }
    }
    
    
}

// MARK: AgoraRtmDelegate
extension VideoKYCViewController: AgoraRtmDelegate {
    func rtmKit(_ kit: AgoraRtmKit, connectionStateChanged state: AgoraRtmConnectionState, reason: AgoraRtmConnectionChangeReason) {
        /*
         showAlert("connection state changed: \(state.rawValue)") { [weak self] (_) in
         if reason == .remoteLogin, let strongSelf = self {
         strongSelf.navigationController?.popToRootViewController(animated: true)
         }
         }
         */
    }
    
    func rtmKit(_ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage, fromPeer peerId: String) {
    }
}

// MARK: AgoraRtmChannelDelegate
extension VideoKYCViewController: AgoraRtmChannelDelegate {
    func channel(_ channel: AgoraRtmChannel, memberJoined member: AgoraRtmMember) {
        // print("\(member.userId) join")
        DispatchQueue.main.async { [unowned self] in
            // self.showAlert("\(member.userId) join")
        }
    }
    
    func channel(_ channel: AgoraRtmChannel, memberLeft member: AgoraRtmMember) {
        // print("\(member.userId) left")
        DispatchQueue.main.async { [unowned self] in
            //  self.showAlert("\(member.userId) left")
        }
    }
    
    func channel(_ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember) {
        print("AgoraRtmChannel: \(message.text)")
        
    }
}

private extension VideoKYCViewController {
    func createChannel(_ channel: String) {
        let errorHandle = { [weak self] (action: UIAlertAction) in
            guard let strongSelf = self else {
                return
            }
            // strongSelf.navigationController?.popViewController(animated: true)
        }
        
        guard let rtmChannel = AgoraRtm.kit?.createChannel(withId: channel, delegate: self) else {
            // print("join channel fail")
            return
        }
        
        rtmChannel.join { [weak self] (error) in
            if error != .channelErrorOk, let strongSelf = self {
                // print("join channel error: \(error.rawValue)")
                // strongSelf.showAlert("join channel error: \(error.rawValue)", handler: errorHandle)
            }
        }
        
        self.rtmChannel = rtmChannel
    }
}

extension VideoKYCViewController: AgoraRtcEngineDelegate {
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionStateType, reason: AgoraConnectionChangedReason) {
        let reasonInt = reason.rawValue
        if(reasonInt == 2){
            // AgoraConnectionChangedInterrupted
            self.networkUnstableLabel.text = self.getNetworkErrorMessage()
            self.networkUnstableLabel.backgroundColor = UIColor.red
            self.networkUnstableLabel.textColor = UIColor.white
            self.networkUnstableLabel.isHidden = false
            perform(#selector(hideNetworkUnstableLable), with: nil, afterDelay: 3)

            let params: Parameters = [
                "state": state.rawValue,
                "reason": reasonInt
            ]
            handleErrorNoAlert(message: "Connection-Interrupted", postLog: true, addParam: params)
            
        }else if(reasonInt == 3){
            // AgoraConnectionChangedBannedByServer
            handleError(message: "Connection-BannedByServer-state-\(state.rawValue)-reason-\(reasonInt)")
        }else if(reasonInt == 4){
            // AgoraConnectionChangedJoinFailed
            handleError(message: "Connection-JoinFailed-state-\(state.rawValue)-reason-\(reasonInt)")
            
        }
    }

    /*
    // deprecated
    func rtcEngineConnectionDidInterrupted(_ engine: AgoraRtcEngineKit) {
        handleErrorNoAlert(message: "Connection-Interrupted", postLog: true, addParam: nil)
    }
     */
    
    
    func rtcEngineConnectionDidLost(_ engine: AgoraRtcEngineKit) {
        handleError(message: "Connection-Lost")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        var errorDialogMessage = "WithLIVEと起動中のアプリを全て終了してから再度入室してください。それでも解決しない場合はiPhoneの電源を入れ直してから再度入室してください。"
        if errorCode.rawValue == 1012 {
            errorDialogMessage = "LINE通話など、他のアプリで通話機能を利用していないかご確認ください。利用中の場合は終了してから再度入室してください。"
        }else if errorCode == .leaveChannelRejected {
            // チャンネルにjoinしていないのleaveすると呼ばれる
            return
        }
        
        handleError(message: "Other-error-errorCode-\(errorCode.rawValue)", dialogMessage: errorDialogMessage)
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, networkQuality uid: UInt, txQuality: AgoraNetworkQuality, rxQuality: AgoraNetworkQuality) {
        // print("uid: \(uid), txQuality: \(txQuality.rawValue), rxQuality: \(rxQuality.rawValue)")

        if(uid != 0){
            // 自分の情報についてのみ判定
            return
        }
        
        if(txQuality.rawValue == 8 || rxQuality.rawValue == 8){
            if(isTestLive){
                self.networkUnstableLabel.text = "接続中..."
                self.networkUnstableLabel.backgroundColor = UIColor.lightGray
                self.networkUnstableLabel.isHidden = false
                self.networkUnstableLabel.textColor = UIColor.white
            }
            
            joinEightCount += 1
            // print("joinEightCount: \(joinEightCount)")
            if(joinEightCount >= 10){
                let params: [String : Any] = [
                    "txQuality": txQuality.rawValue,
                    "rxQuality": rxQuality.rawValue,
                    "joinEightCount": joinEightCount
                ]
                handleErrorNoAlert(message: "NetworkQuality", postLog: false, addParam: params)
                
                if(showNetworkUnstableLabel || isTestLive ){
                    self.testNormalCount = 30 // テスト接続のカウントをリセットする
                    self.networkUnstableLabel.text = self.getNetworkErrorMessage()
                    self.networkUnstableLabel.backgroundColor = UIColor.red
                    self.networkUnstableLabel.textColor = UIColor.white
                    self.networkUnstableLabel.isHidden = false
                }
            }

        }else if(txQuality.rawValue >= self.acceptNetworkQualityInVideo || rxQuality.rawValue >= self.acceptNetworkQualityInVideo || txQuality.rawValue == 0 || rxQuality.rawValue == 0){
            let params: [String : Any] = [
                "txQuality": txQuality.rawValue,
                "rxQuality": rxQuality.rawValue
            ]
            handleErrorNoAlert(message: "NetworkQuality", postLog: false, addParam: params)

            netWorkBadCount += 1
            // print("netWorkBadCount: \(netWorkBadCount)")

            let limitBadNetWorkCount = 4 // 4回以上この分岐に入ったらエラーメッセージを表示
            if(showNetworkUnstableLabel && netWorkBadCount >= limitBadNetWorkCount || isTestLive && netWorkBadCount >= limitBadNetWorkCount ){
                self.testNormalCount = 30 // テスト接続のカウントをリセットする
                self.networkUnstableLabel.text = self.getNetworkErrorMessage()
                self.networkUnstableLabel.backgroundColor = UIColor.red
                self.networkUnstableLabel.textColor = UIColor.white
                self.networkUnstableLabel.isHidden = false
            }
            // else は直前と同じ表示となる。

        }else{
            if(isTestLive){
                self.testNormalCount -= 2 // 2秒おきにこのメソッドは呼ばれる
                var networkUnstableLabelText = "あと\(testNormalCount)秒待機"
                if(self.testNormalCount <= 0){
                    networkUnstableLabelText = "正常"
                }
                self.networkUnstableLabel.text = networkUnstableLabelText
                self.networkUnstableLabel.backgroundColor = UIColor.green
                self.networkUnstableLabel.textColor = UIColor.black
                self.networkUnstableLabel.isHidden = false
            }else{
                self.networkUnstableLabel.isHidden = true
            }
        }
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("didJoinedOfUid: \(uid)")
        
        if uid != 0 && uid != KYC_UID && uid != INFORMATION_UID  {
            // 接続が確認できたら、承認とインフォのボタンを表示
            self.acceptButton.isHidden = false
            self.informationButton.isHidden = false
            self.skipButton.isHidden = true
        }

    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, remoteAudioStateChangedOfUid uid: UInt, state status: AgoraAudioRemoteState, reason: AgoraAudioRemoteStateReason, elapsed:Int){
        print("remoteAudioStateChangedOfUid: \(status.rawValue)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, firstRemoteVideoDecodedOfUid uid:UInt, size:CGSize, elapsed:Int) {
        if (remoteVideo.isHidden) {
            remoteVideo.isHidden = false
        }
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = uid
        videoCanvas.view = remoteVideo
        videoCanvas.renderMode = .hidden
        agoraKit.setupRemoteVideo(videoCanvas)
    }
    
    internal func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid:UInt, reason:AgoraUserOfflineReason) {
        print("didOfflineOfUid: \(uid)")
        if(Int(reason.rawValue) == 0){
            self.acceptButton.isHidden = true
            self.informationButton.isHidden = true
            self.skipButton.isHidden = false
            self.remoteVideo.isHidden = true
        }
    }

}

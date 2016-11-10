//
//  ViewController.swift
//  iWIFI
//
//  Created by 馬聖豪 on 2016/11/8.
//  Copyright © 2016年 aaaddress1. All rights reserved.
//

import Cocoa
import Alamofire
import KeychainSwift

class ViewController: NSViewController {
    @IBOutlet weak var networkStatus: NSTextField!
    var reach: Reachability?
    let networkManageDomain:String = "https://wism.isu.edu.tw"

    func firstMatch(for regex: String, in text: String, in itemIndex: Int) -> String {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.firstMatch(in: nsString as String, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if (results == nil){
                return ""
            }
            
            return (nsString as NSString).substring(with: results!.rangeAt(itemIndex))
            
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return ""
        
        }
    }
    @IBAction func gotoGithub(_ sender: Any) {
     NSWorkspace.shared().open(NSURL(string: "https://github.com/aaaddress1/iWiFi")! as URL)
    }
    
    func loginCiscoAuth(authScr:String) {
        
        
        var parameters: Parameters = [
            "redirect_url": "",
            "Submit": "Submit",
            "username": usrTextField.stringValue,
            "password": passTextField.stringValue,
            "buttonClicked": "0"
        ]
        
        Alamofire.request(networkManageDomain + "/loginscript.js").responseString { jsScr in
            
            parameters["buttonClicked"] = self.firstMatch(
                for: "buttonClicked.value = ([\\d]+);",
                in: jsScr.result.value!,
                in: 1)
     
            parameters["network_name"] = self.firstMatch(
                for: "network_name.*value=.([^\\x22]+)\\x22",
                in: authScr,
                in: 1)
            parameters["err_flag"] = self.firstMatch(
                for: "err_flag.*value=.([^\\x22]+)\\x22",
                in: authScr,
                in: 1)
            parameters["info_flag"] = self.firstMatch(
                for: "info_flag.*value=.([^\\x22]+)\\x22",
                in: authScr,
                in: 1)
            parameters["info_msg"] = self.firstMatch(
                for: "info_msg.*value=.([^\\x22]+)\\x22",
                in: authScr,
                in: 1)
            let loginPath = self.firstMatch(
                for: "post..ACTION=.([^\\x22]+)",
                in: authScr,
                in: 1)
            
            if (loginPath == "") {
                self.networkStatus.stringValue = "connect via wifi (login path not found.)"
                self.networkStatus.textColor = NSColor.red
                return
            }
            
            Alamofire.request(self.networkManageDomain + loginPath, method: .post, parameters: parameters).responseString { final in
                if (final.result.value?.contains("logout successfully"))! {
                    self.networkStatus.stringValue = "connect via wifi (isu authenication.)"
                    self.networkStatus.textColor = NSColor.green
                }
                else {
                    self.networkStatus.stringValue = "connect via wifi (pass authenication fail.)"
                    self.networkStatus.textColor = NSColor.red
                    print(final)
                }
            }
        }

    }


    func networkBotMethod() {

        DispatchQueue.main.async {
            if self.reach!.isReachableViaWiFi() {
                
                Alamofire.request("http://www.google.com").responseString { googleScr in
                    if (googleScr.result.value!.contains("Google")) {
                        self.networkStatus.stringValue = "connect via wifi"
                        self.networkStatus.textColor = NSColor.green
                    }
                    else {
                        Alamofire.request(self.networkManageDomain).responseString { authScr in
                            
                            if let scr = authScr.result.value {
                                self.networkStatus.stringValue = "deal with web authenication..."
                                self.networkStatus.textColor = NSColor.blue
                                self.loginCiscoAuth(authScr: scr)
                            }
                            else {
                                self.networkStatus.stringValue = "web authenication response nothing?"
                                self.networkStatus.textColor = NSColor.red
                            }
                        }
                    }

                }

            }
            else if self.reach!.isReachableViaWWAN() {
                self.networkStatus.textColor = NSColor.blue
                self.networkStatus.stringValue = "connect via WWAN"
            }
            else {
                self.networkStatus.textColor = NSColor.red
                self.networkStatus.stringValue = "you're offline"
            }
        }
        
    }

    @IBAction func logoutButtonEvent(_ sender: Any) {
        let parameters: Parameters = [
            "userStatus": "1",
            "err_flag": "0",
            "err_msg": ""
        ]
        _ = Alamofire.request(networkManageDomain + "/logout.html",method: .post, parameters: parameters)

    }
    @IBOutlet weak var githubLinkTextField: NSTextField!
    @IBOutlet weak var usrTextField: NSTextField!
    @IBOutlet weak var passTextField: NSSecureTextField!
    @IBOutlet weak var saveButton: NSButton!
    
    func initNetworkListener() {
        reach = Reachability.forInternetConnection()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.networkBotMethod),
            name: NSNotification.Name.reachabilityChanged,
            object: nil
        )
        networkBotMethod()
        self.reach!.startNotifier()
    }

    @IBAction func saveUserAccountEvent(_ sender: Any) {
        let keychain = KeychainSwift()
        keychain.set(usrTextField.stringValue, forKey: "usr")
        keychain.set(passTextField.stringValue, forKey: "pass")
        
        let myPopup: NSAlert = NSAlert()
        myPopup.messageText = "Sucess"
        myPopup.informativeText = "All information saved successfully."
        myPopup.alertStyle = NSAlertStyle.informational
        myPopup.addButton(withTitle: "Got it!")
        myPopup.runModal()
        
    }
    
    override func viewDidAppear() {
        guard let window = self.view.window else { return }
        
        window.titlebarAppearsTransparent = true
        //window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        
     
        
        let keychain = KeychainSwift()
        keychain.accessGroup = "iWiFi"
        if let usr = keychain.get("usr"), let pass = keychain.get("pass") {
            usrTextField.stringValue = usr
            passTextField.stringValue = pass
            initNetworkListener()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


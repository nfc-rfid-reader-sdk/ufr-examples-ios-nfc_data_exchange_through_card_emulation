//
//  ViewController.swift
//  ufr-examples-ios-nfc_data_exchange_through_card_emulation
//
//  Created by D-Logic on 4/16/21.
//

import UIKit
import CoreNFC
import DLRadioButton

class mainView: UIViewController{
    
    @IBOutlet weak var mainScrollView: UIScrollView!
    @IBOutlet weak var mainContentView: UIView!
    
    @IBOutlet weak var btnTitle: UIButton!
    
    @IBOutlet weak var btnHeyPC: DLRadioButton!
    @IBOutlet weak var btnIamIOS: DLRadioButton!
    @IBOutlet weak var btnCustomMessage: DLRadioButton!
    
    @IBOutlet weak var txtMessage: UITextField!
    
    var sendMessage: String!
    
    var writeCommand = Data.init([0x00])
    let readCommand = Data.init([0xEB, 0x00, 0x64])
    
    let dl_color = UIColor(red: 143.0/255.0, green: 199.0/255.0, blue: 67.0/255.0, alpha: 1.0)
    
    func restartSession() {
        let session = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)
        session?.begin()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
        
        let width = UIScreen.main.bounds.size.width
        let height = UIScreen.main.bounds.size.height
        
        let imageViewBackground = UIImageView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        imageViewBackground.image = UIImage(named: "background_ios.png")
        
        imageViewBackground.contentMode = UIView.ContentMode.scaleToFill
        mainContentView.addSubview(imageViewBackground)
        mainContentView.sendSubviewToBack(imageViewBackground)
        
        /* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
        
        let underlineAttribute:[NSAttributedString.Key : Any] = [
            NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue,
            NSAttributedString.Key.foregroundColor: dl_color, NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20.0)
        ]
        btnTitle.setAttributedTitle(NSAttributedString(string: "NFC Phone 2 PC communication", attributes: underlineAttribute), for: .normal)
        
        btnTitle.sizeToFit()
        btnHeyPC.titleLabel?.sizeToFit()
        btnIamIOS.titleLabel?.sizeToFit()
        btnCustomMessage.titleLabel?.sizeToFit()
        
        btnHeyPC.isSelected = true
        txtMessage.delegate = self
        txtMessage.isEnabled = false
        
        /* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
        
    }
    
    @IBAction func inputSelection(_ sender: Any) {
        if (btnCustomMessage.isSelected == true)
        {
            txtMessage.isEnabled = true
        } else {
            txtMessage.isEnabled = false
            
        }
    }
    
    @IBAction func btnStartClicked(_ sender: Any) {
        
        
        print("btnStart was clicked!")
        
        if (btnHeyPC.isSelected)
        {
            sendMessage = "Hey PC where are you?"
        } else if (btnIamIOS.isSelected)
        {
            sendMessage = "I am iOS phone"
        } else {
            sendMessage = txtMessage.text
        }
        
        var messageBytes: [UInt8] = Array(self.sendMessage.utf8)
        if (messageBytes.count < 61)
        {
            let append_len = 61 - messageBytes.count
            let buffer: [UInt8] = Array(repeating: 0x00, count: append_len)
            messageBytes.append(contentsOf: buffer)
        }
        var writeCmd: [UInt8] = [0xEA, 0x00]
        writeCmd.append(UInt8(messageBytes.count))
        writeCmd.append(contentsOf: messageBytes)
        
        //format to 64 bytes total write command length
        //CoreNFC returns "Tag connection lost" when attempting to write more data than this in one command
        
        writeCommand = Data(writeCmd)
        restartSession()
    }
}

//MARK: NFC DELEGATE

extension mainView: NFCTagReaderSessionDelegate {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("Session became active")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print ("Invalidated with error: \(error.localizedDescription)")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("Tag detected: \(tags.first!)")
        
        let nfcTag = tags.first!
        
        session.connect(to: nfcTag, completionHandler: { error in
            if (error != nil) {
                print("Tag.connect() failed: \(error?.localizedDescription ?? "unknown error.")")
                session.invalidate(errorMessage: error?.localizedDescription ?? "Error occurred.")
                return
            }
            
            print("CONNECTED\n")
            if case let .miFare(sTag) = nfcTag {
                DispatchQueue.global(qos: .background).asyncAfter(deadline: .now(), execute: {
                    sTag.sendMiFareCommand(commandPacket: self.readCommand) { (data, error) in
                        if (error != nil) {
                            print("sendMiFareReadCommand Error: \(error!.localizedDescription)")
                            session.invalidate(errorMessage: error?.localizedDescription ?? "Error occurred.")
                            return
                        }
                        debugPrint(data)
                        print(data)
                        session.alertMessage = "Response: \(String(bytes: data, encoding: .utf8) ?? "")"
                        
                        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now(), execute: {
                            sTag.sendMiFareCommand(commandPacket: self.writeCommand) { (data, error) in
                                if (error != nil) {
                                    print("sendMiFareWriteCommand Error: \(error!.localizedDescription)")
                                    session.invalidate(errorMessage: error?.localizedDescription ?? "Error occurred.")
                                    return
                                }
                                print(" -------- Write cmd response -------- ")
                                print(data.hexDescription)
                                session.restartPolling()
                            }
                        })
                    }
                })
            }
        })
    }
}

//MARK: Helper functions
extension mainView: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}

extension Data {
    var hexDescription: String {
        return String(reduce("") {$0 + String(format: "%02x:", $1)}.dropLast().uppercased())
    }
}

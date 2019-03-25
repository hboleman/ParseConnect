//
//  ChatViewController.swift
//  Parsechat
//
//  Created by Hunter Boleman on 3/25/19.
//  Copyright © 2019 Hunter Boleman. All rights reserved.
//

import UIKit
import Parse

class ChatViewController: UIViewController {
    
    // Outlets
    @IBOutlet weak var chatMessageField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func doSendMessage(_ sender: Any) {
        let chatMessage = PFObject(className: "Message");
        chatMessage["text"] = chatMessageField.text ?? ""
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    

}

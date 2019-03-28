//
//  ChatViewController.swift
//  Parsechat
//
//  Created by Hunter Boleman on 3/25/19.
//  Copyright © 2019 Hunter Boleman. All rights reserved.
//

import UIKit
import Parse

class ChatViewController: UIViewController, UITableViewDataSource {
    
    // Outlets
    @IBOutlet weak var chatMessageField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    // Global Variables
    var chatMessages: [PFObject] = [];
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self as UITableViewDataSource
        // Auto size row height based on cell autolayout constraints
        tableView.rowHeight = UITableView.automaticDimension
        // Provide an estimated row height. Used for calculating scroll indicator
        tableView.estimatedRowHeight = 50
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.onTimer), userInfo: nil, repeats: true)
        
        getChatMessages();
        print ("reload tableView")
        self.tableView.reloadData();
    }
    
    @IBAction func doSendMessage(_ sender: Any) {
        let chatMessage = PFObject(className: "Message");
        chatMessage["text"] = chatMessageField.text ?? ""
        chatMessage["user"] = PFUser.current();
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Reusable Cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as! ChatCell;
        
        // gets a single message
        let chatMessage = chatMessages[indexPath.row];
        
        // Set text
        cell.messageLable.text = chatMessage["text"] as? String;
        
        //Set username
        if let user = chatMessage["user"] as? PFUser {
            // User found! update username label with username
            cell.usernameLabel.text = user.username;
        } else {
            // No user found, set default username
            cell.usernameLabel.text = "🤖"
        }
        
        return cell;
    }
    
    func getChatMessages(){
        let query = PFQuery(className:"Messages")
        query.addDescendingOrder("createdAt")
        query.limit = 20
        query.includeKey("user")
        
        query.findObjectsInBackground { (messages, error) in
            if let error = error {
                // Log details of the failure
                print(error.localizedDescription)
            } else if let messages = messages {
                // The find succeeded.
                self.chatMessages = messages
                print("Successfully retrieved \(messages.count) posts.")
                // Do something with the found objects
                //for messages in messages {
                //    print(messages.objectId as Any)
                //}
            }
        }
        print ("reload tableView")
        self.tableView.reloadData();
    }
    
    @objc func onTimer() {
        print("about to get chat messages")
        getChatMessages();
    }

}

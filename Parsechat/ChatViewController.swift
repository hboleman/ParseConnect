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
    
    // Master Message Object
    var chatMessages: [PFObject] = [];
    var userToMatchMake: String = "";
    var userFound: Bool = false;
    var currentMatchMake: Int = 1;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Needed for the UITableView
        tableView.dataSource = self as UITableViewDataSource
        // Auto size row height based on cell autolayout constraints
        tableView.rowHeight = UITableView.automaticDimension
        // Provide an estimated row height. Used for calculating scroll indicator
        tableView.estimatedRowHeight = 50
        // Sets getChatMessage to retrieve messages every 5 seconds
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.getChatMessages), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        getChatMessages();
        print ("reload tableView")
        self.tableView.reloadData();
        
        // Match Making
        
    }
    
    // Start Match Making Process
    func startMatchMaking(){
        // Set Status Open
        StatusOpen();
        ListenForUsers();
        
        
    }
    
    //Set Match Status to Open
    func StatusOpen() {
        let chatMessage = PFObject(className: "MatchMake");
        //chatMessage["text"] = chatMessageField.text!
        chatMessageField.text = "STATUS OPEN";
        chatMessage["text"] = "STATUS:OPEN"
        chatMessage["user"] = PFUser.current();
        chatMessage["current"] = currentMatchMake;
        currentMatchMake = currentMatchMake + 1;
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    // Listen for Open User
    func ListenForUsers(){
        var numberOfMessages: Int = 0;
        chatMessageField.text = "LISTENING FOR USER";
        
        while (userFound == false){
            let query = PFQuery(className:"MatchMake")
            query.addDescendingOrder("createdAt")
            query.limit = 10
            query.includeKey("user")
            
            query.findObjectsInBackground { (messages, error) in
                if let error = error {
                    // Log details of the failure
                    print(error.localizedDescription)
                } else if let message = messages {
                    // The find succeeded.
                    self.chatMessages = message
                    var msg: String = "";
                    var usr: String = "";
                    print("Successfully retrieved \(message.count) posts.")
                    // Looking for open
                    var countOfMessages = self.chatMessages.count;
                    
                    for index in 1...countOfMessages {
                        // gets a single message
                        let chatMessage = self.chatMessages[index];
                        msg = (chatMessage["text"] as? String)!;
                        usr = (chatMessage["user"] as? String)!;
                        if (msg == "STATUS:OPEN"){
                            print ("STATUS IS CONFIRMED OPEN");
                            print ("OPEN: \(usr)");
                            self.userToMatchMake = usr;
                            self.userFound = true;
                            
                        }
                    }
                }
                print ("reload tableView")
                self.tableView.reloadData();
            }
        }
    }
        // Checks latest message of a given user and sees if that one says open or not.
        func isUser (countOfMessages: Int){
            // Check if is newest message
            var messageCurrent = true;
            
            // Get number for latest message
            var mostRecentMsg: Int = 0;
            for index in 1...countOfMessages {
                let chatMessage = self.chatMessages[index];
                let curr = (chatMessage["current"] as? Int)!;
                var usr_i = (chatMessage["user"] as? String)!;
                // Find latest message
                if (usr_i == self.userToMatchMake){
                    mostRecentMsg = curr;
                }
            }
            // Find latest message and see if open
            for index in 1...countOfMessages {
                let chatMessage = self.chatMessages[index];
                let curr = (chatMessage["current"] as? Int)!;
                var usr_i = (chatMessage["user"] as? String)!;
                var msg_i = (chatMessage["text"] as? String)!;
                var mostRecentMsg: Int = 0;
                
                if (usr_i == self.userToMatchMake && curr == mostRecentMsg){
                    if (msg_i == "STATUS:OPEN"){
                        print ("FOUND: OPEN AND RECENT")
                    }
                    else {
                        print ("REJECT: OPEN BUT NOT RECENT")
                    }
                    
                }
            }
        }
        
        // Handshake's with Other User
        func InitiateHandshake(){
            
        }
        
        // Gets Chat Messages
        @objc func getChatMessages(){
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
                }
            }
            print ("reload tableView")
            self.tableView.reloadData();
        }
        
        // Sends The User's Message
        @IBAction func doSendMessage(_ sender: Any) {
            let chatMessage = PFObject(className: "Messages");
            chatMessage["text"] = chatMessageField.text!
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
        
        // Allows The User to Logout
        @IBAction func doLogout(_ sender: Any) {
            PFUser.logOutInBackground { (error) in
                if (error != nil) {
                    print("Error, cannot logout: \(String(describing: error))")
                }
            }
            self.performSegue(withIdentifier: "LogoutSeg", sender: nil)
        }
        
        // TABLE VIEW FUNCTIONS
        
        // Sets Table Rows
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return chatMessages.count;
        }
        
        // Sets Table Cell Contents
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
    }


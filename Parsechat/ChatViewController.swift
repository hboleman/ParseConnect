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
    var userAck: Bool = false;
    var currentMatchMake: Int = 0;
    var listeningForUsers: Bool = false;
    var listeningCount: Int = 0;
    var listeningCountMax: Int = 3;
    var isAtemptingHandshake: Bool = false;
    var isAtemptingAck: Bool = false;
    var AckLevel: Int = 0;
    var connectionEstablished: Bool = false;
    var SessionName: String = "";
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Needed for the UITableView
        tableView.dataSource = self as UITableViewDataSource
        // Auto size row height based on cell autolayout constraints
        tableView.rowHeight = UITableView.automaticDimension
        // Provide an estimated row height. Used for calculating scroll indicator
        tableView.estimatedRowHeight = 50
        // Sets getChatMessage to retrieve messages every 5 seconds
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.timedFunc), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        timedFunc();
        print ("reload tableView")
        self.tableView.reloadData();
        
        // Match Making
        startMatchMaking();
    }
    
    func resetVals(){
        userToMatchMake = "";
        userFound = false;
        userAck = false;
        currentMatchMake = 1;
        listeningForUsers = false;
        listeningCount = 0;
        listeningCountMax = 3;
        isAtemptingHandshake = false;
        isAtemptingAck = false;
        AckLevel = 0;
        connectionEstablished = false;
        SessionName = "";
    }
    
    // Start Match Making Process
    func startMatchMaking(){
        // Set Status Open
        print("Start MatchMaking")
        userAck = false;
        userFound = false;
        StatusOpen();
        ListenForUsers();
        
    }
    
    //Set Match Status to Open
    func StatusOpen() {
        print("Set Status to Open")
        let chatMessage = PFObject(className: "MatchMake");
        //chatMessageField.text = "STATUS OPEN";
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
    
    func SendAck(){
        print("Sent Ack")
        let chatMessage = PFObject(className: "Ack");
        //chatMessageField.text = "STATUS OPEN";
        if (AckLevel == 0){
            chatMessage["text"] = "FirstAck:\(userToMatchMake)"
        }
        if (AckLevel == 2){
            chatMessage["text"] = "SecondAck:\(userToMatchMake)"
        }
        if (AckLevel == 3){
            chatMessage["text"] = "FinalAck:\(userToMatchMake)"
        }
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
        print("Listening for Users")
        //chatMessageField.text = "LISTENING FOR USER";
        listeningForUsers = true;
    }
    
    func getMatchMsg(){
        print("Getting Match Make Messages")
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
                print("Successfully retrieved \(message.count) posts.")
            }
            print ("reload tableView")
            self.tableView.reloadData();
        }
    }
    
    func listenForMatch(){
        if (isAtemptingAck == false){
            // START HANDSHAKE MECHANISMS
            if (listeningCount >= listeningCountMax){
                print("Max Listening Atempts Reached - Handshake Aborted")
                resetVals();
            }
            listeningCount = listeningCount + 1;
            isAtemptingHandshake = true;
            self.startHandshake();
            // END HANDSHAKE MECHANISMS
        }
        else if (isAtemptingAck == true){
            if (listeningCount >= listeningCountMax){
                print("Max Ack Listening Atempts Reached - Handshake Aborted")
                resetVals();
            }
            listeningCount = listeningCount + 1;
            
            print("Getting Acknowledgement Messages")
            let query = PFQuery(className:"Ack")
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
                    print("Successfully retrieved \(message.count) posts.")
                }
                print ("reload tableView")
                self.tableView.reloadData();
                
            }
        }
    }
    
    func confirmSession(){
        getChatMessages();
        //var messageCurrent = true;
        if (connectionEstablished == false){
            let countOfMessages = self.chatMessages.count;
            listeningCount = 0;
            
            if (listeningCount >= listeningCountMax){
                print("Max Ack Listening Atempts Reached - Handshake Aborted")
                resetVals();
            }
            listeningCount = listeningCount + 1;
            
            for index in 0..<countOfMessages {
                // gets a single message
                let chatMessage = self.chatMessages[index];
                let usr = (chatMessage["user"] as? PFUser)!.username;
                let msg = (chatMessage["text"] as? String)!;
                // Find latest message
                if (usr == self.userToMatchMake && msg == "ConfirmSession"){
                    connectionEstablished = true;
                    print ("Connection Established");
                }
            }
            
        }
        else{
            // CONNECTION ESTABLISHED
            
            
        }
    }
    
    @objc func timedFunc() {
        if (AckLevel < 4){
            if (isAtemptingHandshake == false){
                getMatchMsg();
                
                // LOGIC FOR LISTENING SECTION
                if (listeningForUsers == true){
                    listenForMatch()
                    //LOGIC FOR LISTENING SECTION
                }
            }
        }
        else {
            
        }
    }
    
    func setSessionName() {
        let myUsername: String = PFUser.current()!.username!;
        let theirUsername: String = userToMatchMake;
        
        if (myUsername > theirUsername){
            SessionName = "SES:(\(myUsername)-\(theirUsername))"
        }
    }
    
    func LookForAck(){
        print("ListenForAck")
        // Check if is newest message
        //var messageCurrent = true;
        let countOfMessages = self.chatMessages.count;
        // Get number for latest message
        var mostRecentMsg: Int = 0;
        
        for index in 0..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let curr = (chatMessage["current"] as? Int)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            // Find latest message
            if (usr == self.userToMatchMake && curr > mostRecentMsg){
                mostRecentMsg = curr;
                print ("Most recent message found is: \(curr)");
            }
        }
        
        // Find latest message and see if Ack
        for index in 1..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let curr = (chatMessage["current"] as? Int)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            let msg = (chatMessage["text"] as? String)!;
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && curr == mostRecentMsg){
                print("Looking for: FirstAck:\(String(describing: PFUser.current()?.username))")
                if (msg == "FirstAck:\(String(describing: PFUser.current()?.username))"){
                    print ("First Ack Found!")
                    AckLevel = 2;
                }
                else if(msg == "SecondAck:\(String(describing: PFUser.current()?.username))"){
                    print ("Second Ack Found!")
                    AckLevel = 3;
                }
                else if (msg == "FinalAck:\(String(describing: PFUser.current()?.username))"){
                    print ("Final Ack Found!")
                    setSessionName();
                    AckLevel = 4;
                }
                else {
                    print ("REJECT: No Ack Found!")
                    AckLevel = 0;
                }
            }
        }
    }
    
    
    func startHandshake(){
        print("Start Handshake")
        // START HANDSHAKE MECHANISMS
        //while(userAck == false){
        if (self.anyUserOpen() == true){
            if (self.isUserOpen() == true){
                self.startAcknowledgement()
            }
        }
        // END HANDSHAKE MECHANISMS
        //}
    }
    
    
    func startAcknowledgement(){
        print ("Start ACK")
        isAtemptingAck = true;
        //userAck = true;
        listeningCount = 0;
    }
    
    
    func anyUserOpen() -> Bool {
        print("Any Users Open?")
        // Looking for open
        let countOfMessages = self.chatMessages.count;
        
        for index in 1..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let msg = (chatMessage["text"] as? String)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            
            if (msg == "STATUS:OPEN" && usr != PFUser.current()?.username){
                print ("STATUS IS CONFIRMED OPEN");
                print ("OPEN: \(String(describing: usr))");
                self.userToMatchMake = usr!;
                self.userFound = true;
                return true;
            }
        }
        return false;
    }
    
    
    
    // Checks latest message of a given user and sees if that one says open or not.
    func isUserOpen () -> Bool{
        print("Is User Open?")
        // Check if is newest message
        //var messageCurrent = true;
        let countOfMessages = self.chatMessages.count;
        // Get number for latest message
        var mostRecentMsg: Int = 0;
        
        for index in 0..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let curr = (chatMessage["current"] as? Int)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            // Find latest message
            if (usr == self.userToMatchMake && curr > mostRecentMsg){
                mostRecentMsg = curr;
                print ("Most recent message found is: \(curr)");
            }
        }
        
        // Find latest message and see if open
        for index in 1..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let curr = (chatMessage["current"] as? Int)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            let msg = (chatMessage["text"] as? String)!;
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && curr == mostRecentMsg){
                if (msg == "STATUS:OPEN"){
                    print ("FOUND: OPEN AND RECENT")
                    return true;
                }
                else {
                    print ("REJECT: OPEN BUT NOT RECENT")
                    return false;
                }
            }
        }
        return false;
    }
    
    
    //---------- Old Chat Stuff ----------//
    
    // Gets Chat Messages
    func getChatMessages(){
        let query = PFQuery(className:"\(SessionName)")
        query.addDescendingOrder("createdAt")
        query.limit = 10
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
        let chatMessage = PFObject(className: "\(SessionName)");
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
        print("DELETING SESSION")
        PFObject.deleteAll(inBackground: chatMessages);
        
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


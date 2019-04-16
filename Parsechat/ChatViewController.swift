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
    @IBOutlet weak var matchMakeOut: UIBarButtonItem!
    @IBOutlet weak var navBarOut: UINavigationItem!
    
    
    // Master Message Object
    var chatMessages: [PFObject] = [];
    var userToMatchMake: String = "";
    var userFound: Bool = false;
    var userAck: Bool = false;
    var currentMatchMake: Int = 0;
    var listeningForUsers: Bool = false;
    var listeningCount: Int = 0;
    var listeningCountMax: Int = 1000;
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
        print ("reload tableView")
        self.tableView.reloadData();
        
        navBarOut.title = PFUser.current()?.username;
    }
    
    @IBAction func matchMake(_ sender: Any) {
        print("In MatchMake")
        resetVals();
        matchMakeOut.isEnabled = false;
        matchMakeOut.title = "Waiting"
        matchMakeOut.tintColor = UIColor.gray;
        
        // Sets getChatMessage to retrieve messages every 5 seconds
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.timedFunc), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        timedFunc();
        
        startMatchMaking();
        
        //matchMakeOut.isEnabled = true;
        //matchMakeOut.title = "Match Make"
        //matchMakeOut.tintColor = UIColor.blue;
    }
    
    
    func resetVals(){
        print("Reset Vals")
        userToMatchMake = "";
        userFound = false;
        userAck = false;
        currentMatchMake = 1;
        listeningForUsers = false;
        listeningCount = 0;
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
        chatMessage["type"] = "STATUS";
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
        let chatMessage = PFObject(className: "MatchMake");
        //chatMessageField.text = "STATUS OPEN";
        
        if (AckLevel <= 0){
            chatMessage["text"] = "FirstAck:\(userToMatchMake)"
            
            var test: String = "";
            test = chatMessage["text"] as! String
            print("Test: " + test);
        }
        if (AckLevel > 0 && AckLevel <= 2){
            chatMessage["text"] = "SecondAck:\(userToMatchMake)"
            print("Send Second Ack Set: \(String(describing: chatMessage["text"]))")
        }
        if (AckLevel == 3){
            chatMessage["text"] = "FinalAck:\(userToMatchMake)"
            print("Send Final Ack Set: \(String(describing: chatMessage["text"]))")
        }
        chatMessage["user"] = PFUser.current();
        chatMessage["current"] = currentMatchMake;
        chatMessage["type"] = "ACK";
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
        chatMessageField.text = "Lst for Opn Usr"
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
    
    func timeout() -> Bool {
        if (listeningCount >= listeningCountMax){
            print("TIMED OUT - Vals Reset")
            resetVals();
            return true;
        }
        listeningCount = listeningCount + 1;
        return false
    }
    
    func listenForMatch(){
        if (isAtemptingAck == false){
            print("Listening For Match")
            chatMessageField.text = "Lst for Match"
            // START HANDSHAKE MECHANISMS
            if (timeout()){
                print("timeout from listen to match")
            }
            else{
                isAtemptingHandshake = true;
                self.startHandshake();
                // END HANDSHAKE MECHANISMS
            }
        }
        else if (isAtemptingAck == true){
            if (listeningCount >= listeningCountMax){
                print("Timeout from Listening for Ack")
            }
            else {
                // Listen for Acks
                ListenForAck();
                    print ("reload tableView - Ack")
                    self.tableView.reloadData();
                    
                
            }
        }
    }
    
    func confirmSession(){
        print("Inside ConfirmSession")
        getChatMessages();
        //var messageCurrent = true;
        if (connectionEstablished == false){
            let countOfMessages = self.chatMessages.count;
            
            if (timeout()){
                print("Timeout from Confirm Session")
            }
            listeningCount = listeningCount + 1;
            
            for index in 0..<countOfMessages {
                // gets a single message
                let chatMessage = self.chatMessages[index];
                let usr = (chatMessage["user"] as? PFUser)!.username;
                let msg = (chatMessage["text"] as? String)!;
                let typ = (chatMessage["type"] as? String)!;
                // Find latest message
                if (usr == self.userToMatchMake && msg == "ConfirmSession" && typ == "ACK"){
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
        print("Inside TimedFunc")
        if (AckLevel < 4){
            if (isAtemptingHandshake == false){
                getMatchMsg();
                
                // LOGIC FOR LISTENING SECTION
                if (listeningForUsers == true){
                    listenForMatch()
                    //LOGIC FOR LISTENING SECTION
                }
            }
            else if (isAtemptingAck == true){
                // Trying to Ack
                SendAck();
                ListenForAck();
            }
        }
        else {
            // If Trying to Ack
            getChatMessages();
        }
    }
    
    func setSessionName() {
        print("Inside SetSessionName")
        let myUsername: String = PFUser.current()!.username!;
        let theirUsername: String = userToMatchMake;
        
        if (myUsername > theirUsername){
            SessionName = "SES:(\(myUsername)-\(theirUsername))"
        }
    }
    
    func ListenForAck(){
        print("ListenForAck")
        chatMessageField.text = "Lst for Ack"
        // Check if is newest message
        //var messageCurrent = true;
        let countOfMessages = self.chatMessages.count;
        // Get number for latest message
        //var mostRecentMsg: Int = 0;
        
//        for index in 0..<countOfMessages {
//            // gets a single message
//            let chatMessage = self.chatMessages[index];
//            let curr = (chatMessage["current"] as? Int)!;
//            let usr = (chatMessage["user"] as? PFUser)!.username;
//            let typ = (chatMessage["type"] as? String)!;
//            // Find latest message
//            if (usr == self.userToMatchMake && curr > mostRecentMsg && typ == "ACK"){
//                mostRecentMsg = curr;
//                print ("Most recent message found is: \(curr)");
//            }
//        }
        
        // Find latest message and see if Ack
        var flag: Bool = false;
        for index in 1..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            //let curr = (chatMessage["current"] as? Int)!;
            let usr = (chatMessage["user"] as? PFUser)!.username;
            let msg = (chatMessage["text"] as? String)!;
            let typ = (chatMessage["type"] as? String)!;
            
            var currUser: String = "";
            currUser = PFUser.current()?.username ?? "N/A";
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && typ == "ACK"){
                print("Test Listen Ack")
                print(("FirstAck:" + currUser));
                if (msg == ("FirstAck:" + currUser)){
                    print ("First Ack Found!")
                    chatMessageField.text = "ACK: 1"
                    AckLevel = 2;
                    flag = false;
                }
                else if(msg == ("SecondAck:" + currUser)){
                    print ("Second Ack Found!")
                    chatMessageField.text = "ACK: 2"
                    AckLevel = 3;
                    flag = false;
                }
                else if (msg == ("FinalAck:" + currUser)){
                    print ("Final Ack Found!")
                    chatMessageField.text = "ACK: 3"
                    setSessionName();
                    AckLevel = 4;
                    flag = false;
                }
                else {
                    flag = true;
                }
            }
        }
        if (flag == true){
            print ("REJECT: No Ack Found!")
            //AckLevel = 0;
        }
        timeout();
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
            let typ = (chatMessage["type"] as? String)!;
            
            if (msg == "STATUS:OPEN" && usr != PFUser.current()?.username && typ == "STATUS"){
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
            let typ = (chatMessage["type"] as? String)!;
            // Find latest message
            if (usr == self.userToMatchMake && curr > mostRecentMsg && typ == "STATUS"){
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
            let typ = (chatMessage["type"] as? String)!;
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && curr == mostRecentMsg && typ == "STATUS"){
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
        print("Inside getChatMessages")
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
        print("Inside doSendMessage")
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
        let curr = (chatMessage["current"] as? Int)!;
        //Set username
        if let user = chatMessage["user"] as? PFUser {
            // User found! update username label with username
            cell.usernameLabel.text = (user.username ?? "" + String(curr));
        } else {
            // No user found, set default username
            cell.usernameLabel.text = "🤖"
        }
        return cell;
    }
}


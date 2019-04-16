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
    var postNumber: Int = 0;
    var listeningForUsers: Bool = false;
    var timoutCounter: Int = 0;
    var timeoutMax: Int = 20;
    var isAtemptingAck: Bool = false;
    var AckLevel: Int = 0;
    var connectionEstablished: Bool = false;
    var SessionName: String = "";
    var freezeData: Bool = false;
    
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
        chatMessageField.text = "In MatchMake"
        
        resetVals();
        matchMakeOut.isEnabled = false;
        matchMakeOut.title = "Waiting"
        matchMakeOut.tintColor = UIColor.blue;
        
        // Sets getChatMessage to retrieve messages every 5 seconds
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.timedFunc), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        timedFunc();
        startMatchMaking();
    }
    
    
    func resetVals(){
        print("Reset Vals")
        //chatMessageField.text = "Reset Vals"
        userToMatchMake = "";
        listeningForUsers = false;
        isAtemptingAck = false;
        AckLevel = 0;
        connectionEstablished = false;
        SessionName = "";
        freezeData = false;
    }
    
    // Start Match Making Process
    func startMatchMaking(){
        print("Start MatchMaking")
        //chatMessageField.text = "Start MatchMaking"
        resetVals();
        setStatusAsOpen();
        getMatchParseData();
        listeningForUsers = true;
    }
    
    //Set Match Status to Open
    func setStatusAsOpen() {
        print("Set Status to Open")
        chatMessageField.text = "Set Status as Open"
        
        let chatMessage = PFObject(className: "MatchMake");
        //chatMessageField.text = "STATUS OPEN";
        chatMessage["text"] = "STATUS:OPEN"
        chatMessage["user"] = PFUser.current();
        chatMessage["current"] = postNumber;
        chatMessage["type"] = "STATUS";
        postNumber = postNumber + 1;
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    func SendAck(){
        print("In Send Ack")
        //chatMessageField.text = "In Send Ack"
        
        let chatMessage = PFObject(className: "MatchMake");
        
        if (AckLevel <= 0){
            chatMessage["text"] = "FirstAck:\(userToMatchMake)"
            
            var test: String = "";
            test = chatMessage["text"] as! String
            print("Send Ack Test: " + test);
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
        chatMessage["current"] = postNumber;
        chatMessage["type"] = "ACK";
        postNumber = postNumber + 1;
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    func getMatchParseData(){
        print("Get Parse Data")
        //chatMessageField.text = "Get Parse Data"
        matchMakeOut.tintColor = UIColor.green;
        
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
                self.matchMakeOut.tintColor = UIColor.blue;
            }
            print ("reload tableView")
            self.tableView.reloadData();
        }
    }
    
    func getSessionParseData(){
        self.matchMakeOut.tintColor = UIColor.green;
        print("Get Session Parse Data")
        //chatMessageField.text = "Get Session Parse Data"
        
        let query = PFQuery(className:SessionName)
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
            self.matchMakeOut.tintColor = UIColor.blue;
        }
    }
    
    func timeout(){
        if (timoutCounter >= timeoutMax){
            print("TIMED OUT!")
            chatMessageField.text = "Timed Out!"
            resetVals();
        }
        timoutCounter = timoutCounter + 1;
    }
    
    func confirmSessionIsActive(){
        print("Inside ConfirmSession")
        chatMessageField.text = "ENTERED SESSION"
        
        if (connectionEstablished == false){
            let countOfMessages = self.chatMessages.count;
            
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
                    //chatMessageField.text = "Connection Established";
                }
            }
        }
        else{
            // CONNECTION ESTABLISHED
            
            
        }
    }
    
    @objc func timedFunc() {
        print("Inside TimedFunc")
        //chatMessageField.text = "In Timed Func"
        if (freezeData == false){
            if(connectionEstablished == false){
             getMatchParseData();
            }
            else{
                getSessionParseData()
            }
            freezeData = true;
        }
        else if (connectionEstablished == true){
            chatMessageField.isEnabled = true;
            freezeData = true;
        }
        else if (AckLevel >= 4){
         confirmSessionIsActive()
        }
        else if (isAtemptingAck == true){
            // Trying to Ack
            SendAck();
            ListenForAck();
            timeout()
            freezeData = false;
        }
        
        else if (listeningForUsers == true){
            findPotentialUser()
            timeout()
            freezeData = false;
        }
    }
    
    func setCustomSessionName() {
        print("SetSessionName")
        //chatMessageField.text = "Set Session Name"
        
        let myUsername: String = PFUser.current()!.username!;
        let theirUsername: String = userToMatchMake;
        
        if (myUsername > theirUsername){
            SessionName = "SES:(\(myUsername)-\(theirUsername))"
        }
        else if (myUsername < theirUsername){
            SessionName = "SES:(\(theirUsername)-\(myUsername))"
        }
    }
    
    func ListenForAck(){
        print("ListenForAck")
        //chatMessageField.text = "List for Ack"
        
        // Check if is newest message
        let countOfMessages = self.chatMessages.count;
        
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
                print(("Test Listen Ack" + currUser))
                if (msg == ("FinalAck:" + currUser)){
                    print ("Final Ack Found!")
                    chatMessageField.text = "ACK: 3"
                    setCustomSessionName();
                    AckLevel = 4;
                    flag = false;
                }
                else if(msg == ("SecondAck:" + currUser)){
                    print ("Second Ack Found!")
                    chatMessageField.text = "ACK: 2"
                    AckLevel = 3;
                    flag = false;
                }
                else if (msg == ("FirstAck:" + currUser)){
                    print ("First Ack Found!")
                    chatMessageField.text = "ACK: 1"
                    AckLevel = 2;
                    flag = false;
                }
                else {
                    flag = true;
                }
            }
        }
        //if (flag == true){
            //print ("REJECT: No Ack Found!")
            //AckLevel = 0;
    //}
    }
    
    func findPotentialUser(){
        print("Atempting to Find User")
        chatMessageField.text = "Finding Potential Users"
        
        if (self.anyUserOpen() == true){
            if (self.isUserReallyOpen() == true){
                isAtemptingAck = true
                timoutCounter = 0;
            }
        }
    }
    
    func anyUserOpen() -> Bool {
        print("Any Users Open")
        chatMessageField.text = "Finding Any Open Users"
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
                return true;
            }
        }
        return false;
    }
    
    // Checks latest message of a given user and sees if that one says open or not.
    func isUserReallyOpen () -> Bool{
        print("Is User Really Open")
        chatMessageField.text = "Is User Really Open?"
        
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
                //self.chatMessageField.text = "";
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
        // gets a single message
        let chatMessage = chatMessages[indexPath.row];
        let curr = (chatMessage["current"] as? Int)!;
        let str = String(curr)
        
        // Reusable Cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as! ChatCell;
        // Set text
        cell.messageLable.text = chatMessage["text"] as? String;
        //Set username
        if let user = chatMessage["user"] as? PFUser {
            // User found! update username label with username
            cell.usernameLabel.text = (user.username);
        } else {
            // No user found, set default username
            cell.usernameLabel.text = "🤖"
        }
        return cell;
    }
}


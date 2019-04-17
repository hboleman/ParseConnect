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
    
    //------------------------------ Class Setup ------------------------------//
    
    // Outlets
    @IBOutlet weak var chatMessageField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var matchMakeOut: UIBarButtonItem!
    @IBOutlet weak var navBarOut: UINavigationItem!
    @IBOutlet weak var obstructorOut: UILabel!
    @IBOutlet weak var progViewOut: UIProgressView!
    
    
    // Global Variables
    var chatMessages: [PFObject] = [];
    var userToMatchMake: String = "";
    var postNumber: Int = 0;
    var listeningForUsers: Bool = false;
    var timeoutCounter: Int = 0;
    var timeoutMax: Int = 10;
    var isAtemptingAck: Bool = false;
    var AckLevel: Int = 0;
    var connectionEstablished: Bool = false;
    var freezeData: Bool = false;
    var activeConnection = false;
    var queryLimit: Int = 6;
    var connectionsToSkip: Int = 0;
    var connectionCount: Int = 0;
    var reset: Bool = false;
    var sendDataDelay: Int = 2;
    var sendDataCount: Int = 2;
    
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
        
        progViewOut.setProgress(0, animated: false);
        // Set Alpha to Zero for Debug
        obstructorOut.alpha = 0;
    }
    
    //------------------------------ Utility Functions ------------------------------//
    
    // Resets all values
    func resetVals(){
        print("Reset Vals")
        
        matchMakeOut.isEnabled = true;
        matchMakeOut.title = "Match Make"
        matchMakeOut.tintColor = UIColor.blue;
        
        userToMatchMake = "";
        listeningForUsers = false;
        isAtemptingAck = false;
        AckLevel = 0;
        connectionEstablished = false;
        freezeData = false;
        activeConnection = false;
        queryLimit = 10;
        connectionCount = 0;
        connectionsToSkip = 0;
        progViewOut.setProgress(0, animated: false);
        //obstructorOut.alpha = 1;
        sendDataCount = 2;
    }
    
    // Removes garbage
    func garbageRemoval(){
        //        print("In Garbage")
        //        //while(chatMessages.count > 10){
        //
        //        PFObject.deleteAll(inBackground: chatMessages) { (sucess, error) in
        //            if (sucess == true){
        //                print("Delete: TRUE")
        //            }
        //            else {
        //                print("Delete: FALSE")
        //            }
        //        }
    }
    
    // Does a timeout if connection not reached
    func timeout(){
        if (timeoutCounter >= timeoutMax){
            print("TIMED OUT!")
            chatMessageField.text = "Timed Out!"
            reset = true;
            resetVals();
        }
        timeoutCounter = timeoutCounter + 1;
    }
    
    //------------------------------ Scheduled Timer Function ------------------------------//
    
    // The logic that will run on a timer
    @objc func timedFunc() {
        if(reset == false){
            if (connectionCount >= connectionsToSkip){
                connectionCount = 0;
                matchMakeOut.isEnabled = false;
                matchMakeOut.title = "Waiting"
                matchMakeOut.tintColor = UIColor.gray;
                print("Timed Func Ran")
                
                if (freezeData == false){
                    if(connectionEstablished == false && AckLevel < 2){
                        getMatchParseData();
                    }
                    else if(connectionEstablished == false && AckLevel >= 2){
                        getConfirmParseData();
                    }
                    else{
                        getSessionParseData();
                    }
                    freezeData = true;
                }
                else if (connectionEstablished == true){
                    ActiveConnection();
                    freezeData = false;
                }
                else if (AckLevel >= 2){
                    checkIfSessionActive()
                    timeout();
                    freezeData = false;
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
            else{
                connectionCount = connectionCount + 1;
            }
        }
        else{
            if(connectionCount >= connectionsToSkip){
                resetVals()
            }
            else{
                connectionCount = connectionCount + 1;
            }
        }
    }
    
    //------------------------------ Starting Match Make ------------------------------//
    
    // Button that does Match Making Preperation
    @IBAction func matchMake(_ sender: Any) {
        print("In MatchMake")
        
        connectionCount = 0
        timeoutCounter = 0
        reset = false;
        matchMakeOut.isEnabled = false;
        matchMakeOut.title = "Waiting"
        matchMakeOut.tintColor = UIColor.gray;
        
        progViewOut.setProgress(0, animated: false);
        //obstructorOut.alpha = 1;
        // Sets getChatMessage to retrieve messages every 5 seconds
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timedFunc), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        timedFunc();
        startMatchMaking();
    }
    
    // Starts Match Making Process
    func startMatchMaking(){
        print("Start MatchMaking")
        //chatMessageField.text = "Start MatchMaking"
        getMatchParseData();
        garbageRemoval();
        resetVals();
        setStatusAsOpen();
        getMatchParseData();
        listeningForUsers = true;
    }
    
    //------------------------------ Match Make Send Status ------------------------------//
    
    //Set Match Status to Open
    func setStatusAsOpen() {
        if (sendDataCount >= sendDataDelay){
            progViewOut.setProgress(0.1, animated: true);
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
                    self.sendDataCount = 1;
                    //self.chatMessageField.text = "";
                } else if let error = error {
                    print("Problem saving message: \(error.localizedDescription)")
                }
            }
        }
        else {
            sendDataCount = sendDataCount + 1;
            timeoutCounter = 0;
        }
    }
    
    //Set Match Status to Closed
    func setStatusAsClosed() {
        if (sendDataCount >= sendDataDelay){
            progViewOut.setProgress(0.1, animated: true);
            print("Set Status to Closed")
            chatMessageField.text = "Set Status as Closed"
            
            let chatMessage = PFObject(className: "MatchMake");
            //chatMessageField.text = "STATUS OPEN";
            chatMessage["text"] = "STATUS:CLOSED"
            chatMessage["user"] = PFUser.current();
            chatMessage["current"] = postNumber;
            chatMessage["type"] = "STATUS";
            postNumber = postNumber + 1;
            
            chatMessage.saveInBackground { (success, error) in
                if success {
                    print("The Closed message was saved!")
                    self.sendDataCount = 1;
                    //self.chatMessageField.text = "";
                } else if let error = error {
                    print("Problem saving message: \(error.localizedDescription)")
                }
            }
        }
        else {
            sendDataCount = sendDataCount + 1;
            timeoutCounter = 0;
        }
    }
    
    //------------------------------ Find Potential Open User ------------------------------//
    
    // Parent logic for finding user
    func findPotentialUser(){
        print("Atempting to Find User")
        chatMessageField.text = "Finding Potential Users"
        progViewOut.setProgress(0.2, animated: true);
        
        if (self.anyUserOpen() == true){
            if (self.isUserReallyOpen() == true){
                isAtemptingAck = true
                timeoutCounter = 0;
            }
        }
    }
    
    // Looks for any open user
    func anyUserOpen() -> Bool {
        print("Any Users Open")
        chatMessageField.text = "Finding Any Open Users"
        progViewOut.setProgress(0.3, animated: true);
        // Looking for open
        let countOfMessages = self.chatMessages.count;
        
        for index in 0..<countOfMessages {
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
    
    // If any user is open, check to see if their latest message says this.
    func isUserReallyOpen () -> Bool{
        print("Is User Really Open")
        chatMessageField.text = "Is User Really Open?"
        progViewOut.setProgress(0.4, animated: true);
        
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
        for index in 0..<countOfMessages {
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
    
    //------------------------------ Acknowledgements ------------------------------//
    
    // Send Ack
    func SendAck(){
        print("In Send Ack")
        if (sendDataCount >= sendDataDelay){
            let chatMessage = PFObject(className: "MatchMake");
            
            if (AckLevel <= 0){
                chatMessage["text"] = "FirstAck:\(userToMatchMake)"
                
                var test: String = "";
                test = chatMessage["text"] as! String
                print("Send Ack Test: " + test);
            }
            else if (AckLevel > 0 && AckLevel < 2){
                chatMessage["text"] = "SecondAck:\(userToMatchMake)"
                print("Send Second Ack Set: \(String(describing: chatMessage["text"]))")
            }
            
            chatMessage["user"] = PFUser.current();
            chatMessage["current"] = postNumber;
            chatMessage["type"] = "ACK";
            postNumber = postNumber + 1;
            
            chatMessage.saveInBackground { (success, error) in
                if success {
                    print("The message was saved!")
                    self.sendDataCount = 1;
                } else if let error = error {
                    print("Problem saving message: \(error.localizedDescription)")
                }
            }
        }
        else{
            sendDataCount = sendDataCount + 1;
            timeoutCounter = timeoutCounter - 1;
        }
    }
    
    // Listen for Ack
    func ListenForAck(){
        print("ListenForAck")
        let countOfMessages = self.chatMessages.count;
        
        // Looks for ack in each message
        for index in 0..<countOfMessages {
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
                // If second ack is found
                if(msg == ("SecondAck:" + currUser) && (AckLevel >= 1 )){
                    print ("Second Ack Found!")
                    chatMessageField.text = "ACK: 2"
                    AckLevel = 2;
                    progViewOut.setProgress(0.7, animated: true);
                    //setStatusAsClosed();
                }
                    // If first ack is found
                else if (msg == ("FirstAck:" + currUser) && (AckLevel >= 0 && AckLevel < 2)){
                    print ("First Ack Found!")
                    chatMessageField.text = "ACK: 1"
                    AckLevel = 1;
                    progViewOut.setProgress(0.6, animated: true);
                }
                else {
                    
                }
            }
        }
    }
    
    //------------------------------ Retrieves Data ------------------------------//
    
    // Retrieves Match Data
    func getMatchParseData(){
        print("Get Parse Data")
        //chatMessageField.text = "Get Parse Data"
        matchMakeOut.tintColor = UIColor.black;
        
        let query = PFQuery(className:"MatchMake")
        query.addDescendingOrder("createdAt")
        query.limit = queryLimit;
        query.includeKey("user")
        
        query.findObjectsInBackground { (messages, error) in
            if let error = error {
                // Log details of the failure
                print(error.localizedDescription)
            } else if let message = messages {
                // The find succeeded.
                self.chatMessages = message
                print("Successfully retrieved \(message.count) posts.")
                self.matchMakeOut.tintColor = UIColor.gray;
            }
            print ("reload tableView")
            self.tableView.reloadData();
        }
    }
    
    // Retrieves Confirmation Data
    func getConfirmParseData(){
        self.matchMakeOut.tintColor = UIColor.black;
        print("Get Confirmation Parse Data")
        
        let query = PFQuery(className:"Confirm")
        query.addDescendingOrder("createdAt")
        query.limit = queryLimit
        query.includeKey("user")
        
        query.findObjectsInBackground { (messagesOther, error) in
            if let error = error {
                // Log details of the failure
                print(error.localizedDescription)
            } else if let message = messagesOther {
                // The find succeeded.
                self.chatMessages = message
                print("Successfully retrieved Confirmation Data \(message.count) posts.")
            }
            print ("reload tableView")
            self.tableView.reloadData();
            self.matchMakeOut.tintColor = UIColor.gray;
        }
    }
    
    // Retrieves Session Data
    func getSessionParseData(){
        self.matchMakeOut.tintColor = UIColor.black;
        print("Get Session Parse Data")
        
        let query = PFQuery(className:"Session")
        query.addDescendingOrder("createdAt")
        query.limit = queryLimit
        query.includeKey("user")
        
        query.findObjectsInBackground { (messagesOther, error) in
            if let error = error {
                // Log details of the failure
                print(error.localizedDescription)
            } else if let message = messagesOther {
                // The find succeeded.
                self.chatMessages = message
                print("Successfully retrieved Session Data \(message.count) posts.")
            }
            print ("reload tableView")
            self.tableView.reloadData();
            self.matchMakeOut.tintColor = UIColor.gray;
        }
    }
    
    //------------------------------ Session Confirmation Logic ------------------------------//
    
    // Confirms Session is Active
    func checkIfSessionActive(){
        print("Inside ConfirmSession")
        chatMessageField.text = "Confirming Connection"
        progViewOut.setProgress(0.8, animated: true);
        
        if (connectionEstablished == false){
            SendConfirmation();
            ListenForConfirmation();
        }
    }
    
    // Sends Confirmation
    func SendConfirmation(){
        if (sendDataCount >= sendDataDelay){
            let chatMessage = PFObject(className: "Confirm");
            
            chatMessage["text"] = "Confirm:\(userToMatchMake)"
            chatMessage["user"] = PFUser.current();
            chatMessage["current"] = postNumber;
            chatMessage["type"] = "COF";
            postNumber = postNumber + 1;
            
            chatMessage.saveInBackground { (success, error) in
                if success {
                    print("Confirmation Saved!")
                    self.sendDataCount = 1;
                } else if let error = error {
                    print("Problem saving Confirmation: \(error.localizedDescription)")
                }
            }
        }
        else{
            sendDataCount = sendDataCount + 1;
            timeoutCounter = 0;
        }
    }
    
    // Listens for Confirmation
    func ListenForConfirmation(){
        // Confirmation Logic
        print("Listen for Confirmation")
        let countOfMessages = self.chatMessages.count;
        
        for index in 0..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            let usr = (chatMessage["user"] as? PFUser)!.username;
            let msg = (chatMessage["text"] as? String)!;
            let typ = (chatMessage["type"] as? String)!;
            
            var currUser: String = "";
            currUser = PFUser.current()?.username ?? "N/A";
            // Find latest message
            if (usr == self.userToMatchMake && typ == "COF" && msg == ("Confirm:" + currUser)){
                connectionEstablished = true;
                print ("Connection Established");
                progViewOut.setProgress(0.9, animated: true);
            }
        }
    }
    
    //------------------------------ Logic for Active Connection ------------------------------//
    
    // Logic for when active connection is established
    func ActiveConnection(){
        print("In Active Connection")
        // This statement runs once.
        if (activeConnection == false){
            chatMessageField.text = ""
            
            progViewOut.setProgress(1, animated: true);
            obstructorOut.alpha = 0;
            progViewOut.setProgress(0, animated: true);
            
            SendTestMsg()
            tableView.reloadData();
            
            queryLimit = 10;
            connectionsToSkip = 3;
            //sendDataDelay = 3
        }
        timeoutCounter = 0;
        activeConnection = true;
        // Put code here that will run once connection is final
        
    }
    
    // Sends the first test message when established
    func SendTestMsg(){
        print("Inside sendTestMsg")
        let chatMessage = PFObject(className: "Session")
        chatMessage["user"] = PFUser.current();
        chatMessage["text"] = "You are now talking to \(PFUser.current()?.username ?? "")"
        chatMessage["type"] = "msg";
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    //------------------------------ Regular Chat Logic ------------------------------//
    
    // Gets Session Messages
    func getChatMessages(){
        print("Inside getChatMessages")
        let query = PFQuery(className:"Session")
        query.addDescendingOrder("createdAt")
        query.limit = queryLimit
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
        let chatMessage = PFObject(className: "Session")
        chatMessage["text"] = chatMessageField.text!
        chatMessage["user"] = PFUser.current();
        chatMessage["type"] = "msg";
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
        setStatusAsClosed()
        
        PFUser.logOutInBackground { (error) in
            if (error != nil) {
                print("Error, cannot logout: \(String(describing: error))")
            }
        }
        self.performSegue(withIdentifier: "LogoutSeg", sender: nil)
    }
    
    //------------------------------ Table View Logic ------------------------------//
    
    // Gives a chat message count based on whether two users are connected
    func getSessionMessageCount() -> Int{
        if (connectionEstablished == true){
            // Sort through to get count
            let countOfMessages = self.chatMessages.count;
            
            var newMessageCount = 0;
            
            for index in 0..<countOfMessages {
                // gets a single message
                let chatMessage = self.chatMessages[index];
                let usr = (chatMessage["user"] as? PFUser)!.username;
                
                // Find latest message
                if ((usr == self.userToMatchMake) || (usr == PFUser.current()?.username)){
                    newMessageCount = newMessageCount + 1;
                }
            }
            return newMessageCount;
        }
        return chatMessages.count;
    }
    
    // Sets Table Rows
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getSessionMessageCount();
    }
    
    // Sets Table Cell Contents
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // gets a single message
        let chatMessage = chatMessages[indexPath.row];
        let usr = (chatMessage["user"] as? PFUser)!.username;
        
        // Reusable Cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as! ChatCell;
        
        // Seperate logic to lock messages to only the two who are connected.
        if (connectionEstablished == true){
            if ((usr == self.userToMatchMake) || (usr == PFUser.current()?.username)){
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
            }
        }
            // Normal Operation
        else{
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
        }
        return cell;
    }
    
    //------------------------------ Trigger Closed Status ------------------------------//
    
    func applicationWillResignActive(_ application: UIApplication) {
        setStatusAsClosed();
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        setStatusAsClosed();
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        setStatusAsClosed();
    }
}

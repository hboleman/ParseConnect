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
    var dataStorage: [PFObject] = [];
    var usedValues: [Int] = [];
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
    var queryLimit: Int = 4;
    var connectionsToSkip: Int = 0;
    var connectionCount: Int = 0;
    var reset: Bool = false;
    var sendDataDelay: Int = 2;
    var sendDataCount: Int = 2;
    var dataPostCount: Int = 0
    var newDataIsAvailable: Bool = false;
    var ttt: Bool = false;
    var expireTime = 20.0 // Seconds
    
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
        obstructorOut.alpha = 1;
    }
    
    //------------------------------ Utility Functions ------------------------------//
    
    // Resets all values
    func resetVals(){
        print("Reset Vals")
        
        matchMakeOut.isEnabled = true;
        matchMakeOut.title = "Match Make"
        matchMakeOut.tintColor = UIColor.blue;
        
        // Disable to debug
        obstructorOut.alpha = 1;
        
        userToMatchMake = "";
        listeningForUsers = false;
        isAtemptingAck = false;
        AckLevel = 0;
        connectionEstablished = false;
        freezeData = false;
        activeConnection = false;
        queryLimit = 4;
        connectionCount = 0;
        connectionsToSkip = 0;
        progViewOut.setProgress(0, animated: false);
        sendDataCount = 2;
        dataPostCount = 0;
        newDataIsAvailable = false;
        ttt = false;
        expireTime = 20.0;
    }
    
    // Removes garbage
    func garbageCollection(){
//        if (chatMessages.count > 15){
//            for index in 0...chatMessages.count {
//                let obj = chatMessages[index]
//
//                if (isExpired(obj: obj) == true){
//
//                    obj.deleteInBackground(block: { (sucess, error) in
//                        if (sucess == true){
//                            print("GarbageDelete: TRUE")
//                        }
//                        else {
//                            //print("GarbageDelete: FALSE")
//                        }
//                    })
//                }
//            }
//        }
    }
    
    // Removed a specified object
    func garbageObj(obj: PFObject){
        if (isExpired(obj: obj) == true){

            obj.deleteInBackground(block: { (sucess, error) in
                if (sucess == true){
                    print("Delete: TRUE")
                }
                else {
                    print("Delete: FALSE")
                }
            })
        }
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
    
    // Finds if object is expired or not
    func isExpired(obj: PFObject) -> Bool {
        
        let currTime = currentTime()
        
                if ((obj["storedTime"]) == nil){
                    print("EXPIRED")
                    return true;
                }

        let storedTime = obj["storedTime"] as! Date;

        let compTime = storedTime.addingTimeInterval(expireTime)

        let result = dateComparison(date1: currTime, date2: compTime)

        if (result == 1){
            // storedTime larger than compTime
            print("EXPIRED")
            print("Curr  : \(currTime.description)")
            print("Comp  : \(compTime.description)")
            print("Stored: \(storedTime.description)")
            print("Exp   : \(expireTime)")
            print("Result :\(result)")
            return true;
        }
        else if (result == -1){
            // storedTime less than compTime
            print("NOT EXPIRED")
            print("Curr  : \(currTime.description)")
            print("Comp  : \(compTime.description)")
            print("Stored: \(storedTime.description)")
            print("Exp   : \(expireTime)")
            print("Result :\(result)")
            return false;
        }
        else if (result == 0) {
            // storedTime equals compTime
            print("EXPIRED")
            print("Curr  : \(currTime.description)")
            print("Comp  : \(compTime.description)")
            print("Stored: \(storedTime.description)")
            print("Exp   : \(expireTime)")
            print("Result :\(result)")
            return true;
        }
        else{
            print("ERROR: Date Comparison Not working! -2")
        }
        return false
    }
    
    // Date Comparison Function
    func dateComparison(date1: Date, date2: Date) -> Int {
        if date1 < date2 {
            return -1
        }
        
        if date1 > date2 {
            return 1
        }
        
        if date1 == date2 {
            return 0
        }
        return -2
    }
    
    // Returns current time
    func currentTime() -> Date {
        return Date()
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
                connectionCount = 0;
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
        // Sets getChatMessage to retrieve messages every x seconds
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.timedFunc), userInfo: nil, repeats: true)
        // runs getChatMessages for the first time
        timedFunc();
        startMatchMaking();
    }
    
    // Starts Match Making Process
    func startMatchMaking(){
        print("Start MatchMaking")
        //chatMessageField.text = "Start MatchMaking"
        getMatchParseData();
        garbageCollection();
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
            chatMessage["storedTime"] = currentTime();
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
            print("Set Status to Closed")
            chatMessageField.text = "Set Status as Closed"
            
            let chatMessage = PFObject(className: "MatchMake");
            //chatMessageField.text = "STATUS OPEN";
            chatMessage["text"] = "STATUS:CLOSED"
            chatMessage["user"] = PFUser.current();
            chatMessage["current"] = postNumber;
            chatMessage["type"] = "STATUS";
            chatMessage["storedTime"] = currentTime();
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
            //let STime = (chatMessage["storedTime"] as? Date)!;
            
            if (msg == "STATUS:OPEN" && usr != PFUser.current()?.username && typ == "STATUS" && isExpired(obj: chatMessage) == false){
                print ("STATUS IS CONFIRMED OPEN");
                print ("OPEN: \(String(describing: usr))");
                self.userToMatchMake = usr!;
                return true;
            }
            else if (isExpired(obj: chatMessage) == true){
                //print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
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
            //let STime = (chatMessage["storedTime"] as? Date)!;
            // Find latest message
            if (usr == self.userToMatchMake && curr > mostRecentMsg && typ == "STATUS" && isExpired(obj: chatMessage) == false){
                mostRecentMsg = curr;
                print ("Most recent message found is: \(curr)");
            }
            else if (isExpired(obj: chatMessage) == true){
                print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
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
            //let STime = (chatMessage["storedTime"] as? Date)!;
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && curr == mostRecentMsg && typ == "STATUS" && isExpired(obj: chatMessage) == false){
                if (msg == "STATUS:OPEN"){
                    print ("FOUND: OPEN AND RECENT")
                    return true;
                }
                else {
                    print ("REJECT: OPEN BUT NOT RECENT")
                    return false;
                }
            }
            else if (isExpired(obj: chatMessage) == true){
                print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
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
            chatMessage["storedTime"] = currentTime();
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
            //let STime = (chatMessage["storedTime"] as? Date)!;
            
            var currUser: String = "";
            currUser = PFUser.current()?.username ?? "N/A";
            
            // Finds most recent message based on work above
            if (usr == self.userToMatchMake && typ == "ACK" && isExpired(obj: chatMessage) == false){
                print(("Test Listen Ack" + currUser))
                // If second ack is found
                if(msg == ("SecondAck:" + currUser)){
                    print ("Second Ack Found!")
                    chatMessageField.text = "ACK: 2"
                    AckLevel = 2;
                    progViewOut.setProgress(0.7, animated: true);
                    //setStatusAsClosed();
                }
                    // If first ack is found
                else if (msg == ("FirstAck:" + currUser)){
                    print ("First Ack Found!")
                    chatMessageField.text = "ACK: 1"
                    AckLevel = 1;
                    progViewOut.setProgress(0.6, animated: true);
                }
                else {
                    
                }
            }
            else if (isExpired(obj: chatMessage) == true){
                print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
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
            self.garbageCollection();
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
            self.garbageCollection();
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
            self.garbageCollection();
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
            chatMessage["storedTime"] = currentTime()
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
            //let STime = (chatMessage["storedTime"] as? Date)!;
            
            var currUser: String = "";
            currUser = PFUser.current()?.username ?? "N/A";
            // Find latest message
            if (usr == self.userToMatchMake && typ == "COF" && msg == ("Confirm:" + currUser) && isExpired(obj: chatMessage) == false){
                connectionEstablished = true;
                print ("Connection Established");
                progViewOut.setProgress(0.9, animated: true);
            }
            else if (isExpired(obj: chatMessage) == true){
                print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
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
            
            expireTime = 60.0
            queryLimit = 30;
            connectionsToSkip = 6;
            //sendDataDelay = 3
        }
        timeoutCounter = 0;
        activeConnection = true;
        // Put code here that will run once connection is final
        if (newDataIsAvailable == true){
            ParseData();
        }
        if (ttt == true){
            ticTacToeCore();
        }
    }
    
    // Sends the first test message when established
    func SendTestMsg(){
        print("Inside sendTestMsg")
        let chatMessage = PFObject(className: "Session")
        chatMessage["user"] = PFUser.current();
        chatMessage["text"] = "You are now talking to \(PFUser.current()?.username ?? "")"
        chatMessage["type"] = "msg";
        chatMessage["storedTime"] = currentTime()
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    //------------------------------ Arbritrary Data Logic ------------------------------//
    
    func WillHandleMsgBeforeFlight(str: String) -> Bool{
        if (str == "menu"){
            chatMessageField.text = "";
            SendMsg(str: "Menu\n\n-tictactoe")
        }
            
        else if (str == "tictactoe"){
            chatMessageField.text = "";
            ttt = true;
            
            return true;
        }
            
        else if (isMyTurn() == true && ttt == true){
            chatMessageField.text = "";
            ticTacToeCaptureUserInput(str: (str + myPiece));
            return true;
        }
        else if(str == "update"){
            ticTacToeDrawBoard();
            return true
        }
        
        return false;
    }
    
    func SendMsg(str: String){
        print("Inside sendMsg")
        let chatMessage = PFObject(className: "Session")
        chatMessage["user"] = PFUser.current();
        chatMessage["text"] = ("Computer:\n" + str);
        chatMessage["type"] = "msg";
        chatMessage["storedTime"] = currentTime()
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("The message was saved!")
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    // Will run when new data found.
    func ParseData(){
        while(dataStorage.isEmpty == false){
            let obj = dataStorage.removeFirst()
            
            let usr = (obj["user"] as? PFUser)!.username;
            //            let msg = (obj["text"] as? String)!;
            //            let typ = (obj["type"] as? String)!;
            //            let cur = (obj["current"] as? Int)!;
            //            let dat2 = (obj["otherDat"] as? String)!;
            //            let STime = (obj["storedTime"] as? Date)!;
            let typ2 = (obj["type2"] as? String)!;
            
            if (usr == userToMatchMake){
                if (typ2 == "TicTacToe"){
                    if (ttt == false){
                        ttt = true;
                        myPiece = "O";
                        print("TTT: Relized is second player: O")
                    }
                }
            }
        }
    }
    
    // Sends arbitrary data
    func SendData(text: String, otherDat: String, type2: String){
        print("Inside send data")
        let chatMessage = PFObject(className: "Session")
        chatMessage["user"] = PFUser.current();
        chatMessage["text"] = text;
        chatMessage["type"] = "DAT";
        chatMessage["current"] = dataPostCount;
        chatMessage["otherDat"] = otherDat;
        chatMessage["type2"] = type2;
        chatMessage["storedTime"] = currentTime()
        
        chatMessage.saveInBackground { (success, error) in
            if success {
                print("Data was saved!")
                self.dataPostCount = self.dataPostCount + 1;
                //self.chatMessageField.text = "";
            } else if let error = error {
                print("Problem saving message: \(error.localizedDescription)")
            }
        }
    }
    
    // Looks through chat messages for data, then grabs data if available
    func LookForData(){
        //print("Looking for data")
        let countOfMessages = self.chatMessages.count;
        
        for index in 0..<countOfMessages {
            // gets a single message
            let chatMessage = self.chatMessages[index];
            //let usr = (chatMessage["user"] as? PFUser)!.username;
            //let msg = (chatMessage["text"] as? String)!;
            let typ = (chatMessage["type"] as? String)!;
            //let cur = (chatMessage["current"] as? Int)!;
            
            //var currUser: String = "";
            //currUser = PFUser.current()?.username ?? "N/A";
            // Find latest message
            if (typ == "DAT" && isNewData(obj: chatMessage) && isExpired(obj: chatMessage) == false){
                print("found new data");
                newDataIsAvailable = true;
            }
            else if (isExpired(obj: chatMessage) == true){
                print("Any User Open: isExpired")
                garbageObj(obj: chatMessage);
            }
        }
    }
    
    // Finds if data seen in the stream is new data
    func isNewData(obj: PFObject) -> Bool {
        let usr = (obj["user"] as? PFUser)!.username;
        let msg = (obj["text"] as? String)!;
        let typ = (obj["type"] as? String)!;
        let cur = (obj["current"] as? Int)!;
        //let STime = (obj["storedTime"] as? Date)!;
        
        var isFound: Bool = false;
        
        for index in 0..<dataStorage.count{
            let usr_i = (dataStorage[index]["user"] as? PFUser)!.username;
            let msg_i = (dataStorage[index]["text"] as? String)!;
            let typ_i = (dataStorage[index]["type"] as? String)!;
            let cur_i = (dataStorage[index]["current"] as? Int)!;
            //let STime_i = (dataStorage[index]["storedTime"] as? Date)!;
            if (usr == usr_i && msg == msg_i && typ == typ_i && cur == cur_i){
                isFound = true;
            }
            else {
                // If not found, add to data storage
                dataStorage.append(obj);
            }
        }
        return isFound;
    }
    
    //------------------------------ Tic Tac Toe ------------------------------//
    
    // Tic Tac Toe Data
    var tttArr = [["-","-","-"],["-","-","-"],["-","-","-"]]
    var turn: Int = 0;
    var msg: String = "";
    var myPiece: String = "";
    var fullBoard: String = "";
    
    func ticTacToeInput(row: Int, col: Int, piece: String){
        // Ex:T&2&X&123
        // [row][col]
        //   1 2 3
        // 1 X X X
        // 2 X X X
        // 3 X X X
        //        var inputArr = str.split(separator: "&");
        //        print("INPUT ARR: " + inputArr[0] + inputArr[1] + inputArr[2] + inputArr[3])
        //        let row = Int(inputArr[0])!;
        //        let col = Int(inputArr[1])!;
        //        let piece = String(inputArr[2]);
        //        turn = Int(String(inputArr[3]))!;
        let row = row
        let col = col
        turn = turn + 1;
        
        tttArr[(row - 1)][(col - 1)] = String(piece);
        SendMsg(str: "Board Input Updated")
        ticTacToeDrawBoard()
    }
    
    func ticTacToeCore(){
        if (turn == 0){
            SendData(text: "Welcome to Tic Tac Toe!\nPlayer: \(String(PFUser.current()!.username!))\nWill Go First!", otherDat: "TicTacToe:::X-" + (PFUser.current()!.username!) + ":::O-" + userToMatchMake, type2: "TicTacToe");
            myPiece = "X";
            //playTurn();
        }
        if (isMyTurn() == true || turn == 0){
            playTurn()
        }
        else {
            
        }
    }
    
    func playTurn(){
        msg = "Selection Ex: 'M3' for middle 3.\n"
        ticTacToeDrawBoard()
        //let usrName = PFUser.current()?.username!
    }
    
    func isMyTurn() -> Bool {
        var PlayerXCount: Int = 0;
        var PlayerOCount: Int = 0;
        
        for index in 0...2{
            for index2 in 0...2{
                if (String(tttArr[index][index2]) == "X"){
                    PlayerXCount = PlayerXCount + 1;
                }
                if (String(tttArr[index][index2]) == "O"){
                    PlayerOCount = PlayerOCount + 1;
                }
            }
        }
        
        if (myPiece == "X" && turn < 1){
            return true;
        }
        else if (myPiece == "X"){
            // If equal
            if(PlayerXCount == PlayerOCount){
                return true;
            }
                // If X one ahead
            else if (PlayerXCount > PlayerOCount && (PlayerXCount - PlayerOCount) <= 1){
                return false;
            }
            else {
                return true;
            }
        }
        else if (myPiece == "O"){
            // If equal
            if(PlayerXCount == PlayerOCount){
                return false;
            }
                // If X one ahead
            else if (PlayerXCount > PlayerOCount && (PlayerXCount - PlayerOCount) <= 1){
                return true;
            }
            else {
                return false;
            }
        }
        return false;
    }
    
    func ticTacToeCaptureUserInput(str: String){
        var row: Int = 0;
        var col: Int = 0;
        // Ex:T&2&X&123
        // [row][col]
        //   1 2 3
        // 1 X X X
        // 2 X X X
        // 3 X X X
        if(str.count == 3 && isMyTurn() == true){
            row = charToInt(char: String(str.character(at: 0)!))
            col = charToInt(char: String(str.character(at: 1)!))
            
            let piece = String(str.character(at: 2)!)
            //            row = Int(String(strMod.removeFirst()))!
            //            col = Int(String(strMod.removeFirst()))!
            //            let piece = String(strMod.removeFirst())
            ticTacToeInput(row: row, col: col, piece: piece)
        }
    }
    
    func charToInt(char: String) -> Int {
        if (char == "T"){
            return 1;
        }
        if (char == "M"){
            return 2;
        }
        if (char == "B"){
            return 3;
        }
        if (char == "0"){
            return 0;
        }
        if (char == "1"){
            return 1;
        }
        if (char == "2"){
            return 2;
        }
        if (char == "3"){
            return 3;
        }
        if (char == "4"){
            return 4;
        }
        if (char == "5"){
            return 5;
        }
        if (char == "6"){
            return 6;
        }
        if (char == "7"){
            return 7;
        }
        if (char == "8"){
            return 8;
        }
        if (char == "9"){
            return 9;
        }
        return -1
    }
    
    func ticTacToeDrawBoard(){
        fullBoard = "";
        var turnSel = "";
        if (isMyTurn() == true){
            let usrName = PFUser.current()?.username
            turnSel = usrName ?? "";
        }
        else {
            let usrName = userToMatchMake
            turnSel = usrName
        }
        let whosTurn = ("Turn: " + turnSel)
        let overhead = "  1 2 3"
        let top = String("T " + tttArr[0][0] + " " + tttArr[0][1] + " " + tttArr[0][2]);
        let mid = String("M " + tttArr[1][0] + " " + tttArr[1][1] + " " + tttArr[1][2]);
        let btm = String("B " + tttArr[2][0] + " " + tttArr[2][1] + " " + tttArr[2][2]);
        fullBoard = (msg + "\n" + whosTurn + "\n" + overhead + "\n" + top + "\n" + mid + "\n" + btm);
        SendMsg(str: fullBoard)
        msg = ""
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
        
        if (WillHandleMsgBeforeFlight(str: chatMessageField.text!) == false) {
            
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
        // Parses any new data to data storage.
        LookForData()
        
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

//------------------------------ String Extension ------------------------------//

extension String {
    
    func index(at position: Int, from start: Index? = nil) -> Index? {
        let startingIndex = start ?? startIndex
        return index(startingIndex, offsetBy: position, limitedBy: endIndex)
    }
    
    func character(at position: Int) -> Character? {
        guard position >= 0, let indexPosition = index(at: position) else {
            return nil
        }
        return self[indexPosition]
    }
}

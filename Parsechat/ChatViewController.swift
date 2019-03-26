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
    @IBOutlet weak var ProtoCell: ChatCell!
    @IBOutlet weak var tableViewOut: UITableView!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.onTimer), userInfo: nil, repeats: true)

        
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5;
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChatCell") as! ChatCell;
        
        
        return cell;
    }
    
    @objc func onTimer() {
        // Add code to be run periodically
        // Do any additional setup after loading the view.
        // construct query
        //let query = Post.query()
        let query = PFQuery(className:"Messages")
        query.whereKey("likesCount", greaterThan: 100)
        query.limit = 20
        
        //let query = PFQuery(className:"GameScore")
        //query.whereKey("playerName", equalTo:"Sean Plott")
        query.findObjectsInBackground { (objects: [PFObject]?, error: Error?) in
            if let error = error {
                // Log details of the failure
                print(error.localizedDescription)
            } else if let objects = objects {
                // The find succeeded.
                print("Successfully retrieved \(objects.count) scores.")
                // Do something with the found objects
                for object in objects {
                    print(object.objectId as Any)
                    query.addDescendingOrder("createdAt")
                }
            }
        }
        
        self.tableViewOut.reloadData();
        
        /*// fetch data asynchronously
         query.findObjectsInBackground { (posts: [Post]?, error: Error?) in
         if let posts = posts {
         // do something with the array of object returned by the call
         } else {
         print(error?.localizedDescription)
         }
         }
         */
    }

}

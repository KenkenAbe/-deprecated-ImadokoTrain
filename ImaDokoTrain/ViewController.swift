//
//  ViewController.swift
//  ImaDokoTrain
//
//  Created by KentaroAbe on 2017/10/24.
//  Copyright © 2017年 KentaroAbe. All rights reserved.
//

import UIKit
import WebKit
import SwiftyJSON
import Alamofire
import Kanna
import ChameleonFramework
import RealmSwift

extension UIImage { //指定したCGSizeとUIColorのUIImageを作成するExtension
    
    static func image(color: UIColor, size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
extension UIColor { //HTMLカラーコードからUIColorを作成するExtension
    convenience init(hex: String, alpha: CGFloat) {
        if hex.characters.count == 6 {
            let rawValue: Int = Int(hex, radix: 16) ?? 0
            let B255: Int = rawValue % 256
            let G255: Int = ((rawValue - B255) / 256) % 256
            let R255: Int = ((rawValue - B255) / 256 - G255) / 256
            
            self.init(red: CGFloat(R255) / 255,
                      green: CGFloat(G255) / 255,
                      blue: CGFloat(B255) / 255,
                      alpha: alpha)
        } else {
            self.init(red: 0, green: 0, blue: 0, alpha: alpha)
        }
    }
    convenience init(hex: String) {
        self.init(hex: hex, alpha: 1.0)
    }
}

class ViewController: UIViewController,UITableViewDelegate,UITableViewDataSource {
    
    @IBOutlet var Bar: UINavigationBar!
    
    var refreshControl:UIRefreshControl!
    
    @objc func refreshControlValueChanged(sender: UIRefreshControl) {
        print("テーブルを下に引っ張った時に呼ばれる")
        print("再読込を行います")
        lineName = [String]()
        let database = try! Realm()
        let data = database.objects(LineData.self)
        let url = "https://dc.akbart.net/imadokotrain/linedata/line.json"
        var keepAlive = true
        Alamofire.request(url).responseJSON{response in
            if response.result.value != nil{
                try! database.write{
                    database.deleteAll()
                }
                let json = JSON(response.result.value)
                //print(json)
                for i in 0...json["line"].count-1{
                    let basedata = LineData()
                    basedata.dataID = i
                    basedata.OperatorName = String(describing:json["line"][String(describing:i)]["company"])
                    basedata.lineID = Int(String(describing:json["line"][String(describing:i)]["LineID"]))!
                    basedata.lineName = String(describing:json["line"][String(describing:i)]["Name"])
                    basedata.lineColor = String(describing:json["line"][String(describing:i)]["Color"])
                    if (Bool(String(describing:json["line"][String(describing:i)]["unique"]))) == true{
                        basedata.isUnique = true
                        basedata.type = String(describing:json["line"][String(describing:i)]["dataType"])
                        basedata.dataURL = String(describing:json["line"][String(describing:i)]["dataURL"])
                    }else{
                        basedata.isUnique = false
                    }
                    
                    if (Bool(String(describing:json["line"][String(describing:i)]["LimitedEXP"]))) == true{
                        basedata.isLtdEXP = true
                    }else{
                        basedata.isLtdEXP = false
                    }
                    try! database.write {
                        database.add(basedata)
                    }
                }
                keepAlive = false
                
            }else{
                
            }
            
        }
        let runLoop = RunLoop.current
        while keepAlive &&
            runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                // 0.1秒毎の処理なので、処理が止まらない
        }
        print(data)
        for i in 0...data.count-1{
            print(data[i].lineName)
            lineName.append(data[i].lineName)
        }
        print(lineName)

        self.LineView.reloadData()
        
        sender.endRefreshing()
    }
    
    let ap = UIApplication.shared.delegate as! AppDelegate
    
    var lineName = [String]()
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let database = try! Realm()
        let data = database.objects(LineData.self)
        
        return data.count
    }
    
    @IBOutlet var LineView: UITableView!
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCell") as! TableViewCell
        
        let database = try! Realm()
        let data = database.objects(LineData.self)
        
        cell.LineName?.text? = data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineName //路線名
        
        if data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].isLtdEXP == true{ //新幹線・特急の場合は遅れ時分を表示しない
            cell.DelayTime?.text? = "この路線は遅れ情報を提供していません"
        }else{ //在来線の場合は遅れ時分を表示する
            let url = "https://rp.cloudrail.jp/tw02/jreast_app/as/existLine/list"
            Alamofire.request(url).responseJSON{response in
                let json = JSON(response.result.value)
                print(json)
                cell.DelayTime?.text? = "最大遅れ時分：\(String(describing:json["maxDelayInfos"][String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID)]["maxDelay"]))分"
                
                if Int(String(describing:json["maxDelayInfos"][String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID)]["maxDelay"]))! > 0{
                    cell.DelayTime?.textColor = UIColor.red
                }else{ //遅れがない場合（最大遅れ時分が0の場合）は遅れがないことを表示する
                    cell.DelayTime?.text? = "現在遅れはありません"
                    cell.DelayTime?.textColor = UIColor.black
                }
            }
        }
        
        
        
        if data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].isLtdEXP == true{ //新幹線・特急の場合は新幹線のロゴを画像として表示する
            cell.LineImage.image = UIImage(named:"TohokuShinkansen.jpg")
        }else{ //在来線の場合は路線カラーで塗りつぶした画像を作成して表示する
            let color = UIColor(hex:String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineColor),alpha:1.0)
            let size = CGSize(width: 60, height: 60)
            let colorImage = UIImage.image(color: color, size: size)
            cell.LineImage.image = colorImage
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100.0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 90.0
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { //セルの内容がタップされた時の処理（データの変更画面）
        self.LineView.deselectRow(at: indexPath, animated: true)
        let database = try! Realm()
        let data = database.objects(LineData.self).sorted(byKeyPath: "dataID", ascending: true)
        self.ap.lineID = data[indexPath.row].lineID
        
        let storyboard: UIStoryboard = self.storyboard!
        let nextView = storyboard.instantiateViewController(withIdentifier: "TrainView") as! TrainController //画面遷移
        self.present(nextView, animated: true, completion: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let database = try! Realm()
        let data = database.objects(LineData.self)
        let url = "https://dc.akbart.net/imadokotrain/linedata/line.json"
        var keepAlive = true
        Alamofire.request(url).responseJSON{response in
            if response.result.value != nil{
                try! database.write{
                    database.deleteAll()
                }
                let json = JSON(response.result.value)
                //print(json)
                for i in 0...json["line"].count-1{
                    let basedata = LineData()
                    basedata.dataID = i
                    basedata.OperatorName = String(describing:json["line"][String(describing:i)]["company"])
                    basedata.lineID = Int(String(describing:json["line"][String(describing:i)]["LineID"]))!
                    basedata.lineName = String(describing:json["line"][String(describing:i)]["Name"])
                    basedata.lineColor = String(describing:json["line"][String(describing:i)]["Color"])
                    if (Bool(String(describing:json["line"][String(describing:i)]["unique"]))) == true{
                        basedata.isUnique = true
                        basedata.type = String(describing:json["line"][String(describing:i)]["dataType"])
                        basedata.dataURL = String(describing:json["line"][String(describing:i)]["dataURL"])
                    }else{
                        basedata.isUnique = false
                    }
                    
                    if (Bool(String(describing:json["line"][String(describing:i)]["LimitedEXP"]))) == true{
                        basedata.isLtdEXP = true
                    }else{
                        basedata.isLtdEXP = false
                    }
                    try! database.write {
                        database.add(basedata)
                    }
                }
                keepAlive = false
                
            }else{
                
            }
            
        }
        let runLoop = RunLoop.current
        while keepAlive &&
            runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                // 0.1秒毎の処理なので、処理が止まらない
        }
        print(data)
        for i in 0...data.count-1{
            print(data[i].lineName)
            lineName.append(data[i].lineName)
        }
        print(lineName)
        
        self.LineView.rowHeight = 90
        self.LineView.estimatedRowHeight = 90
        self.LineView.delegate = self
        self.LineView.dataSource = self
        let statusBar = UIView(frame:CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.size.width, height: 20.0)) //ステータスバーの位置にUINavigationBarと同じ色を配置する
        statusBar.backgroundColor = UIColor.flatGreenDark
        self.Bar.backgroundColor = UIColor.flatGreenDark
        
        self.Bar.removeFromSuperview()
        view.addSubview(self.Bar)
        view.addSubview(statusBar)
        
        self.refreshControl = UIRefreshControl() //上から下に引っ張ってできる動作を作成
        self.refreshControl.attributedTitle = NSAttributedString(string: "引っ張って更新")
        refreshControl.addTarget(self, action: #selector(self.refreshControlValueChanged(sender:)), for: .valueChanged)
        self.LineView.addSubview(refreshControl)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func JsonGet(fileName :String) -> JSON {
        let path = Bundle.main.path(forResource: fileName, ofType: "json")
        print(path)
        
        do{
            let jsonStr = try String(contentsOfFile: path!)
            //print(jsonStr)
            
            let json = JSON.parse(jsonStr)
            
            return json
        } catch {
            return nil
        }
        
    }
    
    @IBAction func goBack(_ segue:UIStoryboardSegue) {}
    
}

class TrainController:UIViewController,WKUIDelegate{
    
    @IBOutlet var Web: WKWebView!
    let ap = UIApplication.shared.delegate as! AppDelegate
    var ActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet var Bar: UINavigationBar!
    
    override func viewDidLoad(){
        super.viewDidLoad()
        let statusBar = UIView(frame:CGRect(x: 0.0, y: 0.0, width: UIScreen.main.bounds.size.width, height: 20.0)) //ステータスバーの位置にUINavigationBarと同じ色を配置する
        
        statusBar.backgroundColor = UIColor.flatGreenDark
        self.Bar.backgroundColor = UIColor.flatGreenDark
        
        self.Bar.removeFromSuperview()
        view.addSubview(self.Bar)
        view.addSubview(statusBar)

        ActivityIndicator = UIActivityIndicatorView()
        ActivityIndicator.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        ActivityIndicator.center = self.view.center
        
        // クルクルをストップした時に非表示する
        ActivityIndicator.hidesWhenStopped = true
        
        // 色を設定
        ActivityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        
        //Viewに追加
        self.view.addSubview(ActivityIndicator)
        
        webView(lineID: self.ap.lineID)
    }
    
    @IBAction func Close(_ sender: Any) {
        let storyboard: UIStoryboard = self.storyboard!
        let nextView = storyboard.instantiateViewController(withIdentifier: "TrainView") as! TrainController //画面遷移
        self.present(nextView, animated: true, completion: nil)
    }
    
    @IBAction func renew(_ sender: Any) {
        webView(lineID: self.ap.lineID)
    }
    
    func webView(lineID:Int){
        self.Web.uiDelegate = self
        //self.Web = WKWebView()
        ActivityIndicator.startAnimating()
        var url = URL(string:"https://rp.cloudrail.jp/rp/zw01/line_\(String(describing:lineID)).html?at=0000&atLink=0000&lineCode=\(String(describing:lineID))")
        var req = URLRequest(url:url!)
        var HTMLRAW:Data?
        let headers:HTTPHeaders = ["User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/603.1.30 (KHTML, like Gecko) Version/10.3 Mobile/14E277 Safari/603.1.30"]
        
        Alamofire.request(url!, method: .get, headers: headers).responseData{ response in
            //print(response)
            HTMLRAW = response.result.value
            print(HTMLRAW)
            var encodevalue = String(data: HTMLRAW!, encoding: String.Encoding.utf8)
            
            print(encodevalue)
            let doc = try! HTML(html: encodevalue!, encoding: String.Encoding.utf8)
            self.ActivityIndicator.stopAnimating()
        }
        self.Web.load(req)
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func JsonGet(fileName :String) -> JSON {
        let path = Bundle.main.path(forResource: fileName, ofType: "json")
        print(path)
        
        do{
            let jsonStr = try String(contentsOfFile: path!)
            print(jsonStr)
            
            let json = JSON.parse(jsonStr)
            
            return json
        } catch {
            return nil
        }
        
    }
}

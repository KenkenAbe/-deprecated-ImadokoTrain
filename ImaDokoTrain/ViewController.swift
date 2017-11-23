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
    
    let TokyuTY_URL = URL(string: "https://tokyu-tid.s3.amazonaws.com/toyoko.json")
    let TokyuDT_URL = URL(string: "https://tokyu-tid.s3.amazonaws.com/dento.json")
    let TokyuMG_URL = URL(string: "https://tokyu-tid.s3.amazonaws.com/meguro.json")
    let TokyuOM_URL = URL(string: "https://tokyu-tid.s3.amazonaws.com/oimachi.json")
    let TokyoMetro_AccessToken = "5f95c806e61e454551b8cb6688a49dbd4b187b8c042bdf9d61c0fd1983a88091"
    
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
                    if Int(String(describing:json["line"][String(describing:i)]["LineID"]))! >= 10000{
                        basedata.lineCode = String(describing:json["line"][String(describing:i)]["LineCode"])
                    }
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
        
        switch data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].OperatorName{
        case "JRE":
            cell.LineName?.text? = "JR \(data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineName)"
        case "TokyoMetro":
            cell.LineName?.text? = "地下鉄 \(data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineName)"
        default:
            cell.LineName?.text? = "不明"
        }
         //路線名
        
        if data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].isLtdEXP == true{ //新幹線・特急の場合は遅れ時分を表示しない
            cell.DelayTime?.text? = "この路線は遅れ情報を提供していません"
        }else{ //在来線の場合は遅れ時分を表示する
            let url = "https://rp.cloudrail.jp/tw02/jreast_app/as/existLine/list"
            Alamofire.request(url).responseJSON{response in
                let json = JSON(response.result.value)
                print(json)
                cell.DelayTime?.text? = "最大遅れ時分：\(String(describing:json["maxDelayInfos"][String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID)]["maxDelay"]))分"
                if data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID >= 10000{ //私鉄の場合は遅れ時分を表示しない
                    cell.DelayTime?.text? = "この路線は遅れ情報を提供していません"
                }else{
                    if json["maxDelayInfos"][String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID)]["maxDelay"] != nil{
                        if Int(String(describing:json["maxDelayInfos"][String(describing:data.sorted(byKeyPath: "dataID", ascending: true)[indexPath.row].lineID)]["maxDelay"]))! > 0{
                            cell.DelayTime?.textColor = UIColor.red
                        }else{ //遅れがない場合（最大遅れ時分が0の場合）は遅れがないことを表示する
                            cell.DelayTime?.text? = "現在遅れはありません"
                            cell.DelayTime?.textColor = UIColor.black
                        }
                    }else{
                        cell.DelayTime?.text? = "遅れ情報を取得できませんでした"
                        cell.DelayTime?.textColor = UIColor.black
                    }
                    
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
        if self.ap.lineID >= 10000{ //私鉄の場合はlineCodeも引き渡し
            self.ap.lineCode = data[indexPath.row].lineCode
        }
        self.ap.lineColor = data[indexPath.row].lineColor
        let storyboard: UIStoryboard = self.storyboard!
        if self.ap.lineID < 10000{ //JRの場合はWebKitを備えた画面に遷移
            let nextView = storyboard.instantiateViewController(withIdentifier: "TrainView") as! TrainController //画面遷移
            self.present(nextView, animated: true, completion: nil)
        }else{ //私鉄の場合は独自UIを生成するため、別画面に遷移
            let nextView = storyboard.instantiateViewController(withIdentifier: "OtherRailway") as! otherRailwayViewController //画面遷移
            self.present(nextView, animated: true, completion: nil)
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let database = try! Realm()
        let data = database.objects(LineData.self)
        let url = "https://dc.akbart.net/imadokotrain/linedata/line.json"
        var keepAlive = true
        let metroURL = URL(string: "https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Station&acl:consumerKey=5f95c806e61e454551b8cb6688a49dbd4b187b8c042bdf9d61c0fd1983a88091") //東京メトロの駅データ
        Alamofire.request(metroURL!).responseJSON{response in
            if response.result.value != nil{
                self.ap.TokyoMetroStationData = JSON(response.result.value)
                //print(self.ap.TokyoMetroStationData)
            }
        }
        
        Alamofire.request(url).responseJSON{response in
            if response.result.value != nil{
                try! database.write{
                    database.deleteAll()
                }
                let json = JSON(response.result.value)
                print(json)
                for i in 0...json["line"].count-1{
                    let basedata = LineData()
                    basedata.dataID = i
                    basedata.OperatorName = String(describing:json["line"][String(describing:i)]["company"])
                    basedata.lineID = Int(String(describing:json["line"][String(describing:i)]["LineID"]))!
                    if Int(String(describing:json["line"][String(describing:i)]["LineID"]))! >= 10000{
                        basedata.lineCode = String(describing:json["line"][String(describing:i)]["LineCode"])
                    }
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
        if self.ap.lineID >= 10000{
            
        }else{
            webView(lineID: self.ap.lineID)
        }
    }
    
    @IBAction func Close(_ sender: Any) {
        let storyboard: UIStoryboard = self.storyboard!
        let nextView = storyboard.instantiateViewController(withIdentifier: "TrainView") as! TrainController //画面遷移
        self.present(nextView, animated: true, completion: nil)
    }
    
    @IBAction func renew(_ sender: Any) {
        if self.ap.lineID >= 10000{
            
        }else{
            webView(lineID: self.ap.lineID)
        }
    }
    
    func MetroLineView(lineCode:String){
        
    }
    
    func webView(lineID:Int){ //JR線の場合の路線情報更新
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

class otherRailwayViewController:UIViewController,UIScrollViewDelegate{
    
    @IBOutlet var mainView: UIScrollView!
    
    @IBOutlet var Bar: UINavigationBar!
    
    
    @IBAction func renew(_ sender: Any) {
        trainView()
    }
    
    
    let ap = UIApplication.shared.delegate as! AppDelegate
    var lineCode = "" //
    var NetworkOperator = ""
    var mainViewWidth = CGFloat(0.0)
    var mainViewHeight = CGFloat(0.0)
    let TokyoMetro_AccessToken = "5f95c806e61e454551b8cb6688a49dbd4b187b8c042bdf9d61c0fd1983a88091" //アクセストークン（東京メトロの場合のみ使用）
    
    override func viewDidLoad(){
        super.viewDidLoad()
        
        lineCode = self.ap.lineCode
        let database = try! Realm()
        let data = database.objects(LineData.self).sorted(byKeyPath: "lineID", ascending: true)
        
        for i in 0...data.count-1{
            if data[i].lineCode != ""{
                if data[i].lineCode == self.lineCode{
                    self.NetworkOperator = data[i].OperatorName
                }
            }
        }
        trainView()
        mainView.delegate = self
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func trainView() {
        let viewes = self.mainView.subviews
        for viewes in viewes {
            viewes.removeFromSuperview()
        }
        self.mainViewWidth = self.mainView.frame.width
        self.mainViewHeight = self.mainView.frame.height
        let database = try! Realm()
        var trainPositionData:JSON? = nil
        var keepAlive = true
        
        switch NetworkOperator{
        case "TokyoMetro":
            let url = URL(string:"https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Train&odpt:railway=\(self.lineCode)&acl:consumerKey=\(self.TokyoMetro_AccessToken)")
            Alamofire.request(url!).responseJSON{response in
                
                let database = try! Realm()
                let url = URL(string:"https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Station&odpt:railway=\(self.lineCode)&acl:consumerKey=5f95c806e61e454551b8cb6688a49dbd4b187b8c042bdf9d61c0fd1983a88091")
                Alamofire.request(url!).responseJSON{response in
                    let response = JSON(response.result.value)
                    //print(response)
                    print("路線の駅データ：\(response[].count)件")
                    if database.objects(stationData.self).filter("lineCode == %@",self.lineCode).count >= 1{
                        for i in 0...database.objects(stationData.self).filter("lineCode == %@",self.lineCode).count-1{
                            try! Realm().write {
                                database.delete(database.objects(stationData.self).filter("lineCode == %@",self.lineCode).first!)
                            }
                        }
                    }
                    
                    let lineNum = response[].count-1
                    for j in 0...lineNum{
                        let obj = stationData()
                        obj.lineCode = self.lineCode
                        obj.stationName = String(describing:response[j]["dc:title"])
                        obj.stationCode = String(describing:response[j]["owl:sameAs"])
                        obj.operatorName = "TokyoMetro"
                        var stationCode = String(describing:response[j]["odpt:stationCode"])
                        stationCode.remove(at: stationCode.startIndex)
                        print(stationCode)
                        obj.stationID = Int(stationCode)!
                        obj.stationColor = ""
                        
                        try! Realm().write {
                            database.add(obj)
                        }
                    }
                    keepAlive = false
                }
                
                
            }
        default:
            break
        }
        
        
        let runLoop = RunLoop.current
        while keepAlive &&
            runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                // 0.1秒毎の処理なので、処理が止まらない
        }
        let data = database.objects(stationData.self).filter("lineCode == %@",self.lineCode).sorted(byKeyPath: "stationID", ascending: true)
        print(data)
        var currentHeight = CGFloat(0.0)
        for i in 0...data.count-1{
            print(data[i].stationName)
            print(data[i].stationCode)
            let current = StationView(stationName: data[i].stationName, currentHeight: currentHeight)
            currentHeight += CGFloat(50)
            if i != data.count{
                let bothCurrent = bothStationView(stationName: data[i].stationName, currentHeight: currentHeight)
                currentHeight += CGFloat(50)
            }
        }
        
        self.mainView.frame.size = CGSize(width: self.mainViewWidth, height: CGFloat(50*data.count)*2)
        self.mainView.contentSize = CGSize(width: self.mainViewWidth, height: CGFloat(50*data.count)*2)
        self.mainView.bounces = true
        self.mainView.indicatorStyle = .black
        self.view.addSubview(self.mainView)
        let alert = UIAlertController(title: "少々お待ちください", message: "", preferredStyle: .alert)
        self.present(alert,animated:true)
        /*GetTrainPos_Up()
        GetTrainPos_Down()*/
        GetTrain()
        alert.dismiss(animated: true, completion: nil)
    }
    
    func StationView(stationName:String,currentHeight:CGFloat) -> CGFloat{
        let lineColor = self.ap.lineColor
        let color = UIColor(hex:lineColor,alpha:1.0)
        let size = CGSize(width: 10, height: 50)
        let colorImage = UIImage.image(color: color, size: size)
        var frame:CGRect = CGRect(x: (self.mainViewWidth/3)*2, y:currentHeight, width: 10, height: 50)
        var image = UIImageView(frame: frame)
        var textFrame:CGRect = CGRect(x: 10, y: currentHeight+10, width: 200, height: 50)
        var str = UITextView(frame:textFrame)
        str.isSelectable = true
        
        var separateLine = UIImageView.init(image:(UIImage.image(color: UIColor.black, size: CGSize(width: self.mainViewWidth, height: CGFloat(5)))))
        
        separateLine.frame = CGRect(x: 0, y:currentHeight-25, width: self.mainViewWidth, height: CGFloat(0.5))
        separateLine.alpha = CGFloat(0.07)
        
        str.text = stationName
        str.font = str.font?.withSize(CGFloat(15.0))
        image.image = colorImage
        
        
        self.mainView.addSubview(image)
        self.mainView.addSubview(str)
        self.mainView.addSubview(separateLine)
        
        return (frame.minY+frame.maxY)/2
    }
    func bothStationView(stationName:String,currentHeight:CGFloat) -> CGFloat{
        let lineColor = self.ap.lineColor
        let color = UIColor(hex:lineColor,alpha:1.0)
        let size = CGSize(width: 10, height: 50)
        let colorImage = UIImage.image(color: color, size: size)
        var frame:CGRect = CGRect(x: (self.mainViewWidth/3)*2, y:currentHeight, width: 10, height: 50)
        var image = UIImageView(frame: frame)
        var textFrame:CGRect = CGRect(x: 10, y: currentHeight+10, width: 200, height: 50)
        var str = UITextView(frame:textFrame)
        str.isSelectable = true
        
        //str.text = stationName
        str.font = str.font?.withSize(CGFloat(15.0))
        image.image = colorImage
        var separateLine = UIImageView.init(image:(UIImage.image(color: UIColor.black, size: CGSize(width: self.mainViewWidth, height: CGFloat(5)))))
        
        separateLine.frame = CGRect(x: 0, y:currentHeight-25, width: self.mainViewWidth, height: CGFloat(0.5))
        separateLine.alpha = CGFloat(0.07)
        
        self.mainView.addSubview(image)
        self.mainView.addSubview(separateLine)
        
        return (frame.minY+frame.maxY)/2
    }
    let train_image = UIButton()
    
    func GetTrain(){
        let json = JsonGet(fileName: "metro_direction")
        let data = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
        
        let url = URL(string:"https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Train&odpt:railway=\(self.lineCode)&acl:consumerKey=\(self.TokyoMetro_AccessToken)")
        print(String(describing:self.JsonGet(fileName: "other_stationDict")))
        Alamofire.request(url!).responseJSON{response in
            print(response.result.value)
            let data = JSON(response.result.value)
            var keepAlive = true
            if data.count >= 1{
                keepAlive = false
            }
            let runLoop = RunLoop.current
            while keepAlive &&
                runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                    // 0.1秒毎の処理なので、処理が止まらない
                    print("処理を待っています")
            }
            for i in 0...data.count-1{
                print(data[i]["odpt:railDirection"])
                let StationData = try! Realm()
                let StationDataAlias = StationData.objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
                
                let firstStation = StationDataAlias.first?.stationCode
                let lastStation = StationDataAlias.last?.stationCode
                
                let UpStr = String(describing:json[firstStation!])
                let DownStr = String(describing:json[lastStation!])
                //print("この路線の01方面は\(UpStr), 最終方面は\(DownStr)")
                if String(describing:data[i]["odpt:railDirection"]) == UpStr{ //下から上に
                    let lineData = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
                    if data[i]["odpt:toStation"] != nil{
                        for j in 0...lineData.count-1{
                            if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                                let train_image = UIImageView.init(image: #imageLiteral(resourceName: "up.png"))
                                train_image.frame = CGRect(x: (self.mainViewWidth/3)*2-40, y: CGFloat((50*2*j+10)-50), width: CGFloat(15), height: CGFloat(25))
                                train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                                let destinationTxt = UILabel(frame: CGRect(x: (train_image.frame.maxX+train_image.frame.minX)/2, y: train_image.frame.maxY-25, width: CGFloat(100), height: CGFloat(30)))
                                let dest_stationStr = String(describing:data[i]["odpt:terminalStation"])
                                var destinationStr = ""
                                if dest_stationStr.contains("TokyoMetro"){
                                    let strs = dest_stationStr.components(separatedBy: ".")
                                    destinationStr = String(describing:self.JsonGet(fileName: "metro_stationDict")[strs[3]])
                                    //destinationStr = strs[3]
                                }else{
                                    destinationStr = String(describing:self.JsonGet(fileName: "other_stationDict")[dest_stationStr])
                                }
                                
                                print(dest_stationStr)
                                destinationTxt.text = destinationStr
                                
                                self.mainView.addSubview(train_image)
                                self.mainView.addSubview(destinationTxt)
                            }
                        }
                        
                    }else{
                        for j in 0...lineData.count-1{
                            if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                                let train_image = UIImageView.init(image: #imageLiteral(resourceName: "up.png"))
                                train_image.frame = CGRect(x: (self.mainViewWidth/3)*2-40, y: CGFloat(50*2*j+10), width: CGFloat(15), height: CGFloat(25))
                                train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                                let destinationTxt = UILabel(frame: CGRect(x: (train_image.frame.maxX+train_image.frame.minX)/2, y: train_image.frame.maxY-25, width: CGFloat(100), height: CGFloat(30)))
                                let dest_stationStr = String(describing:data[i]["odpt:terminalStation"])
                                var destinationStr = ""
                                if dest_stationStr.contains("TokyoMetro"){
                                    let strs = dest_stationStr.components(separatedBy: ".")
                                    destinationStr = String(describing:self.JsonGet(fileName: "metro_stationDict")[strs[3]])
                                }else{
                                    destinationStr = String(describing:self.JsonGet(fileName: "other_stationDict")[dest_stationStr])
                                }
                                
                                print(dest_stationStr)
                                destinationTxt.text = destinationStr
                                
                                self.mainView.addSubview(train_image)
                                self.mainView.addSubview(destinationTxt)
                            }
                        }
                    }
                    
                }else{ //上から下に
                    
                    print(data[i]["odpt:trainNumber"])
                    let lineData = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
                    if data[i]["odpt:toStation"] != nil{
                        for j in 0...lineData.count-1{
                            if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                                let train_image = UIImageView.init(image: #imageLiteral(resourceName: "low.png"))
                                train_image.frame = CGRect(x: (self.mainViewWidth/3)*2+40, y: CGFloat((50*2*j+10)-50), width: CGFloat(15), height: CGFloat(25))
                                train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                                let destinationTxt = UILabel(frame: CGRect(x: (train_image.frame.maxX+train_image.frame.minX)/2, y: train_image.frame.maxY-25, width: CGFloat(100), height: CGFloat(30)))
                                let dest_stationStr = String(describing:data[i]["odpt:terminalStation"])
                                var destinationStr = ""
                                if dest_stationStr.contains("TokyoMetro"){
                                    let strs = dest_stationStr.components(separatedBy: ".")
                                    destinationStr = String(describing:self.JsonGet(fileName: "metro_stationDict")[strs[3]])
                                }else{
                                    destinationStr = String(describing:self.JsonGet(fileName: "other_stationDict")[dest_stationStr])
                                }
                                
                                print(dest_stationStr)
                                destinationTxt.text = destinationStr
                                
                                self.mainView.addSubview(train_image)
                                self.mainView.addSubview(destinationTxt)
                            }
                        }
                        
                    }else{
                        for j in 0...lineData.count-1{
                            if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                                
                                let train_image = UIImageView.init(image: #imageLiteral(resourceName: "low.png"))
                                train_image.frame = CGRect(x: (self.mainViewWidth/3)*2+40, y: CGFloat((50*2*j+10)-50), width: CGFloat(15), height: CGFloat(25))
                                train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                                let destinationTxt = UILabel(frame: CGRect(x: (train_image.frame.maxX+train_image.frame.minX)/2, y: train_image.frame.maxY-25, width: CGFloat(100), height: CGFloat(30)))
                                let dest_stationStr = String(describing:data[i]["odpt:terminalStation"])
                                var destinationStr = ""
                                if dest_stationStr.contains("TokyoMetro"){
                                    let strs = dest_stationStr.components(separatedBy: ".")
                                    destinationStr = String(describing:self.JsonGet(fileName: "metro_stationDict")[strs[3]])
                                }else{
                                    destinationStr = String(describing:self.JsonGet(fileName: "other_stationDict")[dest_stationStr])
                                }
                                
                                print(dest_stationStr)
                                destinationTxt.text = destinationStr
                                
                                self.mainView.addSubview(train_image)
                                self.mainView.addSubview(destinationTxt)
                                
                                
                            }
                        }
                    }
                    
                    
                }
            }
        }
    }
    
    @objc func buttonTapped(sender:AnyObject){
        
    }
    
    func GetTrainPos_Up(){
        let json = JsonGet(fileName: "metro_direction")
        let data = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
        
        let dist = String(describing:json[(data.first?.stationCode)!])
        let url = URL(string:"https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Train&odpt:railway=\(self.lineCode)&odpt:railDirection=\(dist)&acl:consumerKey=\(self.TokyoMetro_AccessToken)")
        
        //print(url)
        
        Alamofire.request(url!).responseJSON{response in
            print(response.result.value)
            let data = JSON(response.result.value)
            var keepAlive = true
            if data.count >= 1{
                keepAlive = false
            }
            let runLoop = RunLoop.current
            while keepAlive &&
                runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                    // 0.1秒毎の処理なので、処理が止まらない
                    print("処理を待っています")
            }
            for i in 0...data.count-1{
                print(data[i]["odpt:trainNumber"])
                let lineData = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
                if data[i]["odpt:toStation"] != nil{
                    for j in 0...lineData.count-1{
                        if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                            let train_image = UIImageView.init(image: #imageLiteral(resourceName: "up.png"))
                            train_image.frame = CGRect(x: (self.mainViewWidth/3)*2-20, y: CGFloat((50*2*j+10)-50), width: CGFloat(15), height: CGFloat(25))
                            train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                            self.mainView.addSubview(train_image)
                        }
                    }
                    
                }else{
                    for j in 0...lineData.count-1{
                        if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                            let train_image = UIImageView.init(image: #imageLiteral(resourceName: "up.png"))
                            train_image.frame = CGRect(x: (self.mainViewWidth/3)*2-20, y: CGFloat(50*2*j+10), width: CGFloat(15), height: CGFloat(25))
                            train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                            self.mainView.addSubview(train_image)
                        }
                    }
                }
                
            }
        }
    }
    
    func GetTrainPos_Down(){
        let json = JsonGet(fileName: "metro_direction")
        let data = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
        
        let dist = String(describing:json[(data.last?.stationCode)!])
        let url = URL(string:"https://api.tokyometroapp.jp/api/v2/datapoints?rdf:type=odpt:Train&odpt:railway=\(self.lineCode)&odpt:railDirection=\(dist)&acl:consumerKey=\(self.TokyoMetro_AccessToken)")
        
        //print(url)
        
        Alamofire.request(url!).responseJSON{response in
            print(response.result.value)
            let data = JSON(response.result.value)
            var keepAlive = true
            if data.count >= 1{
                keepAlive = false
            }
            
            let runLoop = RunLoop.current
            while keepAlive &&
                runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate(timeIntervalSinceNow: 0.1) as Date) {
                    // 0.1秒毎の処理なので、処理が止まらない
                    print("処理を待っています")
            }
            for i in 0...data.count-1{
                print(data[i]["odpt:trainNumber"])
                let lineData = try! Realm().objects(stationData.self).filter("lineCode == %@",self.ap.lineCode).sorted(byKeyPath: "stationID", ascending: true)
                if data[i]["odpt:toStation"] != nil{
                    for j in 0...lineData.count-1{
                        if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                            let train_image = UIImageView.init(image: #imageLiteral(resourceName: "low.png"))
                            train_image.frame = CGRect(x: (self.mainViewWidth/3)*2+20, y: CGFloat((50*2*j+10)-50), width: CGFloat(15), height: CGFloat(25))
                            train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                            self.mainView.addSubview(train_image)
                        }
                    }
                    
                }else{
                    for j in 0...lineData.count-1{
                        if String(describing:data[i]["odpt:fromStation"]) == lineData[j].stationCode{
                            let train_image = UIImageView.init(image: #imageLiteral(resourceName: "low.png"))
                            train_image.frame = CGRect(x: (self.mainViewWidth/3)*2+20, y: CGFloat(50*2*j+10), width: CGFloat(15), height: CGFloat(25))
                            train_image.tintColor = UIColor(hex:self.ap.lineColor,alpha:1.0)
                            self.mainView.addSubview(train_image)
                        }
                    }
                }
                
            }
        }
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

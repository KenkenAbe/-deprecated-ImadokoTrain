//
//  AppDelegate.swift
//  ImaDokoTrain
//
//  Created by KentaroAbe on 2017/10/24.
//  Copyright © 2017年 KentaroAbe. All rights reserved.
//

import UIKit
import SwiftyJSON
import RealmSwift
import Alamofire

class LineData:Object{
    @objc dynamic var dataID = 0
    @objc dynamic var OperatorName = "" //運行会社
    @objc dynamic var lineName = "" //路線名
    @objc dynamic var isLtdEXP = false //特急（JR線の特急は遅延時分を表示しない）
    @objc dynamic var lineID = 0 //路線ID
    @objc dynamic var lineCode = "" //路線コード（東京メトロでリクエストを投げる際に使用するためのコード）
    @objc dynamic var lineColor = "" //路線カラー（HTMLカラー)
    @objc dynamic var isUnique = false //JREの首都圏列車位置情報とは違う法則性のURLを使っているか
    @objc dynamic var dataURL = "" //isUniqueがtrueの場合はURLを記録
    @objc dynamic var type = "" //データタイプ（例：JRE/京王->HTML 東急/東京メトロ->JSON）
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    var lineID = 0
    var lineName = [String]()
    var TokyoMetroStationData:JSON? = nil

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
       
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}


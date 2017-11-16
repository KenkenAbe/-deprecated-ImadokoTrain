//
//  TableViewCell.swift
//  ImaDokoTrain
//
//  Created by KentaroAbe on 2017/11/06.
//  Copyright © 2017年 KentaroAbe. All rights reserved.
//

import UIKit

class TableViewCell: UITableViewCell {

    @IBOutlet var LineName: UILabel!
    @IBOutlet var DelayTime: UILabel!
    @IBOutlet var LineImage: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

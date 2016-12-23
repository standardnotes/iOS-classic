//
//  TagTableViewCell.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit

class TagTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var `switch`: UISwitch!
    var tagObject: Tag!
    var selectionStateChanged: ((TagTableViewCell, Bool) -> ())!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        self.selectionStateChanged(self, sender.isOn)
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

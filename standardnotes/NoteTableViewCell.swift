//
//  NoteTableViewCell.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/23/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit

class NoteTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var contentLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    var note: Note!
    var longPressHandler: ((NoteTableViewCell) -> ())!
    var longPress: UILongPressGestureRecognizer!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        configureLongPress()
    }
    
    func configureLongPress() {
        longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressStateDidChange(gesture:)))
        addGestureRecognizer(longPress)
    }
    
    func longPressStateDidChange(gesture: UIGestureRecognizer) {
        if gesture.state == .began {
            longPressHandler(self)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}

//
//  TagsViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/22/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit
import CoreData

class TagsViewController: UIViewController {
    
    internal var selectedTags = NSMutableSet()
    var selectionCompletion: (([Tag]) -> ())?
    
    @IBOutlet weak var tableView: UITableView!
    
    var resultsController: NSFetchedResultsController<Tag>!
    
    func setInitialSelectedTags(tags: [Tag]) {
        selectedTags = NSMutableSet(array: tags)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureResultsController()
        configureNavBar()
    }
    
    func configureNavBar() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Dismiss", style: .plain, target: self, action: #selector(donePressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New", style: .plain, target: self, action: #selector(newTagPressed))
    }
    
    func newTagPressed() {
        let alertController = UIAlertController(title: "Add New Tag", message: "", preferredStyle: .alert)
        
        let saveAction = UIAlertAction(title: "Save", style: .default, handler: {
            alert -> Void in
            
            let textField = alertController.textFields![0] as UITextField
            let tagTitle = textField.text!
            let tag = ItemManager.sharedInstance.findTag(byTitle: tagTitle)
            if tag == nil {
                let createdTag = ItemManager.sharedInstance.createTag(title: tagTitle)
                createdTag.dirty = true
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: ApiController.DirtyChangeMadeNotification), object: nil)
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: {
            (action : UIAlertAction!) -> Void in
            
        })
        
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "Tag Name"
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func donePressed() {
        self.selectionCompletion?(self.selectedTags.allObjects as! [Tag])
        self.dismiss(animated: true, completion: nil)
    }
    
    func configureResultsController() {
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        let sort = NSSortDescriptor(key: "uuid", ascending: true)
        fetchRequest.sortDescriptors = [sort]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: AppDelegate.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        resultsController.delegate = self
        do {
            try resultsController.performFetch()
        }
        catch {
            print("Error fetching: \(error)")
        }
    }
    
    func isTagSelected(tag: Tag) -> Bool {
        return selectedTags.contains(tag)
    }
    
    func setTagEnabled(tag: Tag, enabled: Bool) {
        if !enabled {
            selectedTags.remove(tag)
        } else {
            selectedTags.addObjects(from: [tag])
        }
    }
    
    func presentActionSheetForTag(tag: Tag) {
        let alertController = UIAlertController(title: tag.url, message: nil, preferredStyle: .actionSheet)
        
        let cell = self.tableView.cellForRow(at: self.resultsController.indexPath(forObject: tag)!)
        alertController.popoverPresentationController?.sourceView = cell
        
        let shareAction = UIAlertAction(title: "Share", style: .default, handler: {
            alert -> Void in
            ApiController.sharedInstance.shareItem(item: tag, completion: { (error) in
                if error != nil {
                    self.showAlert(title: "Oops", message: error!.localizedDescription)
                } else {
                    self.tableView.reloadData()
                    self.presentActionSheetForTag(tag: tag)
                }
            })
        })
        
        let openInSafariAction = UIAlertAction(title: "View In Safari", style: .default, handler: {
            alert -> Void in
            UIApplication.shared.open(URL(string: tag.url!)!, options: [:], completionHandler: nil)
        })
        
        let unshareAction = UIAlertAction(title: "Unshare", style: .default, handler: {
            alert -> Void in
            ApiController.sharedInstance.unshareItem(item: tag, completion: { (error) in
                if error != nil {
                    self.showAlert(title: "Oops", message: error!.localizedDescription)
                } else {
                    self.tableView.reloadData()
                    self.presentActionSheetForTag(tag: tag)
                }
            })
        })
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: {
            alert -> Void in
            if !tag.canDelete() {
                self.showAlert(title: "Cannot Delete", message: "To delete this tag, first delete all the notes that belong to this tag.")
            } else {
                self.showDestructiveAlert(title: "Confirm Deletion", message: "Are you sure you want to delete this tag?", buttonString: "Delete", block: {
                    self.deleteTag(tag: tag)
                })
            }
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action : UIAlertAction!) -> Void in
            
        })
        
        if tag.isPublic {
            alertController.addAction(unshareAction)
            alertController.addAction(openInSafariAction)
        } else {
            alertController.addAction(shareAction)
        }
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func deleteTag(tag: Tag) {
        ItemManager.sharedInstance.setItemToBeDeleted(item: tag)
        ApiController.sharedInstance.sync { (error) in
            if error == nil {
                ItemManager.sharedInstance.removeItemFromCoreData(item: tag)
            } else {
                self.showAlert(title: "Oops", message: "There was an error deleting this tag. Please try again.")
            }
        }
    }
}


extension TagsViewController : UITableViewDelegate, UITableViewDataSource {
    
    func configureCell(cell: TagTableViewCell, indexPath: NSIndexPath) {
        let selectedObject = resultsController.object(at: indexPath as IndexPath) as Tag
        cell.titleLabel?.text = "\(selectedObject.safeTitle())"
        cell.switch.setOn(isTagSelected(tag: selectedObject), animated: false)
        cell.tagObject = selectedObject
        cell.selectionStyle = .none
        cell.selectionStateChanged = {changedCell, status in
            self.setTagEnabled(tag: cell.tagObject, enabled: status)
        }
        cell.longPressHandler = { cell in
            self.presentActionSheetForTag(tag: cell.tagObject)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)
        configureCell(cell: cell as! TagTableViewCell, indexPath: indexPath as NSIndexPath)
        return cell
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return resultsController.sections!.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sections = resultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[section]
        // print("Returning number of row: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedObject = resultsController.object(at: indexPath as IndexPath) as Tag
        setTagEnabled(tag: selectedObject, enabled: !isTagSelected(tag: selectedObject))
        tableView.reloadRows(at: [indexPath], with: .none)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension TagsViewController : NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex) as IndexSet, with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath! as IndexPath], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath! as IndexPath], with
                : .fade)
        case .update:
            configureCell(cell: tableView.cellForRow(at: indexPath! as IndexPath) as! TagTableViewCell, indexPath: indexPath! as NSIndexPath)
        case .move:
            tableView.moveRow(at: indexPath! as IndexPath, to: newIndexPath! as IndexPath)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}


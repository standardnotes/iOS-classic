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
    
    enum Section: Int {
        case Sort = 0
        case Tags = 1
        case Count
    }
    
    var hasSortType = true
    var sort: SortType!
    
    internal var selectedTags = NSMutableSet()
    var selectionCompletion: (([Tag], SortType?) -> ())?
    
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
    
    var isModal: Bool {
        return self.presentingViewController?.presentedViewController == self
            || (self.navigationController != nil && self.navigationController?.presentingViewController?.presentedViewController == self.navigationController)
            || self.tabBarController?.presentingViewController is UITabBarController
    }
    
    func configureNavBar() {
        self.title = hasSortType ? "Filter" : "Tags"
        if self.isModal {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(donePressed))
        }
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
        self.selectionCompletion?(self.selectedTags.allObjects as! [Tag], sort)
        self.dismiss(animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
     
        if !self.isModal {
            self.selectionCompletion?(self.selectedTags.allObjects as! [Tag], sort)
        }
    }
    
    func configureResultsController() {
        let fetchRequest = NSFetchRequest<Tag>(entityName: "Tag")
        let sort = NSSortDescriptor(key: "title", ascending: true)
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
    
    func mapFRCIndexPathToTableIndexPath(indexPath: IndexPath) -> IndexPath {
        return IndexPath(row: indexPath.row, section: hasSortType ? Section.Tags.rawValue : 0)
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
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let cell = self.tableView.cellForRow(at: self.resultsController.indexPath(forObject: tag)!)
        alertController.popoverPresentationController?.sourceView = cell
        
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
    
    func tagAtIndexPath(indexPath: IndexPath) -> Tag {
        return resultsController.object(at: IndexPath(row: indexPath.row, section: 0)) as Tag
    }

}


extension TagsViewController : UITableViewDelegate, UITableViewDataSource {
    
    func configureTagCell(cell: TagTableViewCell, indexPath: NSIndexPath) {
        let sectionInfo = resultsController.sections![0]
        if sectionInfo.numberOfObjects <= indexPath.row {
            return
        }
    
        let selectedObject = tagAtIndexPath(indexPath: indexPath as IndexPath)
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
    
    func configureSortCell(cell: UITableViewCell, indexPath: NSIndexPath) {
        let sortType = SortType(rawValue: indexPath.row)!
        switch sortType {
        case .Created:
            cell.textLabel?.text = "Date Created"
            break
        case .Modified:
            cell.textLabel?.text = "Date Modified"
            break
        case .Title:
            cell.textLabel?.text = "Title"
            break
        default:
            break
        }
        
        cell.selectionStyle = .none
        cell.accessoryType = sortType == sort ? UITableViewCellAccessoryType.checkmark : UITableViewCellAccessoryType.none
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if hasSortType && indexPath.section == Section.Sort.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SortCell", for: indexPath)
            configureSortCell(cell: cell, indexPath: indexPath as NSIndexPath)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TagCell", for: indexPath)
            configureTagCell(cell: cell as! TagTableViewCell, indexPath: indexPath as NSIndexPath)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if hasSortType && section == Section.Sort.rawValue {
            return "Sort by"
        } else if hasSortType {
            return "Tags"
        }
        return nil
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        if hasSortType {
            return Section.Count.rawValue
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if hasSortType && section == Section.Sort.rawValue {
            return SortType.TypeCount.rawValue
        }
        
        guard let sections = resultsController.sections else {
            fatalError("No sections in fetchedResultsController")
        }
        let sectionInfo = sections[0]
        // print("Returning number of row: \(sectionInfo.numberOfObjects)")
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if hasSortType && indexPath.section == Section.Sort.rawValue {
            sort = SortType(rawValue: indexPath.row)!
            tableView.reloadSections(NSIndexSet(index: indexPath.section) as IndexSet, with: .none)
        } else {
            let selectedObject = tagAtIndexPath(indexPath: mapFRCIndexPathToTableIndexPath(indexPath: indexPath))
            setTagEnabled(tag: selectedObject, enabled: !isTagSelected(tag: selectedObject))
            tableView.reloadRows(at: [indexPath], with: .none)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
}

extension TagsViewController : NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(NSIndexSet(index: hasSortType ? Section.Tags.rawValue : 0) as IndexSet, with: .fade)
        case .delete:
            tableView.deleteSections(NSIndexSet(index: hasSortType ? Section.Tags.rawValue : 0) as IndexSet, with: .fade)
        case .move:
            break
        case .update:
            break
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [mapFRCIndexPathToTableIndexPath(indexPath: newIndexPath!)], with: .fade)
        case .delete:
            tableView.deleteRows(at: [mapFRCIndexPathToTableIndexPath(indexPath: indexPath!)], with
                : .fade)
        case .update:
            if let cell = tableView.cellForRow(at: mapFRCIndexPathToTableIndexPath(indexPath: indexPath!)) as? TagTableViewCell {
                configureTagCell(cell: cell, indexPath: mapFRCIndexPathToTableIndexPath(indexPath: indexPath!) as NSIndexPath)
            }
        case .move:
            tableView.moveRow(at: mapFRCIndexPathToTableIndexPath(indexPath: indexPath!), to: mapFRCIndexPathToTableIndexPath(indexPath: newIndexPath!))
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}


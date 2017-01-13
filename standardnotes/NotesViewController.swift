//
//  ViewController.swift
//  standardnotes
//
//  Created by Mo Bitar on 12/19/16.
//  Copyright © 2016 Standard Notes. All rights reserved.
//

import UIKit
import CoreData

class NotesViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    var resultsController: NSFetchedResultsController<Note>!
    var selectedTags = [Tag]()
    var refreshControl: UIRefreshControl!
   
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureNavBar()
        reloadResults()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main) { (notification) in
            self.refreshItems()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: UserManager.LogoutNotification), object: nil, queue: OperationQueue.main) { (notification) in
            self.reloadResults()
        }
    }
    
    func configureTableView() {
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 90
     
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }
    
    func refresh() {
        refreshItems()
    }
    
    func configureNavBar() {
        let tagsTitle = selectedTags.count > 0 ? "Tags (\(selectedTags.count))" : "Tags"
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: tagsTitle, style: .plain, target: self, action: #selector(tagsPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New", style: .plain, target: self, action: #selector(newPressed))
    }
    
    var viewDidDisappear = false
    
    override func viewWillAppear(_ animated: Bool) {
        refreshItems()
        if viewDidDisappear {
            viewDidDisappear = false
                self.sync()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        viewDidDisappear = true
    }
    
    func refreshItems() {
        if !UserManager.sharedInstance.signedIn {
            return
        }
        
        ApiController.sharedInstance.sync { (error) in
            self.refreshControl.endRefreshing()
        }
    }
    
    func tagsPressed() {
        let tags = self.storyboard?.instantiateViewController(withIdentifier: "Tags") as! TagsViewController
        tags.setInitialSelectedTags(tags: self.selectedTags)
        tags.selectionCompletion = { tags in
            self.selectedTags = tags
            self.reloadResults()
            self.configureNavBar()
        }
        
        let navController = UINavigationController(rootViewController: tags)
        self.present(navController, animated: true, completion: nil)
    }
    
    func newPressed() {
        presentComposer(note: nil)
    }
    
    func presentComposer(note: Note?) {
        let compose = self.storyboard?.instantiateViewController(withIdentifier: "Compose") as! ComposeViewController
        compose.note = note
        let navController = UINavigationController(rootViewController: compose)
        self.present(navController, animated: true, completion: nil)
    }
    
    func reloadResults() {
        let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
        fetchRequest.predicate = NSPredicate(format: "draft == false")
        if selectedTags.count > 0 {
            var predicates = [NSPredicate]()
            for tag in selectedTags {
                let tagPredicate = NSPredicate(format: "ANY tags.uuid == %@", tag.uuid)
                predicates.append(tagPredicate)
            }
            let tagPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [fetchRequest.predicate!, tagPredicate])
        }
        let sort = NSSortDescriptor(key: "createdAt", ascending: false)
        fetchRequest.sortDescriptors = [sort]
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: AppDelegate.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
    
        resultsController.delegate = self
        do {
            try resultsController.performFetch()
            self.tableView.reloadData()
        }
        catch {
            print("Error fetching: \(error)")
        }
    }
    
    func presentActionSheetForNote(note: Note) {
        let alertController = UIAlertController(title: note.url, message: nil, preferredStyle: .actionSheet)
    
        let cell = self.tableView.cellForRow(at: self.resultsController.indexPath(forObject: note)!)
        alertController.popoverPresentationController?.sourceView = cell
        
        let shareAction = UIAlertAction(title: "Share", style: .default, handler: {
            alert -> Void in
            ApiController.sharedInstance.shareItem(item: note, completion: { (error) in
                if error != nil {
                    self.showAlert(title: "Oops", message: error!.localizedDescription)
                } else {
                    self.tableView.reloadData()
                    self.presentActionSheetForNote(note: note)
                }
            })
        })
        
        let openInSafariAction = UIAlertAction(title: "View In Safari", style: .default, handler: {
            alert -> Void in
            UIApplication.shared.open(URL(string: note.url!)!, options: [:], completionHandler: nil)
        })
        
        let unshareAction = UIAlertAction(title: "Unshare", style: .default, handler: {
            alert -> Void in
            ApiController.sharedInstance.unshareItem(item: note, completion: { (error) in
                if error != nil {
                    self.showAlert(title: "Oops", message: error!.localizedDescription)
                } else {
                    self.tableView.reloadData()
                    self.presentActionSheetForNote(note: note)
                }
            })
        })
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: {
            alert -> Void in
            self.showDestructiveAlert(title: "Confirm Deletion", message: "Are you sure you want to delete this note?", buttonString: "Delete", block: { 
                self.deleteNote(note: note)
            })
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: {
            (action : UIAlertAction!) -> Void in
            
        })
        
        if note.isSharedIndividually {
            alertController.addAction(unshareAction)
            alertController.addAction(openInSafariAction)
        } else {
            alertController.addAction(shareAction)
        }
        alertController.addAction(deleteAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func deleteNote(note: Note) {
        ItemManager.sharedInstance.setItemToBeDeleted(item: note)
        ApiController.sharedInstance.sync { (error) in
            if error == nil {
                ItemManager.sharedInstance.removeItemFromCoreData(item: note)
            } else {
                self.showAlert(title: "Oops", message: "There was an error deleting your note. Please try again.")
            }
        }
    }
}

extension NotesViewController : UITableViewDelegate, UITableViewDataSource {
    
    func configureCell(cell: NoteTableViewCell, indexPath: NSIndexPath) {
        let selectedObject = resultsController.object(at: indexPath as IndexPath) as Note
        cell.titleLabel?.text = selectedObject.safeTitle()
        cell.contentLabel?.text = selectedObject.safeText()
        cell.dateLabel?.text = selectedObject.humanReadableCreateDate()
        cell.note = selectedObject
        cell.longPressHandler = { cell in
            self.presentActionSheetForNote(note: cell.note)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath) as! NoteTableViewCell
        configureCell(cell: cell, indexPath: indexPath as NSIndexPath)
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
        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedObject = resultsController.object(at: indexPath as IndexPath) as Note
        presentComposer(note: selectedObject)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let selectedNote = resultsController.object(at: indexPath as IndexPath) as Note
            deleteNote(note: selectedNote)
        }
    }
}

extension NotesViewController : NSFetchedResultsControllerDelegate {
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
            if let cell = tableView.cellForRow(at: indexPath! as IndexPath) as? NoteTableViewCell {
                configureCell(cell: cell, indexPath: indexPath! as NSIndexPath)
            }
        case .move:
            tableView.moveRow(at: indexPath! as IndexPath, to: newIndexPath! as IndexPath)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}


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
   
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        configureNavBar()
        reloadResults()
    }
    
    func configureTableView() {
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 70
    }
    
    func configureNavBar() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Tags", style: .plain, target: self, action: #selector(tagsPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New", style: .plain, target: self, action: #selector(newPressed))
    }
    
    var viewDidDisappear = false
    
    override func viewWillAppear(_ animated: Bool) {
        if viewDidDisappear {
            viewDidDisappear = false
            ApiController.sharedInstance.saveDirtyItems {
                
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        viewDidDisappear = true
    }
    
    func refreshItems() {
        ApiController.sharedInstance.refreshItems { (items) in
        }
    }
    
    func tagsPressed() {
        let tags = self.storyboard?.instantiateViewController(withIdentifier: "Tags") as! TagsViewController
        tags.setInitialSelectedTags(tags: self.selectedTags)
        tags.selectionCompletion = { tags in
            self.selectedTags = tags
            self.reloadResults()
            print("Reloading results after tags selecteion: \(tags)")
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
        let sort = NSSortDescriptor(key: "uuid", ascending: true)
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
}

extension NotesViewController : UITableViewDelegate, UITableViewDataSource {
    
    func configureCell(cell: NoteTableViewCell, indexPath: NSIndexPath) {
        let selectedObject = resultsController.object(at: indexPath as IndexPath) as Note
        cell.titleLabel?.text = selectedObject.safeTitle()
        cell.contentLabel?.text = selectedObject.safeText()
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
            configureCell(cell: tableView.cellForRow(at: indexPath! as IndexPath) as! NoteTableViewCell, indexPath: indexPath! as NSIndexPath)
        case .move:
            tableView.moveRow(at: indexPath! as IndexPath, to: newIndexPath! as IndexPath)
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}


//
//  NoteMap.swift
//  NoteMap
//
//  Created by Zach Eriksen on 6/23/17.
//  Copyright © 2017 oneleif. All rights reserved.
//

import UIKit
import RxCocoa
import RxSwift

class NoteMap: UIView {
    fileprivate var clusters: Variable<[Cluster]> = Variable([])
    fileprivate var disposeBag = DisposeBag()
    private var doubleTapGestureRecognizer: UITapGestureRecognizer {
        let tgr = UITapGestureRecognizer(target: self, action: #selector(doubleTap))
        tgr.numberOfTapsRequired = 2
        return tgr
    }

    init() {
		super.init(frame: CGRect(origin: .zero, size: Singleton.standard().noteMapSize()))
		NMinit()
		if !UserDefaults.standard.bool(forKey: "tutorialNotesViewed") {
			addTutorialNotes()
		}
	}
	
	private func NMinit() {
		backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1)
		addGestureRecognizer(doubleTapGestureRecognizer)
		bindObservers()
	}
    
    private func bindObservers() {
        disposeBag = DisposeBag()
        clusterArraySubscriber().disposed(by: disposeBag)
        bindSave().disposed(by: disposeBag)
        bindLoad().disposed(by: disposeBag)
    }

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func doubleTap(sender: UITapGestureRecognizer) {	
        _ = addNote(atCenter: sender.location(in: self))
        logAnalytic()
	}
}

extension NoteMap: LogAnalytic {
    func logAnalytic() {
        Singleton.log(type: .Notemap)
    }
}

extension NoteMap {
    //MARK: Public helpers
    func removedNoteMerge(forArray observableArray: [Observable<Note>]) -> Disposable {
        return Observable.merge(observableArray).subscribe(onNext: { note in
            self.addCluster(forNote: note)
        })
    }
    
    func checkConsumeMerge(forArray observableArray: [Observable<Cluster>]) -> Disposable {
        return Observable.merge(observableArray).subscribe(onNext: { cluster in
            cluster.check(bounds: self.bounds)
            self.checkConsume()
        })
    }
    
    func clusterArraySubscriber() -> Disposable {
        return clusters.asObservable().subscribe(onNext: { cluster in

                var arrayOfNoteRemoval = [Observable<Note>]()
                self.clusters.value.forEach { (arrayOfNoteRemoval.append($0.removedNoteObservable)) }
                self.removedNoteMerge(forArray: arrayOfNoteRemoval).disposed(by: self.disposeBag)

                var arrayOfCheckConsumeEvent = [Observable<(Cluster)>]()
                self.clusters.value.forEach { (arrayOfCheckConsumeEvent.append($0.checkNotemapConsume)) }
                self.checkConsumeMerge(forArray: arrayOfCheckConsumeEvent).disposed(by: self.disposeBag)
        })
    }
    
    func bindSave() -> Disposable {
        return Singleton.global.SaveDataObservable.subscribe(onNext: {
            let toBeSavedModel = self.generateSnapshot()
            let b = toBeSavedModel as! NoteMapModel
            let encode = try? JSONEncoder().encode(b)
            let a = String(data: encode!, encoding: String.Encoding.utf8)
            print("Saved data : \(a!)")
            UserDefaults.standard.set(a!, forKey: "nm")
        })
    }
    
    func bindLoad() -> Disposable {
        return Singleton.global.LoadDataObservable.subscribe(onNext: { jsonString in
            if let jsonData = jsonString.data(using: .utf8),
                let model = try? JSONDecoder().decode(NoteMapModel.self, from: jsonData) as NoteMapModel {
                print("Got notemapmodel : \((model))")
                self.loadFromModel(model: model)
            }
        })
    }
    
    func loadFromModel(model: NoteMapModel) {
        for clusterModel in model.clusters {
            let notes = clusterModel.notes.map{ Note(atCenter: $0.center, withColor: Color(rawValue: $0.color)!, withText: $0.text) }
            let cluster = Cluster(notes: notes, withTitle: clusterModel.title)
            clusters.value.append(cluster)
            addSubview(cluster)
            notes.forEach{ addSubview($0) }
        }
        Singleton.global.selectedColor.value = model.settings.selectedColor
        Singleton.global.selectedTheme.value = model.settings.selectedTheme
        
    }
    
    func checkConsume() {
        for cluster in clusters.value {
            let collidingClusters = clusters.value.filter{ check(lhs: cluster, rhs: $0) }
            if !collidingClusters.isEmpty {
                for c in collidingClusters {
                    guard let clusterIndex = clusters.value.index(of: c) else {
                        return
                    }
                    cluster.consume(cluster: c)
                    bindObservers()
                    clusters.value.remove(at: clusterIndex).removeFromSuperview()
                }
            }
        }
    }
    
    func addCluster(forNote note: Note) {
        
        let noClusterInRange = clusters.value.map{ $0.check(note: note) }.filter{ $0 }.isEmpty
        
        if noClusterInRange {
            let cluster = Cluster(note: note)
            bindObservers()
            clusters.value.append(cluster)
            addSubview(cluster)
            sendSubview(toBack: cluster)
        } else {
            let collidedClusters = clusters.value.filter{ $0.check(note: note) }
            var distFromNote: [CGFloat: Cluster] = [:]
            collidedClusters.forEach{ distFromNote[$0.centerPoint.distanceFrom(point: note.center)] = $0 }
            let min = collidedClusters.map{ $0.centerPoint.distanceFrom(point: note.center) }.sorted(by: <).first!
            let cluster = distFromNote[min]
            cluster?.add(note: note)
        }
    }
    
    //MARK: Private helpers
    fileprivate func addNote(atCenter point: CGPoint, withText text: String = "") -> Note {
        return add(note: Note(atCenter: point, withColor: Singleton.global.selectedColor.value, withText: text))
    }
    
    fileprivate func add(note: Note) -> Note {
        addCluster(forNote: note)
        checkConsume()
        addSubview(note)
        
        return note
    }
    
    fileprivate func addTutorialNotes() {
        clusters.value.forEach{ $0.removeFromSuperview() }
        clusters.value = []
        func create(noteWithText text: String, displacementPoint point: CGPoint, andColor color: Color) {
            _ = add(note: Note(atCenter: CGPoint(x: point.x + center.x, y: point.y + center.y), withColor: color, withText: text))
        }
        create(noteWithText: "Double tap with one finger to create a note of the selected color. Double tap with two fingers to delete a note",
               displacementPoint: CGPoint(x: 300, y: 400),
               andColor: .red)
        create(noteWithText: "Use the button in the top left to change your selected color",
               displacementPoint: CGPoint(x: 900, y: 400),
               andColor: .orange)
        create(noteWithText: "Use the keyboard color picker when typing to change the note's color",
               displacementPoint: CGPoint(x: 300, y: 1000),
               andColor: .yellow)
        create(noteWithText: "Drag notes of the same color together to make a cluster. Triple tap with two fingers to delete",
               displacementPoint: CGPoint(x: 900, y: 1000),
               andColor: .green)
        create(noteWithText: "Pinch to zoom in and out. Your position and zoom will be saved",
               displacementPoint: CGPoint(x: 300, y: 1600),
               andColor: .blue)
        create(noteWithText: "Flip the switch in the top right to change the theme. NoteMap will auto save",
               displacementPoint: CGPoint(x: 900, y: 1600),
               andColor: .purple)
        UserDefaults.standard.set(true, forKey: "tutorialNotesViewed")
    }
    
    fileprivate func check(lhs: Cluster, rhs: Cluster) -> Bool {
        return lhs.canConsume(cluster: rhs) && lhs !== rhs && lhs.backgroundColor == rhs.backgroundColor
    }
}

extension NoteMap: Themeable {
	
	func updateTheme() {
		clusters.value.forEach{ $0.updateTheme() }
		backgroundColor = Singleton.global.backgroundColorData
	}
}

extension NoteMap: SnapshotProtocol {
	func generateSnapshot() -> Any {
		var clusterModels: [ClusterModel] = []
		self.clusters.value.forEach { clusterModels.append($0.generateSnapshot() as! ClusterModel) }
        let settings =  NMDefaults(selectedColor: Singleton.global.selectedColor.value, selectedTheme: Singleton.global.selectedTheme.value)
		let model = NoteMapModel(clusters: clusterModels, settings: settings)
		return model
	}
}

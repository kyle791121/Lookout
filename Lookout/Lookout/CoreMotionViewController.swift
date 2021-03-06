//
//  CoreMotionViewController.swift
//  Lookout
//
//  Created by Chunkai Chan on 2016/10/1.
//  Copyright © 2016年 Chunkai Chan. All rights reserved.
//

import UIKit
import CoreMotion
import Charts

// MARK: CoreMotionViewController is used for designer to monitor
//       acceleromter in real time.

class CoreMotionViewController: UIViewController, EventCoreDataManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var eventsUITableView: UITableView!
    
    @IBAction func saveEventButton(sender: AnyObject) {
        
        let time = NSDate()
        let event = Event(time: time, data: yAxis, latitude: AppState.sharedInstance.userLatitude, longitude: AppState.sharedInstance.userLongitude, isAccident: nil)
        
        eventCoreDataManager.saveCoreData(eventToSave: event)
        eventCoreDataManager.fetchCoreData()
    }
    
    @IBOutlet weak var xLineChartView: LineChartView!
    
    let manager = CMMotionManager()
    
    var xAxis = [""]
    var yAxis = [1.0]
    
    var dataEntries: [ChartDataEntry] = []
    
    let eventCoreDataManager = EventCoreDataManager.shared
    
    var event: Event?
    var events:[Event] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        while (yAxis.count < 100) {
            xAxis.append("")
            yAxis.append(1.0)
        }
        
        eventCoreDataManager.delegate = self
        chartView.setChartFormat(lineChartView: xLineChartView)
    }
    
    override func viewDidAppear(animated: Bool) {
        print("Start updating chart.")
        getAccelerationMotion()
        eventCoreDataManager.fetchCoreData()
    }
    
    
    override func viewWillDisappear(animated: Bool) {
        if manager.accelerometerAvailable {
            manager.stopAccelerometerUpdates()
            print("Stop updating chart.")
        }
    }
    
    var sum = 0.0
    let chartView = ChartViewModel()
    
    func getAccelerationMotion() {
        if manager.accelerometerAvailable {
            manager.accelerometerUpdateInterval = 0.04
            manager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue()) {
                [weak self] (data: CMAccelerometerData?, error: NSError?) in
                if let acceleration = data?.acceleration {
                    let overallAcceleration = sqrt(acceleration.x*acceleration.x + acceleration.y*acceleration.y + acceleration.z*acceleration.z)
                    
                    let thetaX = acos(acceleration.x/overallAcceleration)
                    let thetaY = acos(acceleration.y/overallAcceleration)
                    let thetaZ = acos(acceleration.z/overallAcceleration)
                    
                    let Gx = acceleration.x - cos(thetaX)
                    let Gy = acceleration.y - cos(thetaY)
                    let Gz = acceleration.z - cos(thetaZ)
                    
                    // Overall acceleration without gravity
                    let _ = sqrt(Gx*Gx+Gy*Gy+Gz*Gz)
//                    print("D-G x: \(Gx), Gy: \(Gy), Gz: \(Gz), ")
//                    print("Acc x: \(acceleration.x), y: \(acceleration.y), z: \(acceleration.z), ")
//                    print("theta x: \(thetaX*180/M_PI), y: \(thetaY*180/M_PI), z: \(thetaZ*180/M_PI), ")
                    
//                    print(acceleration.z)
//                    print(overallAcceleration*cos(thetaZ))
//                    print(cos(60.0/180*M_PI))
                    self!.yAxis.removeAtIndex(0)
                    self!.yAxis.append(overallAcceleration)
                    
                    
                    if (UIApplication.sharedApplication().applicationState == .Active) {
                        dispatch_async(dispatch_get_main_queue(), {
                            self!.chartView.setChartData(lineChartView: self!.xLineChartView, dataPoints: self!.xAxis, values: self!.yAxis)
                        })
                    }
                }
                
            }
        }
    }
    
    func manager(manager: EventCoreDataManager, didSaveEventData: AnyObject) {
        print("Save an event to core data")
    }
    func manager(manager: EventCoreDataManager, didFetchEventData: AnyObject) {
        events = []
        print("Fetch events from core data.")
        guard let results = didFetchEventData as? [Events] else {fatalError()}
        
        if (results.count>0) {
            
            for result in results {
        
                events.append(Event(time: result.time!,
                                    data: result.data! as! [Double],
                                    latitude: result.latitude! as Double,
                                    longitude: result.longitude! as Double,
                                    isAccident: result.isAccident as? Bool))
                
            }
            
            dispatch_async(dispatch_get_main_queue(), {
            
                UIView.transitionWithView(self.eventsUITableView, duration: 0.35, options: UIViewAnimationOptions.TransitionCrossDissolve, animations: { _ in
                    self.eventsUITableView.reloadData()
                    }, completion: nil)
            })
        }
    }
    
    func manager(manager: EventCoreDataManager, getFetchEventError: ErrorType) {
        print("Error when fetch events from core data.")
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let index = (events.count - 1) - indexPath.row
        let cell = tableView.dequeueReusableCellWithIdentifier("EventsTableCell", forIndexPath: indexPath) as! EventsTableViewCell
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd  HH:mm:ss"
        let convertedDate = dateFormatter.stringFromDate(events[index].time)
        cell.eventTime.text = "\(convertedDate)"
        return cell
    }
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            let index = (events.count - 1) - indexPath.row
            events.removeAtIndex(index)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
            eventCoreDataManager.clearCoreData()
            for event in events {
                eventCoreDataManager.saveCoreData(eventToSave: event)
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let index = (events.count - 1) - indexPath.row
        event = events[index]
        self.performSegueWithIdentifier("SegueEventDetail", sender: [])
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "SegueEventDetail" {
            let destination: EventMapViewController = segue.destinationViewController as! EventMapViewController
            destination.xdata = xAxis
            destination.event = event
        }
    }
}

//
//  ViewController.swift
//  WhaleCodingTest
//
//  Created by Chase Wang on 11/18/16.
//  Copyright © 2016 ocwang. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import AssetsLibrary

private var recordedDurationContext = 0

class ViewController: UIViewController {
    
    // MARK: - Instance Vars
    
    var currentTotalDuration = kCMTimeZero
    
    let maxVideoDuration = CMTime(seconds: 60, preferredTimescale: 1)
    
    var currentProgressViewWidthConstraint: NSLayoutConstraint?
    
    var segmentedProgressViews = [UIView]()

    var videoSegments = [AVAsset]()
    
    let captureSession = AVCaptureSession()
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var movieFileOutput: AVCaptureMovieFileOutput!

    // MARK: - Subviews
    
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var toggleRecordButton: UIButton!
    
    @IBOutlet weak var doneButton: UIButton!
    
    // MARK: - VC Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        setupPreviewLayer()
        // add initial progress view segment
        addSegmentedProgressView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        previewLayer.frame = cameraView.bounds
    }
    
    // MARK: Helpers
    
    func presentAlertController(withTitle title: String) {
        let alertController = UIAlertController(title: title, message: "", preferredStyle: UIAlertControllerStyle.alert)
        
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil)
        alertController.addAction(okAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        
        // TODO: check if mic is automatically added as well
        let cameraDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        var input: AVCaptureDeviceInput!
        do {
            input = try AVCaptureDeviceInput(device: cameraDevice)
        } catch let error as NSError {
            fatalError("Error: \(error.localizedDescription)")
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        movieFileOutput = AVCaptureMovieFileOutput()
        // this should be time left
        
        movieFileOutput.maxRecordedDuration = CMTimeSubtract(maxVideoDuration, currentTotalDuration)
        
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
        }
    }
    
    func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        
        cameraView.layer.addSublayer(previewLayer)
    }
    
    func updateRecordingValues() {
        // NOTE: tried making this work with KVO on movieFileOutput.recordedDuration but observer wasn't being updating frequently enough
        if movieFileOutput.isRecording {
            let seconds = CMTimeGetSeconds(movieFileOutput.recordedDuration)
            let maxDurationInSeconds = CMTimeGetSeconds(maxVideoDuration)
            print("seconds:", seconds)
            
            currentProgressViewWidthConstraint!.constant = CGFloat(seconds) / CGFloat(maxDurationInSeconds) * view.bounds.width
            
            perform(#selector(self.updateRecordingValues), with: nil, afterDelay: 0.1)
        }
    }
    
    func addSegmentedProgressView() {
        let newView = UIView()
        newView.translatesAutoresizingMaskIntoConstraints = false
        
        newView.backgroundColor = .white
        
        view.addSubview(newView)
        
        newView.heightAnchor.constraint(equalToConstant: 10).isActive = true
        newView.bottomAnchor.constraint(equalTo: toggleRecordButton.topAnchor, constant: -5).isActive = true
        
        if segmentedProgressViews.isEmpty {
            newView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
            currentProgressViewWidthConstraint = newView.widthAnchor.constraint(equalToConstant: 0)
            currentProgressViewWidthConstraint?.isActive = true
        } else {
            let lastView = segmentedProgressViews.last!
            newView.leadingAnchor.constraint(equalTo: lastView.trailingAnchor, constant: 2).isActive = true
            currentProgressViewWidthConstraint = newView.widthAnchor.constraint(equalToConstant: 0)
            currentProgressViewWidthConstraint?.isActive = true
        }
        
        segmentedProgressViews.append(newView)

        view.setNeedsUpdateConstraints()
    }
    
    func exportDidFinish(session: AVAssetExportSession) {
        if session.status == AVAssetExportSessionStatus.completed {
            PHPhotoLibrary.shared().performChanges({ [unowned self] in
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: session.outputURL!, options: options)
                
                DispatchQueue.main.async {
                    self.cleanUpForNewSession()
                }

                self.presentAlertController(withTitle: "Finished merging video segments into one video. Saved into your photo library.")
                
            }, completionHandler: { success, error in
                if !success {
                    print("Could not save movie to photo library: \(error)")
                }
            })
        }
    }
    
    func cleanUpForNewSession() {
        currentProgressViewWidthConstraint = nil
        
        for progressViewSegment in segmentedProgressViews {
            progressViewSegment.removeFromSuperview()
        }
        
        segmentedProgressViews.removeAll()
        
        currentTotalDuration = kCMTimeZero
        
        videoSegments.removeAll()
        
        movieFileOutput.maxRecordedDuration = CMTimeSubtract(maxVideoDuration, currentTotalDuration)
        
        addSegmentedProgressView()
    }
    
    // MARK: - IBActions

    @IBAction func toggleRecordButtonTapped(_ sender: UIButton) {
        guard currentTotalDuration <= maxVideoDuration else {
            self.presentAlertController(withTitle: "Max recording duration reached. Click the orange Done button to create your video.")
            return
        }
        
        if !movieFileOutput.isRecording {
            sender.backgroundColor = .red
            sender.setTitle("Stop Recording", for: .normal)
            sender.isUserInteractionEnabled = false
            
            let outputFileName = NSUUID().uuidString
            let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
            movieFileOutput.startRecording(toOutputFileURL: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
            
        } else {
            movieFileOutput.stopRecording()
        }
        
    }
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        let mixComposition = AVMutableComposition()
        let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo,
                                                        preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        var totalDuration = kCMTimeZero
        for asset in videoSegments {
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration),
                                               of: asset.tracks(withMediaType: AVMediaTypeVideo)[0] ,
                                               at: totalDuration)
                
                totalDuration = CMTimeAdd(totalDuration, asset.duration)
            } catch let error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let savePath = (documentDirectory as NSString).appendingPathComponent("mergeVideo-\(date).mov")
        let url = NSURL(fileURLWithPath: savePath)
        
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url as URL
        exporter.outputFileType = AVFileTypeQuickTimeMovie
        exporter.shouldOptimizeForNetworkUse = true
        
        exporter.exportAsynchronously() {
            DispatchQueue.main.async {
                self.exportDidFinish(session: exporter)
            }
        }
    }
}

extension ViewController: AVCaptureFileOutputRecordingDelegate {
    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
        toggleRecordButton.isUserInteractionEnabled = true
        updateRecordingValues()
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        toggleRecordButton.backgroundColor = .green
        toggleRecordButton.setTitle("Start Recording", for: .normal)
        toggleRecordButton.backgroundColor = .white
        
        let videoAsset = AVAsset(url: outputFileURL)
        videoSegments.append(videoAsset)
        currentTotalDuration = CMTimeAdd(currentTotalDuration, videoAsset.duration)
        movieFileOutput.maxRecordedDuration = CMTimeSubtract(maxVideoDuration, currentTotalDuration)
        
        addSegmentedProgressView()
    }
}

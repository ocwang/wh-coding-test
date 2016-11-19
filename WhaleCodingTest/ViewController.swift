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
    
    @IBOutlet weak var videoSegmentProgressBar: VideoSegmentProgressBar!
    
    var segmentedProgressViews = [UIView]()

    var videoSegments = [AVAsset]()
    
    let captureSession = AVCaptureSession()
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var movieFileOutput: AVCaptureMovieFileOutput!

    // MARK: - Subviews
    
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var toggleRecordButton: UIButton!
    
    @IBOutlet weak var nextBarButtonItem: UIBarButtonItem!
    
    @IBOutlet weak var recordContainerView: UIView!
    // MARK: - VC Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCaptureSession()
        setupPreviewLayer()
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
        let micDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeAudio)
        
        var cameraInput: AVCaptureDeviceInput!
        var audioInput: AVCaptureDeviceInput!
        do {
            cameraInput = try AVCaptureDeviceInput(device: cameraDevice)
            audioInput = try AVCaptureDeviceInput(device: micDevice)
        } catch let error as NSError {
            fatalError("Error: \(error.localizedDescription)")
        }
        
        if captureSession.canAddInput(cameraInput) {
            captureSession.addInput(cameraInput)
        }
        
        if captureSession.canAddInput(audioInput) {
            captureSession.addInput(audioInput)
        }
        
        movieFileOutput = AVCaptureMovieFileOutput()
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
            
            let currentProgressViewWidth = CGFloat(seconds / maxDurationInSeconds) * view.bounds.width
            videoSegmentProgressBar.updateCurrentVideoSegmentProgressView(toWidth: currentProgressViewWidth)
        
            perform(#selector(self.updateRecordingValues), with: nil, afterDelay: 0.1)
        }
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
        
        videoSegmentProgressBar.reset()
        
        currentTotalDuration = kCMTimeZero
        
        videoSegments.removeAll()
        
        movieFileOutput.maxRecordedDuration = CMTimeSubtract(maxVideoDuration, currentTotalDuration)
        
        nextBarButtonItem.isEnabled = false
    }
    
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    
    // MARK: - IBActions

    @IBAction func recordVideo(_ sender: UIButton) {
        guard currentTotalDuration <= maxVideoDuration else {
            self.presentAlertController(withTitle: "Max recording duration reached. Click the orange Done button to create your video.")
            return
        }
        
        guard !movieFileOutput.isRecording else { return }
        
        let outputFileName = NSUUID().uuidString
        let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
        movieFileOutput.startRecording(toOutputFileURL: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
    }
    
    @IBAction func stopRecording(_ sender: UIButton) {
        movieFileOutput.stopRecording()
    }
    
    @IBAction func nextButtonTapped(_ sender: UIBarButtonItem) {
        let mixComposition = AVMutableComposition()
        let videoTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeVideo,
                                                        preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        let audioTrack = mixComposition.addMutableTrack(withMediaType: AVMediaTypeAudio,
                                                        preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        
        var totalDuration = kCMTimeZero
        for asset in videoSegments {
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration),
                                               of: asset.tracks(withMediaType: AVMediaTypeVideo)[0] ,
                                               at: totalDuration)
                
                try audioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration),
                                               of: asset.tracks(withMediaType: AVMediaTypeAudio)[0] ,
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
        updateRecordingValues()
    }
    
    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt outputFileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
        
        let videoAsset = AVAsset(url: outputFileURL)
        
        guard Float(CMTimeGetSeconds(videoAsset.duration)) >= 0.3 else {
            print("remove videos that don't pass 1/3 second threshold")
            videoSegmentProgressBar.lastVideoSegmentInvalidated()
            
            return
        }
        
        videoSegments.append(videoAsset)
        currentTotalDuration = CMTimeAdd(currentTotalDuration, videoAsset.duration)
        movieFileOutput.maxRecordedDuration = CMTimeSubtract(maxVideoDuration, currentTotalDuration)
        
        videoSegmentProgressBar.newVideoSegmentProgressView()
        
        nextBarButtonItem.isEnabled = !videoSegments.isEmpty ? true : false
    }
}

//
//  VideoViewController.swift
//  TailVideoClip
//
//  Created by Todd Johnson on 4/21/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import UIKit
import AVFoundation

class VideoViewController: UIViewController {

    @IBOutlet var videoPreview: UIView!
    @IBOutlet var recordButton: UIButton!
    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var deviceInput: AVCaptureDeviceInput!
    var deviceOutput: AVCaptureMovieFileOutput!

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession = AVCaptureSession()
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = videoPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        videoPreview.layer.addSublayer(previewLayer)

        device = getBackCamera()
        do {
            deviceInput = try AVCaptureDeviceInput(device: device)
            captureSession.addInput(deviceInput)
        } catch let error as NSError {
            NSLog("device capture input failed: " + error.localizedDescription)
        }

        deviceOutput = AVCaptureMovieFileOutput()
        captureSession.addOutput(deviceOutput)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) != AVAuthorizationStatus.Authorized {
            let requestComplete: (granted: Bool) -> () = { granted in
                NSLog("access granted: " + granted.description)
            }
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: requestComplete)
        } else {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewDidAppear(animated)

        captureSession.stopRunning()
    }

    @IBAction func closeView(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func toggleRecording(sender: UIButton) {
        if deviceOutput.recording {
            stopRecording()
            recordButton.selected = false
        } else {
            startRecording()
            recordButton.selected = true
        }
    }

    private func startRecording() {
        let path = NSHomeDirectory() + "/Documents/testMovie.mov"
        let url = NSURL(fileURLWithPath: path)
        let fileManager = NSFileManager.defaultManager()
        // delete old backup
        do {
            if fileManager.fileExistsAtPath(path) {
                try fileManager.removeItemAtPath(path)
            }
        } catch let error as NSError {
            // Ignore file not found errors
            if error.code != NSFileNoSuchFileError {
                NSLog("Error removing backup file: \(error)")
            }
        }
        deviceOutput.startRecordingToOutputFileURL(url, recordingDelegate: self)
    }

    private func stopRecording() {
        deviceOutput.stopRecording()
    }

    private func getBackCamera() -> AVCaptureDevice {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]!
        for camera in devices {
            if camera.position == AVCaptureDevicePosition.Back {
                return camera
            }
        }

        return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeVideo)
    }
}

extension VideoViewController: AVCaptureFileOutputRecordingDelegate {
    func captureOutput(captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAtURL outputFileURL: NSURL!, fromConnections connections: [AnyObject]!, error: NSError!) {
        NSLog("movie file written to " + outputFileURL.absoluteString)
        if error != nil {
            NSLog("Error: " + error.localizedDescription)
        }
    }

    func captureOutput(captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAtURL fileURL: NSURL!, fromConnections connections: [AnyObject]!) {
        NSLog("starting movie capture")
    }
}

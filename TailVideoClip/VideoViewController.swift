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
    @IBOutlet var bufferLabel: UILabel!
    @IBOutlet var activityView: UIView!

    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var deviceInput: AVCaptureDeviceInput!
    var dataOutput: AVCaptureVideoDataOutput!

    let maxSeconds = Int32(5)
    let framesPerSecond = Int32(30)
    var maxFrames: Int32 {
        return maxSeconds * framesPerSecond
    }
    var currentFrame = Int32(0)
    var frameBuffer = [UIImage]()
    var capturing = false

    override func viewDidLoad() {
        super.viewDidLoad()

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPreset352x288

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
        let frameTime = CMTimeMake(1, framesPerSecond) // i.e. 30 fps
        var frameRateSupported = false
        let allRanges = device.activeFormat.videoSupportedFrameRateRanges
        for range in allRanges {
            if (CMTimeCompare(frameTime, range.minFrameDuration) != -1)  && (CMTimeCompare(frameTime, range.maxFrameDuration) != 1) {
                frameRateSupported = true
            }
        }
        if frameRateSupported {
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = frameTime
                device.activeVideoMaxFrameDuration = frameTime
                device.unlockForConfiguration()
            } catch let error as NSError {
                NSLog("device lock failed: " + error.localizedDescription)
            }
        }

        dataOutput = AVCaptureVideoDataOutput()
        let queue = dispatch_queue_create("videoDataQueue", DISPATCH_QUEUE_SERIAL)
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        dataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey : NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
        captureSession.addOutput(dataOutput)
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
            currentFrame = 0
            frameBuffer.removeAll()
            bufferLabel.text = "0%"
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewDidAppear(animated)

        captureSession.stopRunning()
    }

    @IBAction func closeView(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func captureRecording(sender: UIButton) {
        activityView.hidden = false
        capturing = true
        var frames: [UIImage]
        if currentFrame > maxFrames {
            let firstFrame = Int(currentFrame - maxFrames)
            frames = Array(frameBuffer[firstFrame..<Int(maxFrames)] + frameBuffer[0..<firstFrame])
        } else {
            frames = frameBuffer
        }
        let path = NSHomeDirectory() + "/Documents/clip.mp4"
        let size = CGSize(width: 352, height: 288)
        VideoBufferWriter.exportMovie(frames, path: path, size: size, fps: framesPerSecond)
        activityView.hidden = true
        capturing = false
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

extension VideoViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        if capturing {
            return
        }
//        NSLog("got new frame: " + currentFrame.description)
        // add until we reach buffer limit, then replace in circular fashion
        if imageFromSampleBuffer(sampleBuffer, frameIndex: currentFrame) {
            currentFrame += 1
            if currentFrame >= maxFrames {
                dispatch_async(dispatch_get_main_queue(), {
                    self.bufferLabel.text = "100%"
                })
            } else {
                let pct = (Float(currentFrame) / Float(maxFrames)) * 100.0
                dispatch_async(dispatch_get_main_queue(), {
                    self.bufferLabel.text = String(format: "%.2f%%", pct)
                })
            }
        }
    }

    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer, frameIndex: Int32) -> Bool {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return false }

        CVPixelBufferLockBaseAddress(imageBuffer, 0)
        let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.NoneSkipFirst.rawValue | CGBitmapInfo.ByteOrder32Little.rawValue
        let context = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, bitmapInfo)
        let quartzImage = CGBitmapContextCreateImage(context)
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0)

        let image = UIImage(CGImage: quartzImage!)
//        let jpg = UIImageJPEGRepresentation(image, 0.9)!
//        NSLog(String(format: "Scaled (%dx%d)image is %d Kbytes", width, height, jpg.length / 1024))

        if currentFrame < maxFrames {
            frameBuffer.append(image)
        } else {
            let frameIndex = currentFrame % maxFrames
            frameBuffer[Int(frameIndex)] = image
        }

        return true
    }
}

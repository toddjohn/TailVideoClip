//
//  VideoBuffer.swift
//  TailVideoClip
//
//  Created by Todd Johnson on 4/26/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import UIKit
import AVFoundation

class VideoBuffer: NSObject {

    var captureSession: AVCaptureSession!
    var device: AVCaptureDevice!
    var deviceInput: AVCaptureDeviceInput!
    var dataOutput: AVCaptureVideoDataOutput!

    var maxSeconds = Int32(5)
    let framesPerSecond = Int32(30)
    var maxFrames: Int32 {
        return maxSeconds * framesPerSecond
    }
    var currentFrame = Int32(0)
    var frameBuffer = [UIImage]()
    var capturing = false

    var bufferSize: ((percent: Int32) -> ())?

    required init(lengthInSeconds seconds: Int32) {
        super.init()

        maxSeconds = seconds

        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPreset352x288

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

    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        return AVCaptureVideoPreviewLayer(session: captureSession)
    }

    func start() {
        captureSession.startRunning()
        currentFrame = 0
        frameBuffer.removeAll()
    }

    func stop() {
        captureSession.stopRunning()
    }

    func save(path: String, completion: ((success: Bool) -> ())?) {
        capturing = true
        var frames: [UIImage]
        if currentFrame > maxFrames {
            let firstFrame = Int(currentFrame % maxFrames)
            frames = Array(frameBuffer[firstFrame..<Int(maxFrames)] + frameBuffer[0..<firstFrame])
        } else {
            frames = frameBuffer
        }
        do {
            let fileManager = NSFileManager.defaultManager()
            if fileManager.fileExistsAtPath(path) {
                try fileManager.removeItemAtPath(path)
            }
        } catch let error as NSError {
            NSLog("Error removing file: " + error.localizedDescription)
        }

        let size = CGSize(width: 288, height: 352)
        let writer = VideoBufferWriter(frames: frames, path: path, size: size, fps: framesPerSecond, orientation: .Portrait)
        writer.exportMovie({ success in
            NSLog("export success: " + success.description)
            dispatch_async(dispatch_get_main_queue(), {
                self.capturing = false
                completion?(success: success)
            })
        })
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

extension VideoBuffer: AVCaptureVideoDataOutputSampleBufferDelegate {
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
                    self.bufferSize?(percent: 100)
                })
            } else {
                let pct = Int32((Float(currentFrame) / Float(maxFrames)) * 100.0)
                dispatch_async(dispatch_get_main_queue(), {
                    self.bufferSize?(percent: pct)
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
        if currentFrame < maxFrames {
            frameBuffer.append(image)
        } else {
            let frameIndex = currentFrame % maxFrames
            frameBuffer[Int(frameIndex)] = image
        }
        
        return true
    }
}

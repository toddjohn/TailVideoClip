//
//  VideoBufferWriter.swift
//  TailVideoClip
//
//  Created by Todd Johnson on 4/25/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

enum VideoOrientation {
    case Portrait
    case Landscape
}

class VideoBufferWriter {

    private var frames: [UIImage]
    private var path: String
    private var size: CGSize
    private var fps: Int32
    private var orientation: VideoOrientation

    required init (frames: [UIImage], path: String, size: CGSize, fps: Int32, orientation: VideoOrientation) {
        self.frames = frames
        self.path = path
        self.size = size
        self.fps = fps
        self.orientation = orientation
    }

    func exportMovie(completion: ((success: Bool) -> ())? ) {
        // Create AVAssetWriter to write video
        guard let assetWriter = createAssetWriter() else {
            NSLog("Error converting images to video: AVAssetWriter not created")
            return
        }

        // If here, AVAssetWriter exists so create AVAssetWriterInputPixelBufferAdaptor
        let writerInput = assetWriter.inputs.filter{ $0.mediaType == AVMediaTypeVideo }.first!
        let sourceBufferAttributes : [String : AnyObject] = [
            kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height,
            ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)

        // Start writing session
        assetWriter.startWriting()
        assetWriter.startSessionAtSourceTime(kCMTimeZero)
        if (pixelBufferAdaptor.pixelBufferPool == nil) {
            NSLog("Error converting images to video: pixelBufferPool nil after starting session. Make sure that the file does not exist on disk.")
            return
        }

        // -- Create queue for <requestMediaDataWhenReadyOnQueue>
        let mediaQueue = dispatch_queue_create("mediaInputQueue", nil)

        // -- Set video parameters
        let frameDuration = CMTimeMake(1, fps)
        var frameCount = 0

        // -- Add images to video
        let numImages = frames.count
        writerInput.requestMediaDataWhenReadyOnQueue(mediaQueue, usingBlock: { () -> Void in
            // Append unadded images to video but only while input ready
            while (writerInput.readyForMoreMediaData && frameCount < numImages) {
                let lastFrameTime = CMTimeMake(Int64(frameCount), self.fps)
                let presentationTime = frameCount == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)

                if !self.appendPixelBufferForImageAtURL(self.frames[frameCount], pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
                    NSLog("Error converting images to video: AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
                    completion?(success: false)
                    return
                }

                frameCount += 1
            }

            // No more images to add? End video.
            if (frameCount >= numImages) {
                writerInput.markAsFinished()
                assetWriter.finishWritingWithCompletionHandler {
                    if (assetWriter.error != nil) {
                        NSLog("Error converting images to video: \(assetWriter.error)")
                        completion?(success: false)
                    } else {
                        NSLog("Converted images to movie @ \(self.path)")
                        completion?(success: true)
                    }
                }
            }
        })
    }

    private func createAssetWriter() -> AVAssetWriter? {
        // Convert <path> to NSURL object
        let pathURL = NSURL(fileURLWithPath: path)

        // Return new asset writer or nil
        do {
            // Create asset writer
            let newWriter = try AVAssetWriter(URL: pathURL, fileType: AVFileTypeMPEG4)

            // Define settings for video input
            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecH264,
                AVVideoWidthKey  : size.width,
                AVVideoHeightKey : size.height,
                ]

            // Add video input to writer
            let assetWriterVideoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoSettings)
            newWriter.addInput(assetWriterVideoInput)

            // Return writer
            NSLog("Created asset writer for \(size.width)x\(size.height) video")
            return newWriter
        } catch {
            NSLog("Error creating asset writer: \(error)")
            return nil
        }
    }
    
    private func appendPixelBufferForImageAtURL(image: UIImage, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false

        autoreleasepool {
            if  let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool {
                let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.alloc(1)
                let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                    kCFAllocatorDefault,
                    pixelBufferPool,
                    pixelBufferPointer
                )

                if let pixelBuffer = pixelBufferPointer.memory where status == 0 {
                    fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
                    appendSucceeded = pixelBufferAdaptor.appendPixelBuffer(pixelBuffer, withPresentationTime: presentationTime)
                    pixelBufferPointer.destroy()
                } else {
                    NSLog("Error: Failed to allocate pixel buffer from pool")
                }
                
                pixelBufferPointer.dealloc(1)
            }
        }
        
        return appendSucceeded
    }

    private func fillPixelBufferFromImage(image: UIImage, pixelBuffer: CVPixelBufferRef) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0)

        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()

        // Create CGBitmapContext
        let context = CGBitmapContextCreate(
            pixelData,
            Int(size.width),
            Int(size.height),
            8,
            CVPixelBufferGetBytesPerRow(pixelBuffer),
            rgbColorSpace,
            CGImageAlphaInfo.PremultipliedFirst.rawValue
        )

        // Draw image into context
        if orientation == .Portrait {
            CGContextTranslateCTM(context, size.width/2, size.height/2)
            CGContextRotateCTM(context, CGFloat(-M_PI/2))
            CGContextTranslateCTM(context, -image.size.width/2, -image.size.height/2)
        }
        CGContextDrawImage(context, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage)
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0)
    }
}

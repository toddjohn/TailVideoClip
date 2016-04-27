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

    var buffer: VideoBuffer!
    var path = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        buffer = VideoBuffer(lengthInSeconds: 5)
        buffer.bufferSize = { percent in
            self.bufferLabel.text = String.init(format: "%d%%", percent)
        }

        let previewLayer = buffer.getPreviewLayer()
        previewLayer.frame = videoPreview.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        videoPreview.layer.addSublayer(previewLayer)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        bufferLabel.text = "0%"
        if AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo) != AVAuthorizationStatus.Authorized {
            let requestComplete: (granted: Bool) -> () = { granted in
                NSLog("access granted: " + granted.description)
                self.buffer.start()
            }
            AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: requestComplete)
        } else {
            buffer.start()
        }
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewDidAppear(animated)

        buffer.stop()
    }

    @IBAction func closeView(sender: UIButton) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func captureRecording(sender: UIButton) {
        activityView.hidden = false
        recordButton.enabled = false
        buffer.save(path, completion: { success in
            self.activityView.hidden = true
            self.recordButton.enabled = true
            if success {
                self.dismissViewControllerAnimated(true, completion: nil)
            }
        })
    }
}

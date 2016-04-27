//
//  ViewController.swift
//  TailVideoClip
//
//  Created by Todd Johnson on 4/21/16.
//  Copyright © 2016 toddjohn. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var videoView: UIView!
    @IBOutlet var playButton: UIButton!
    @IBOutlet var timeSlider: UISlider!
    var videoLayer: AVPlayerLayer?
    var player: AVPlayer?
    var refreshPlayer = false
    var restartClock = false
    var duration = CMTimeMake(0, 1)
    var observerToken: AnyObject?
    var outputPath: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        outputPath = NSHomeDirectory() + "/Documents/clip.mp4"
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        if refreshPlayer {
            timeSlider.value = 0
            playButton.selected = false
            let url = NSURL(fileURLWithPath: outputPath)
            let asset = AVAsset(URL: url)
            let item = AVPlayerItem(asset: asset)
            if player != nil {
                NSNotificationCenter.defaultCenter().removeObserver(self)
                player?.replaceCurrentItemWithPlayerItem(item)
            } else {
                player = AVPlayer(playerItem: item)
                observerToken = player?.addPeriodicTimeObserverForInterval(CMTimeMake(1, 10), queue: nil, usingBlock: { currentTime in
                    self.updateSlider(currentTime)
                })
            }
            duration = item.duration
            NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.videoEnded(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: item)
            if videoLayer == nil {
                videoLayer = AVPlayerLayer(player: player)
                videoLayer?.frame = videoView.bounds
                videoView.layer.addSublayer(videoLayer!)
            }
            refreshPlayer = false
        }
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vvc = segue.destinationViewController as? VideoViewController {
            refreshPlayer = true
            vvc.path = outputPath
        }
    }

    @IBAction func playPause(sender: UIButton) {
        if sender.selected {
            player?.pause()
            sender.selected = false
        } else {
            if restartClock {
                restartClock = false
                player?.seekToTime(CMTimeMake(0, 1))
            }
            player?.play()
            sender.selected = true
        }
    }

    @IBAction func sliderChanged(sender: UISlider) {
        restartClock = false
        let time = CMTimeMultiplyByFloat64(duration, Float64(sender.value))
        if CMTIME_IS_VALID(time) && !CMTIME_IS_INDEFINITE(time) {
            let tolerance = CMTimeMake(1, 10)
            player?.seekToTime(time, toleranceBefore: tolerance, toleranceAfter: tolerance)
        } else {
            if player?.currentItem?.status == .ReadyToPlay {
                if let itemDuration = player?.currentItem?.duration {
                    duration = itemDuration
                }
            }
        }
    }

    func videoEnded(notification: NSNotification) {
        playButton.selected = false
        restartClock = true
    }

    func updateSlider(currentTime: CMTime) {
        if CMTIME_IS_VALID(duration) && !CMTIME_IS_INDEFINITE(duration) {
            let totalSeconds = CMTimeGetSeconds(duration)
            let currentSeconds = CMTimeGetSeconds(currentTime)
            let value = Float(currentSeconds / totalSeconds)
            timeSlider.value = value
        } else {
            if player?.currentItem?.status == .ReadyToPlay {
                if let itemDuration = player?.currentItem?.duration {
                    duration = itemDuration
                }
            }
        }
    }
}


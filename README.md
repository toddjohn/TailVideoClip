# TailVideoClip

This sample app will stream video from the camera into a buffer of UIImages. The 5 second buffer can then be exported to an mp4 video file.

## VideoBuffer

This class collects the sample buffers from the video capture, converts them to UIImages, and stores them in a circular buffer. The video capture is hardcoded to 352x288 because it is the smallest. (Typical size of a single UIImage from the sample buffer is between 10kb and 30kb.) Using a larger source will dramatically increase memory usage and ultimately crash the app. Writing the images to storage takes far too long to be useful. The bottom line is that this class only works for small video sizes of short duration.

## VideoBufferWriter

This class is largely take from StackOverflow answers on how to convert an array of UIImages to a video file. It can support either portrait or landscape. (The default video capture is in landscape, so portrait requires a 90 degree rotation.)

## VideoViewController

This view controller has a preview of the capture session, and allows the user to save the current buffer in a video file.

## ViewController 

This view controller can playback a captured video, and includes a scrub bar to scroll through the playback manually.

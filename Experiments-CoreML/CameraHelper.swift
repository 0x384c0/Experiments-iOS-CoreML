//
//  CameraHelper.swift
//  Experiments-CoreML
//
//  Created by 0x384c0 on 10/25/18.
//  Copyright © 2018 0x384c0. All rights reserved.
//

import AVFoundation
import UIKit

class CameraHelper: NSObject{
    var session = AVCaptureSession()
    let layer = AVSampleBufferDisplayLayer()
    let sampleQueue = DispatchQueue(label: "CameraHelper.sampleQueue", attributes: [])
    
    func openSession() -> Bool {
        let deviceMaybe = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        
        guard let device = deviceMaybe else {
            return false
        }
        let input = try! AVCaptureDeviceInput(device: device)
        
        
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        
        session.beginConfiguration()
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        let settings: [AnyHashable: Any] = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
        output.videoSettings = settings as? [String : Any]
        
        
        session.startRunning()
        
        return true
    }
}


extension CameraHelper : AVCaptureVideoDataOutputSampleBufferDelegate{
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        connection.videoOrientation = .portrait
        layer.enqueue(sampleBuffer)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("didDrop sampleBuffer")
    }
}

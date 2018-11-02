//
//  ImageHelper.swift
//  Experiments-CoreML
//
//  Created by 0x384c0 on 10/26/18.
//  Copyright © 2018 0x384c0. All rights reserved.
//

import UIKit

class ImageHelper{
    static func resize(pixelBuffer:CVPixelBuffer, to newSize:CGSize) -> CVPixelBuffer?{
        return
            UIImage(pixelBuffer: pixelBuffer)?
                .pixelBuffer(width: Int(newSize.width), height: Int(newSize.height))
    }
}



import VideoToolbox
extension UIImage {
    public convenience init?(pixelBuffer: CVPixelBuffer) {
        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        
        if let cgImage = cgImage {
            self.init(cgImage: cgImage)
        } else {
            return nil
        }
    }
    
    public func pixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var maybePixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32ARGB,
                                         attrs as CFDictionary,
                                         &maybePixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = maybePixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        guard let context = CGContext(data: pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
            else {
                return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
}

extension CVPixelBuffer{
    func transform(transform:CGAffineTransform) -> CVPixelBuffer{
        let finalImage = CIImage(cvPixelBuffer: self).transformed(by: transform)
        let pixelBuffer = finalImage.getPixelBuffer()!
        return pixelBuffer
    }
}

extension CIImage{
    func getPixelBuffer() -> CVPixelBuffer?{
        let ctx = CIContext()
        if let cgImage = ctx.createCGImage(self, from: self.extent){
            let uiImage = UIImage(cgImage: cgImage)
            if let buffer = uiImage.pixelBuffer(width: Int(uiImage.size.width), height: Int(uiImage.size.height)){
                return buffer
            }
        }
        return nil
    }
}

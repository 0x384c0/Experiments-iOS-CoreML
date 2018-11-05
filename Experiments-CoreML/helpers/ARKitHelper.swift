//
//  ARKitHelper.swift
//  Experiments-CoreML
//
//  Created by 0x384c0 on 11/2/18.
//  Copyright © 2018 0x384c0. All rights reserved.
//

import SceneKit
import ARKit

@available(iOS 11.0, *)
class ARKitHelper:NSObject{
    
    //MARK: basic camera functions
    var didOutputHandler:((CVPixelBuffer)->())?
    func setup(sceneView: ARSCNView){
        self.sceneView = sceneView
        
        orient = UIApplication.shared.statusBarOrientation
        viewportSize = sceneView.bounds.size
        
        sceneView.delegate = self
        sceneView.scene = SCNScene()
        sceneView.autoenablesDefaultLighting = true
        sceneView.preferredFramesPerSecond = 30
    }
    func start(){
        addObservers()
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 11.3, *){
            configuration.planeDetection = [.horizontal,.vertical]
        } else {
            configuration.planeDetection = .horizontal
        }
        sceneView.session.run(configuration)
    }
    func stop(){
        removeObservers()
        sceneView.session.pause()
    }
    
    //MARK: ARKit functions
    private(set) var transform:CGAffineTransform!
    var showsStatistics:Bool{
        get{ return sceneView.showsStatistics }
        set{
            sceneView.showsStatistics = newValue
            sceneView.debugOptions = newValue ? [.showFeaturePoints] : []
        }
    }
    var planeFoundHandler:(()->())?
    
    //MARK: private
    private weak var sceneView:ARSCNView!
    private let bubbleDepth : Float = 0.01 // the 'depth' of 3D text
    private var
    orient:UIInterfaceOrientation!,
    viewportSize:CGSize!
    
    private func addObservers(){
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged), name: ProcessInfo.thermalStateDidChangeNotification,    object: nil)
    }
    private func removeObservers(){
        NotificationCenter.default.removeObserver(self)
    }
    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            switch processInfo.thermalState{
            case .nominal:
                print("thermalStateChanged nominal")
            case .fair:
                print("thermalStateChanged fair")
            case .serious:
                print("thermalStateChanged serious")
            case .critical:
                print("thermalStateChanged critical")
            }
        }
    }
    deinit {
        removeObservers()
    }
}

@available(iOS 11.0, *)
extension ARKitHelper:ARSCNViewDelegate{
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let pixelBuffer = sceneView.session.currentFrame?.capturedImage{
            if (transform == nil){
                transform = sceneView.session.currentFrame?.displayTransform(for: orient, viewportSize: viewportSize).inverted()
            }
            didOutputHandler?(pixelBuffer)
        }
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async { self.planeFoundHandler?() }
        if (self.showsStatistics){
            guard let planeAnchor = anchor as? ARPlaneAnchor else {preconditionFailure("could not get planeAnchor")}
            print("anchor:\(anchor), node: \(node), node geometry: \(String(describing: node.geometry))")
            
            let geometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                    height: CGFloat(planeAnchor.extent.z))
            geometry.materials.first?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.5)
            
            let planeNode = SCNNode(geometry: geometry)
            planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
            
            DispatchQueue.main.async(execute: {
                node.addChildNode(planeNode)
            })
        }
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            print("trackingState normal")
        case .limited(.initializing):
            print("trackingState limited initializing")
        case .limited(.excessiveMotion):
            print("trackingState limited excessiveMotion")
        case .limited(.insufficientFeatures):
            print("trackingState limited insufficientFeatures")
        case .limited(.relocalizing):
            print("trackingState limited relocalizing")
        case .notAvailable:
            print("trackingState notAvailable")
        }
    }
}

@available(iOS 11.0, *)
extension ARKitHelper{
    func addLabel(text:String){
        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
        if let closestResult = arHitTestResults.first {
            // Get Coordinates of HitTest
            let transform : matrix_float4x4 = closestResult.worldTransform
            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            // Create 3D Text
            let node : SCNNode = createNewBubbleParentNode(text)
            sceneView.scene.rootNode.addChildNode(node)
            node.position = worldCoord
        }
    }
    
    private func createNewBubbleParentNode(_ text : String) -> SCNNode {
        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
        
        // TEXT BILLBOARD CONSTRAINT
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = SCNBillboardAxis.Y
        
        // BUBBLE-TEXT
        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
        var font = UIFont(name: "Futura", size: 0.15)
        font = font?.withTraits(traits: .traitBold)
        bubble.font = font
        bubble.alignmentMode = CATextLayerAlignmentMode.center.rawValue
        bubble.firstMaterial?.diffuse.contents = UIColor.orange
        bubble.firstMaterial?.specular.contents = UIColor.white
        bubble.firstMaterial?.isDoubleSided = true
        // bubble.flatness // setting this too low can cause crashes.
        bubble.chamferRadius = CGFloat(bubbleDepth)
        
        // BUBBLE NODE
        let (minBound, maxBound) = bubble.boundingBox
        let bubbleNode = SCNNode(geometry: bubble)
        // Centre Node - to Centre-Bottom point
        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
        // Reduce default text size
        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
        
        // CENTRE POINT NODE
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
        let sphereNode = SCNNode(geometry: sphere)
        
        // BUBBLE PARENT NODE
        let bubbleNodeParent = SCNNode()
        bubbleNodeParent.addChildNode(bubbleNode)
        bubbleNodeParent.addChildNode(sphereNode)
        bubbleNodeParent.constraints = [billboardConstraint]
        
        return bubbleNodeParent
    }
}


extension UIFont {
    // Based on: https://stackoverflow.com/questions/4713236/how-do-i-set-bold-and-italic-on-uilabel-of-iphone-ipad
    func withTraits(traits:UIFontDescriptor.SymbolicTraits...) -> UIFont {
        let descriptor = self.fontDescriptor.withSymbolicTraits(UIFontDescriptor.SymbolicTraits(traits))
        return UIFont(descriptor: descriptor!, size: 0)
    }
}

import UIKit
import SceneKit
import ARKit

// MARK: - VisualizationManager
class VisualizationManager {
    
    private let sceneView: ARSCNView
    
    // Visual elements
    private var planeNodes: [UUID: SCNNode] = [:]
    private var featurePointNodes: Set<SCNNode> = []
    private var debugText: SCNNode?
    
    // Configuration
    private let maxFeaturePoints = 500
    private let featurePointSize: CGFloat = 0.005 // 5mm
    
    init(sceneView: ARSCNView) {
        self.sceneView = sceneView
    }
    
    // MARK: - Plane Visualization
    func createPlaneNode(for anchor: ARPlaneAnchor, type: TerrainType) -> SCNNode {
        // Create a node to visualize the plane
        let planeNode = SCNNode()
        
        // Create plane geometry
        let planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        // Create plane visualization with appropriate color and opacity
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = type.color
        planeMaterial.isDoubleSided = true
        planeGeometry.materials = [planeMaterial]
        
        // Create child node with the geometry
        let planeGeometryNode = SCNNode(geometry: planeGeometry)
        planeGeometryNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        planeGeometryNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        planeGeometryNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        
        // Add plane visualization to the parent node
        planeNode.addChildNode(planeGeometryNode)
        
        return planeNode
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor, type: TerrainType) {
        guard let planeGeometryNode = node.childNodes.first,
              let planeGeometry = planeGeometryNode.geometry as? SCNPlane else {
            return
        }
        
        // Update the geometry to match the anchor
        planeGeometry.width = CGFloat(anchor.extent.x)
        planeGeometry.height = CGFloat(anchor.extent.z)
        planeGeometryNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        // Update material if needed
        if let material = planeGeometry.materials.first {
            material.diffuse.contents = type.color
        }
    }
    
    func addPlaneNode(for anchor: ARPlaneAnchor, type: TerrainType, to node: SCNNode) {
        let planeNode = createPlaneNode(for: anchor, type: type)
        node.addChildNode(planeNode)
        planeNodes[anchor.identifier] = planeNode
    }
    
    func updatePlaneNode(for anchor: ARPlaneAnchor, type: TerrainType) {
        guard let planeNode = planeNodes[anchor.identifier] else { return }
        updatePlaneNode(planeNode, for: anchor, type: type)
    }
    
    func removePlaneNode(for anchor: ARPlaneAnchor) {
        guard let planeNode = planeNodes[anchor.identifier] else { return }
        planeNode.removeFromParentNode()
        planeNodes.removeValue(forKey: anchor.identifier)
    }
    
    // MARK: - Feature Points Visualization
    func updateFeaturePoints(_ points: [SCNVector3], type: TerrainType) {
        // Remove all existing feature point nodes
        for node in featurePointNodes {
            node.removeFromParentNode()
        }
        featurePointNodes.removeAll()
        
        // Limit the number of feature points to avoid overloading the scene
        let pointsToShow = points.count > maxFeaturePoints ? Array(points.prefix(maxFeaturePoints)) : points
        
        // Create new feature point nodes
        for point in pointsToShow {
            let pointNode = createFeaturePointNode(at: point, type: type)
            sceneView.scene.rootNode.addChildNode(pointNode)
            featurePointNodes.insert(pointNode)
        }
    }
    
    private func createFeaturePointNode(at position: SCNVector3, type: TerrainType) -> SCNNode {
        let sphere = SCNSphere(radius: featurePointSize)
        sphere.firstMaterial?.diffuse.contents = type.color
                
                let node = SCNNode(geometry: sphere)
                node.position = position
                
                return node
            }
            
            // MARK: - Debug Text
            func showDebugText(_ text: String, at position: SCNVector3) {
                // Remove existing debug text node
                debugText?.removeFromParentNode()
                
                // Create a new text geometry
                let textGeometry = SCNText(string: text, extrusionDepth: 0.001)
                textGeometry.font = UIFont.systemFont(ofSize: 0.02)
                textGeometry.firstMaterial?.diffuse.contents = UIColor.white
                
                // Calculate the bounds of the text
                let (min, max) = textGeometry.boundingBox
                let width = max.x - min.x
                
                // Create a node with the text geometry
                let textNode = SCNNode(geometry: textGeometry)
                textNode.position = SCNVector3(position.x - width / 2, position.y + 0.05, position.z)
                textNode.scale = SCNVector3(0.01, 0.01, 0.01)
                
                // Add to scene and save reference
                sceneView.scene.rootNode.addChildNode(textNode)
                debugText = textNode
            }
            
            // MARK: - Cleanup
            func reset() {
                // Remove all visualizations
                for (_, node) in planeNodes {
                    node.removeFromParentNode()
                }
                planeNodes.removeAll()
                
                for node in featurePointNodes {
                    node.removeFromParentNode()
                }
                featurePointNodes.removeAll()
                
                debugText?.removeFromParentNode()
                debugText = nil
            }
        }

import UIKit
import ARKit
import SceneKit

// MARK: - TerrainType Enum
enum TerrainType: Int {
    case traversable = 0
    case caution = 1
    case nonTraversable = 2
    
    var color: UIColor {
        switch self {
        case .traversable:
            return UIColor.green.withAlphaComponent(0.7)
        case .caution:
            return UIColor.yellow.withAlphaComponent(0.7)
        case .nonTraversable:
            return UIColor.red.withAlphaComponent(0.7)
        }
    }
}

// MARK: - VoxelNode
class VoxelNode: SCNNode {
    var voxelType: TerrainType = .traversable
    
    init(type: TerrainType, size: CGFloat) {
        super.init()
        self.voxelType = type
        
        let box = SCNBox(width: size, height: size, length: size, chamferRadius: 0.0)
        box.firstMaterial?.diffuse.contents = type.color
        box.firstMaterial?.transparency = 0.7
        
        self.geometry = box
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - VoxelGridManager
class VoxelGridManager {
    private var voxelSize: CGFloat = 0.05
    private var gridSize: (x: Int, y: Int, z: Int) = (20, 10, 20)
    private var voxelGrid: [[[VoxelNode?]]] = []
    private var scene: SCNScene
    
    init(scene: SCNScene, voxelSize: CGFloat = 0.05) {
        self.scene = scene
        self.voxelSize = voxelSize
        
        // Initialize empty voxel grid
        initializeGrid()
    }
    
    private func initializeGrid() {
        voxelGrid = Array(repeating: Array(repeating: Array(repeating: nil, count: gridSize.z), count: gridSize.y), count: gridSize.x)
    }
    
    func updateVoxel(at position: SCNVector3, type: TerrainType) {
        let indices = worldPositionToGridIndices(position)
        guard isValidIndices(indices) else { return }
        
        if let existingVoxel = voxelGrid[indices.x][indices.y][indices.z] {
            // Update existing voxel
            if existingVoxel.voxelType != type {
                existingVoxel.removeFromParentNode()
                createVoxel(at: position, type: type, indices: indices)
            }
        } else {
            // Create new voxel
            createVoxel(at: position, type: type, indices: indices)
        }
    }
    
    private func createVoxel(at position: SCNVector3, type: TerrainType, indices: (x: Int, y: Int, z: Int)) {
        let voxel = VoxelNode(type: type, size: voxelSize)
        voxel.position = position
        scene.rootNode.addChildNode(voxel)
        voxelGrid[indices.x][indices.y][indices.z] = voxel
    }
    
    func removeVoxel(at position: SCNVector3) {
        let indices = worldPositionToGridIndices(position)
        guard isValidIndices(indices) else { return }
        
        if let voxel = voxelGrid[indices.x][indices.y][indices.z] {
            voxel.removeFromParentNode()
            voxelGrid[indices.x][indices.y][indices.z] = nil
        }
    }
    
    func getTerrainType(at position: SCNVector3) -> TerrainType? {
        let indices = worldPositionToGridIndices(position)
        guard isValidIndices(indices) else { return nil }
        
        return voxelGrid[indices.x][indices.y][indices.z]?.voxelType
    }
    
    private func worldPositionToGridIndices(_ position: SCNVector3) -> (x: Int, y: Int, z: Int) {
        // Convert world position to grid indices
        let halfX = CGFloat(gridSize.x) * voxelSize / 2
        let halfY = CGFloat(gridSize.y) * voxelSize / 2
        let halfZ = CGFloat(gridSize.z) * voxelSize / 2
        
        let x = Int((CGFloat(position.x) + halfX) / voxelSize)
        let y = Int((CGFloat(position.y) + halfY) / voxelSize)
        let z = Int((CGFloat(position.z) + halfZ) / voxelSize)
        
        return (x, y, z)
    }
    
    private func isValidIndices(_ indices: (x: Int, y: Int, z: Int)) -> Bool {
        return indices.x >= 0 && indices.x < gridSize.x &&
               indices.y >= 0 && indices.y < gridSize.y &&
               indices.z >= 0 && indices.z < gridSize.z
    }
    
    func reset() {
        // Remove all voxels from scene
        for x in 0..<gridSize.x {
            for y in 0..<gridSize.y {
                for z in 0..<gridSize.z {
                    if let voxel = voxelGrid[x][y][z] {
                        voxel.removeFromParentNode()
                    }
                }
            }
        }
        
        // Reinitialize grid
        initializeGrid()
    }
}

// MARK: - TerrainAnalyzer
class TerrainAnalyzer {
    enum ObstacleSize {
        case small
        case large
    }
    
    // Configuration parameters
    private let maxTraversableSlopeDegrees: Float = 20.0
    private let maxSmallObstacleHeight: Float = 0.05  // 5cm
    private let minLargeObstacleHeight: Float = 0.20  // 20cm
    
    func classifyTerrain(pointCloud: [SCNVector3], referenceNormal: SCNVector3) -> [SCNVector3: TerrainType] {
        var classification: [SCNVector3: TerrainType] = [:]
        
        // Group points into clusters for analysis
        let clusters = clusterPoints(pointCloud)
        
        for cluster in clusters {
            // Calculate the normal of the cluster
            if let normal = calculateNormal(for: cluster) {
                // Check slope by comparing with reference normal (usually up vector)
                let slopeAngle = angleBetweenVectors(normal, referenceNormal)
                
                if slopeAngle > maxTraversableSlopeDegrees {
                    // Too steep - mark as non-traversable
                    for point in cluster {
                        classification[point] = .nonTraversable
                    }
                } else {
                    // Check for obstacles
                    let heightVariation = calculateHeightVariation(in: cluster)
                    
                    if heightVariation < maxSmallObstacleHeight {
                        // Smooth terrain - traversable
                        for point in cluster {
                            classification[point] = .traversable
                        }
                    } else if heightVariation < minLargeObstacleHeight {
                        // Small obstacle - caution
                        for point in cluster {
                            classification[point] = .caution
                        }
                    } else {
                        // Large obstacle - non-traversable
                        for point in cluster {
                            classification[point] = .nonTraversable
                        }
                    }
                }
            }
        }
        
        return classification
    }
    
    private func clusterPoints(_ points: [SCNVector3]) -> [[SCNVector3]] {
        // Simple clustering by grid cells
        let gridSize: Float = 0.1 // 10cm grid
        var clusters: [String: [SCNVector3]] = [:]
        
        for point in points {
            // Create a grid cell key
            let cellX = Int(point.x / gridSize)
            let cellZ = Int(point.z / gridSize)
            let key = "\(cellX),\(cellZ)"
            
            if clusters[key] == nil {
                clusters[key] = []
            }
            clusters[key]?.append(point)
        }
        
        return Array(clusters.values)
    }
    
    private func calculateNormal(for points: [SCNVector3]) -> SCNVector3? {
        guard points.count >= 3 else { return nil }
        
        // Use the first three points to determine a plane
        let a = points[0]
        let b = points[1]
        let c = points[2]
        
        // Calculate vectors on the plane
        let ab = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let ac = SCNVector3(c.x - a.x, c.y - a.y, c.z - a.z)
        
        // Cross product gives the normal
        let normal = SCNVector3(
            ab.y * ac.z - ab.z * ac.y,
            ab.z * ac.x - ab.x * ac.z,
            ab.x * ac.y - ab.y * ac.x
        )
        
        // Normalize
        let length = sqrt(normal.x * normal.x + normal.y * normal.y + normal.z * normal.z)
        guard length > 0 else { return nil }
        
        return SCNVector3(normal.x / length, normal.y / length, normal.z / length)
    }
    
    func angleBetweenVectors(_ v1: SCNVector3, _ v2: SCNVector3) -> Float {
        // Calculate the angle between two vectors in degrees
        let dotProduct = v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
        let length1 = sqrt(v1.x * v1.x + v1.y * v1.y + v1.z * v1.z)
        let length2 = sqrt(v2.x * v2.x + v2.y * v2.y + v2.z * v2.z)
        
        let cosAngle = dotProduct / (length1 * length2)
        let angle = acos(min(max(cosAngle, -1.0), 1.0))
        
        return angle * (180.0 / Float.pi)
    }
    
    private func calculateHeightVariation(in points: [SCNVector3]) -> Float {
        // Find height range in the cluster
        guard !points.isEmpty else { return 0 }
        
        var minHeight = points[0].y
        var maxHeight = points[0].y
        
        for point in points {
            minHeight = min(minHeight, point.y)
            maxHeight = max(maxHeight, point.y)
        }
        
        return maxHeight - minHeight
    }
    
    func identifyObstacleSize(heightVariation: Float) -> ObstacleSize {
        return heightVariation >= minLargeObstacleHeight ? .large : .small
    }
}

// MARK: - ViewController
class ViewController: UIViewController, ARSCNViewDelegate {
    
    // MARK: - Properties
    var sceneView: ARSCNView!
    var statusLabel: UILabel!
    private var scanButton: UIButton!
    private var resetButton: UIButton!
    
    private var voxelGridManager: VoxelGridManager!
    private var terrainAnalyzer = TerrainAnalyzer()
    private var pointCloud: [SCNVector3] = []
    private var isScanning = false
    private var scanTimer: Timer?
    private let scanFrequency: TimeInterval = 0.5 // Scan every 0.5 seconds
    
    // Add voxelSize constant
    private let voxelSize: CGFloat = 0.05
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup UI
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        if #available(iOS 13.4, *) {
            // Use Scene Reconstruction if available (LiDAR devices)
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
        }
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Start automatic scanning
        startScanningTerrain()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        // Stop scanning
        stopScanningTerrain()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Create ARSCNView
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sceneView)
        
        // Set up the scene
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = [.showFeaturePoints]
        
        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Initialize the voxel grid manager
        voxelGridManager = VoxelGridManager(scene: scene, voxelSize: voxelSize)
        
        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        
        // Create status label
        statusLabel = UILabel(frame: CGRect(x: 20, y: 50, width: view.frame.width - 40, height: 80))
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = .white
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        statusLabel.layer.cornerRadius = 10
        statusLabel.layer.masksToBounds = true
        view.addSubview(statusLabel)
        
        // Create scan button
        scanButton = UIButton(type: .system)
        scanButton.frame = CGRect(x: 20, y: view.frame.height - 80, width: (view.frame.width - 60) / 2, height: 50)
        scanButton.setTitle("Scan Terrain", for: .normal)
        scanButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 10
        scanButton.addTarget(self, action: #selector(toggleScanning), for: .touchUpInside)
        view.addSubview(scanButton)
        
        // Create reset button
        resetButton = UIButton(type: .system)
        resetButton.frame = CGRect(x: scanButton.frame.maxX + 20, y: view.frame.height - 80, width: (view.frame.width - 60) / 2, height: 50)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.layer.cornerRadius = 10
        resetButton.addTarget(self, action: #selector(resetVoxelGrid), for: .touchUpInside)
        view.addSubview(resetButton)
        
        updateStatusLabel("Ready to scan terrain. Tap to analyze specific points.")
    }
    
    // MARK: - Scanning Methods
    @objc private func toggleScanning() {
        if isScanning {
            stopScanningTerrain()
        } else {
            startScanningTerrain()
        }
    }
    
    private func startScanningTerrain() {
        guard !isScanning else { return }
        
        isScanning = true
        scanTimer = Timer.scheduledTimer(timeInterval: scanFrequency, target: self, selector: #selector(scanTerrainFrame), userInfo: nil, repeats: true)
        updateStatusLabel("Scanning terrain... (Green: Traversable, Yellow: Caution, Red: Non-traversable)")
    }
    
    private func stopScanningTerrain() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
        updateStatusLabel("Scanning paused. Tap to analyze specific points.")
    }
    
    @objc private func scanTerrainFrame() {
        // Get current frame points
        guard let frame = sceneView.session.currentFrame else { return }
        
        // Process feature points
        if let points = getFeaturePoints() {
            analyzeTerrainPoints(points)
        }
        
        // Process detected planes
        analyzePlanes()
    }
    
    private func getFeaturePoints() -> [SCNVector3]? {
        guard let pointCloud = sceneView.session.currentFrame?.rawFeaturePoints else { return nil }
        
        return pointCloud.points.map { point in
            SCNVector3(point.x, point.y, point.z)
        }
    }
    
    private func analyzeTerrainPoints(_ points: [SCNVector3]) {
        // Reference normal vector (up direction)
        let referenceNormal = SCNVector3(0, 1, 0)
        
        // Classify terrain
        let classification = terrainAnalyzer.classifyTerrain(pointCloud: points, referenceNormal: referenceNormal)
        
        // Update voxel grid
        for (point, terrainType) in classification {
            voxelGridManager.updateVoxel(at: point, type: terrainType)
        }
    }
    
    private func analyzePlanes() {
        // Get anchors from the scene
        guard let anchors = sceneView.session.currentFrame?.anchors else { return }
        
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                // Process detected plane
                analyzePlane(planeAnchor)
            }
        }
    }
    
    private func analyzePlane(_ planeAnchor: ARPlaneAnchor) {
        // Determine terrain type based on plane orientation and geometry
        let terrainType: TerrainType
        
        // Check plane orientation (horizontal vs. vertical)
        let normal = SCNVector3(planeAnchor.transform.columns.2.x,
                               planeAnchor.transform.columns.2.y,
                               planeAnchor.transform.columns.2.z)
        
        let angleWithHorizontal = terrainAnalyzer.angleBetweenVectors(normal, SCNVector3(0, 1, 0))
        
        if angleWithHorizontal < 20 {
            // Mostly horizontal plane - likely traversable
            terrainType = .traversable
        } else if angleWithHorizontal > 70 {
            // Mostly vertical plane - likely non-traversable (wall)
            terrainType = .nonTraversable
        } else {
            // Sloped plane - caution
            terrainType = .caution
        }
        
        // Generate voxels for the plane
        generateVoxelsForPlane(planeAnchor, terrainType: terrainType)
    }
    
    private func generateVoxelsForPlane(_ planeAnchor: ARPlaneAnchor, terrainType: TerrainType) {
        // Create voxels across the plane extent
        let center = SCNVector3(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z)
        let extent = planeAnchor.extent
        
        // Determine voxel placement step size
        let stepsX = Int(Float(extent.x) / Float(voxelSize))
        let stepsZ = Int(Float(extent.z) / Float(voxelSize))
        
        // Generate grid of voxels
        for x in -stepsX/2...stepsX/2 {
            for z in -stepsZ/2...stepsZ/2 {
                let xPos = center.x + Float(x) * Float(voxelSize)
                let zPos = center.z + Float(z) * Float(voxelSize)
                let position = SCNVector3(xPos, center.y, zPos)
                
                // Create voxel at this position
                voxelGridManager.updateVoxel(at: position, type: terrainType)
            }
        }
    }
    
    // MARK: - User Interaction
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        // Get tap location
        let tapLocation = gestureRecognizer.location(in: sceneView)
        
        // Perform hit test with feature points
        let hitTestResults = sceneView.hitTest(tapLocation, types: .featurePoint)
        
        // Check if we hit a feature point
        if let hitResult = hitTestResults.first {
            let hitPoint = SCNVector3(
                x: hitResult.worldTransform.columns.3.x,
                y: hitResult.worldTransform.columns.3.y,
                z: hitResult.worldTransform.columns.3.z
            )
            
            // Analyze a small region around the tap point
            analyzeRegionAroundPoint(hitPoint)
        }
    }
    
    private func analyzeRegionAroundPoint(_ center: SCNVector3) {
        // Create a sample of points around the center point
        var pointsToAnalyze: [SCNVector3] = []
        let radius: Float = 0.1 // 10cm radius
        let density: Int = 10 // Number of points to generate
        
        for _ in 0..<density {
            // Generate random offset within radius
            let dx = Float.random(in: -radius...radius)
            let dz = Float.random(in: -radius...radius)
            let point = SCNVector3(center.x + dx, center.y, center.z + dz)
            pointsToAnalyze.append(point)
        }
        
        // Add the center point
        pointsToAnalyze.append(center)
        
        // Analyze this small point cloud
        analyzeTerrainPoints(pointsToAnalyze)
        
        // Show analysis result
        updateStatusLabel("Point analyzed. Tap other areas to analyze them.")
    }
    
    @objc private func resetVoxelGrid() {
        voxelGridManager.reset()
        updateStatusLabel("Voxel grid reset. Ready to scan terrain again.")
    }
    
    private func updateStatusLabel(_ message: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = message
        }
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Called for every frame
        
        // Update pointCloud if needed
        if isScanning, let points = getFeaturePoints() {
            // Only update if we have significant new points
            if points.count > self.pointCloud.count + 100 || time.truncatingRemainder(dividingBy: 1.0) < 0.1 {
                self.pointCloud = points
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Handle newly added anchors
        if let planeAnchor = anchor as? ARPlaneAnchor {
            // New plane detected
            analyzePlane(planeAnchor)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Handle updated anchors
        if let planeAnchor = anchor as? ARPlaneAnchor {
            // Plane updated with new information
            analyzePlane(planeAnchor)
        }
    }
    
    // MARK: - Error Handling
    func session(_ session: ARSession, didFailWithError error: Error) {
        updateStatusLabel("AR Session Failed: \(error.localizedDescription)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        updateStatusLabel("AR Session Interrupted")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        updateStatusLabel("AR Session Resumed")
        resetVoxelGrid()
    }
}

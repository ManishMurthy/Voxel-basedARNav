import SceneKit

// MARK: - SCNVector3 Extension
extension SCNVector3 {
    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
    }
    
    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        return SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
    }
    
    static func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
    
    static func / (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        return SCNVector3(vector.x / scalar, vector.y / scalar, vector.z / scalar)
    }
    
    func length() -> Float {
        return sqrt(x*x + y*y + z*z)
    }
    
    func distance(to vector: SCNVector3) -> Float {
        return (self - vector).length()
    }
    
    func normalized() -> SCNVector3 {
        let len = length()
        if len == 0 {
            return self
        }
        return self / len
    }
    
    func dot(_ vector: SCNVector3) -> Float {
        return x * vector.x + y * vector.y + z * vector.z
    }
    
    func cross(_ vector: SCNVector3) -> SCNVector3 {
        return SCNVector3(
            y * vector.z - z * vector.y,
            z * vector.x - x * vector.z,
            x * vector.y - y * vector.x
        )
    }
}

// MARK: - SCNVector3 Hashable Conformance
extension SCNVector3: Hashable {
    public static func == (lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }
}

// MARK: - Float Extension
extension Float {
    func degreesToRadians() -> Float {
        return self * .pi / 180.0
    }
    
    func radiansToDegrees() -> Float {
        return self * 180.0 / .pi
    }
}

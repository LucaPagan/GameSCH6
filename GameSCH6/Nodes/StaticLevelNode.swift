import SpriteKit

// MARK: - Static Level Node

/// A node that loads a pre-designed level section from a SpriteKit Scene file (.sks).
/// This allows the user to design "modules" using Xcode's drag-and-drop Scene Editor.
class StaticLevelNode: SKNode {
    
    /// Load a level section by its file name (without extension).
    /// - Parameter fileName: The name of the .sks file in the main bundle.
    init(fileNamed fileName: String) {
        super.init()
        
        // Attempt to load the scene
        if let template = SKReferenceNode(fileNamed: fileName) {
            // Add as reference or flatten children
            addChild(template)
            
            // Optional: iterate through children to assign physics if not set in editor
            template.enumerateChildNodes(withName: "//*") { node, _ in
                // Custom logic for nodes with specific names can go here
                if node.name?.contains("platform") == true {
                    // Pre-process any nodes manually if needed
                }
            }
        } else {
            print("Warning: Could not load static level file named \(fileName)")
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

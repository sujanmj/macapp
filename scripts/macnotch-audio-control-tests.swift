import Foundation

@main
struct AudioControlMathChecks {
    static func main() {
        precondition(AudioControlMath.normalizedVolume(-1) == 0, "Volume should clamp below zero")
        precondition(AudioControlMath.normalizedVolume(0.42) == 0.42, "Volume within range should remain unchanged")
        precondition(AudioControlMath.normalizedVolume(2) == 1, "Volume should clamp above one")
        precondition(AudioControlMath.normalizedVolume(.infinity) == 0, "Non-finite volume should fail closed")
        precondition(AudioControlMath.normalizedVolume(.nan) == 0, "NaN volume should fail closed")
        print("MacNotch audio control range checks passed")
    }
}

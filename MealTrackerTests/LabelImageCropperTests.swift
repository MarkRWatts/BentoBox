import Testing
import CoreGraphics
@testable import MealTracker

struct LabelImageCropperTests {
    @Test func matchingAspectRatioMapsGuideRectUnchanged() {
        let screenSize = CGSize(width: 400, height: 800)
        let imageSize = CGSize(width: 400, height: 800)
        let guideRect = CGRect(x: 40, y: 200, width: 320, height: 400)

        let result = LabelImageCropper.imageSpaceRect(forGuideRect: guideRect, screenSize: screenSize, imageSize: imageSize)

        #expect(result == guideRect)
    }

    @Test func accountsForAspectFillCroppingWhenImageIsRelativelyWider() {
        // screen aspect (w/h) = 0.5, image aspect = 0.75 — aspect-fill scales by the
        // height-constrained factor (1.0 here) and the image overflows/crops horizontally,
        // landing its origin 50pt off-screen to the left.
        let screenSize = CGSize(width: 200, height: 400)
        let imageSize = CGSize(width: 300, height: 400)
        let guideRect = CGRect(x: 50, y: 100, width: 100, height: 200)

        let result = LabelImageCropper.imageSpaceRect(forGuideRect: guideRect, screenSize: screenSize, imageSize: imageSize)

        #expect(result == CGRect(x: 100, y: 100, width: 100, height: 200))
    }

    @Test func clampsToImageBoundsWhenGuideRectExtendsPastEdges() {
        let screenSize = CGSize(width: 200, height: 400)
        let imageSize = CGSize(width: 200, height: 400)
        let guideRect = CGRect(x: -50, y: -50, width: 300, height: 500)

        let result = LabelImageCropper.imageSpaceRect(forGuideRect: guideRect, screenSize: screenSize, imageSize: imageSize)

        #expect(result == CGRect(x: 0, y: 0, width: 200, height: 400))
    }

    @Test func returnsZeroRectForDegenerateInputs() {
        #expect(LabelImageCropper.imageSpaceRect(forGuideRect: .zero, screenSize: .zero, imageSize: CGSize(width: 100, height: 100)) == .zero)
        #expect(LabelImageCropper.imageSpaceRect(forGuideRect: .zero, screenSize: CGSize(width: 100, height: 100), imageSize: .zero) == .zero)
    }
}

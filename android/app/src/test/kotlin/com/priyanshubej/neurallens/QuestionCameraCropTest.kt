package com.priyanshubej.neurallens

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class QuestionCameraCropTest {
    @Test fun unzoomedMatchingAspectPreservesWholePhoto() {
        assertEquals(QuestionCameraCrop(0, 0, 4000, 3000),
            QuestionCameraCrop.calculate(4000, 3000, 4.0 / 3.0, 1.0))
    }

    @Test fun twoTimesZoomCropsTheCenterHalf() {
        assertEquals(QuestionCameraCrop(1000, 750, 2000, 1500),
            QuestionCameraCrop.calculate(4000, 3000, 4.0 / 3.0, 2.0))
    }

    @Test fun photoIsMatchedToPortraitPreviewBeforeZoom() {
        assertEquals(QuestionCameraCrop(2500, 1000, 1000, 2000),
            QuestionCameraCrop.calculate(6000, 4000, 0.5, 2.0))
    }

    @Test fun allSupportedZoomsStayWithinImageBoundsAndKeepAspect() {
        for (zoom in listOf(1.0, 1.5, 2.0, 2.5, 3.0)) {
            val crop = QuestionCameraCrop.calculate(3024, 4032, 9.0 / 16.0, zoom)
            assertTrue(crop.x >= 0 && crop.y >= 0)
            assertTrue(crop.x + crop.width <= 3024 && crop.y + crop.height <= 4032)
            assertEquals(9.0 / 16.0, crop.width.toDouble() / crop.height, 0.002)
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun invalidZoomIsRejected() {
        QuestionCameraCrop.calculate(4000, 3000, 4.0 / 3.0, Double.NaN)
    }
}

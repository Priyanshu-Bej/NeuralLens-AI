package com.priyanshubej.neurallens

import kotlin.math.roundToInt

/** Center crop matches the visible preview aspect and the user's digital zoom. */
internal data class QuestionCameraCrop(val x: Int, val y: Int, val width: Int, val height: Int) {
    companion object {
        fun calculate(width: Int, height: Int, aspect: Double, zoom: Double): QuestionCameraCrop {
            require(width > 0 && height > 0 && aspect.isFinite() && aspect > 0)
            require(zoom.isFinite() && zoom in 1.0..3.0)
            val baseWidth = minOf(width.toDouble(), height * aspect)
            val baseHeight = baseWidth / aspect
            val cropWidth = (baseWidth / zoom).roundToInt().coerceIn(1, width)
            val cropHeight = (baseHeight / zoom).roundToInt().coerceIn(1, height)
            return QuestionCameraCrop((width - cropWidth) / 2, (height - cropHeight) / 2, cropWidth, cropHeight)
        }
    }
}

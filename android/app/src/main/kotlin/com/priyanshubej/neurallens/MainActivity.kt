package com.priyanshubej.neurallens

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// Must be a ComponentActivity (FlutterFragmentActivity is one): the Meta
// Wearables SDK only learns that registration happened in Developer Mode
// through an ActivityResult callback. On a plain FlutterActivity it never
// records Developer Mode, and the glasses then refuse every session with
// DAT_APP_ON_THE_GLASSES_UPDATE_REQUIRED.
class MainActivity : FlutterFragmentActivity() {
    private var wearables: MetaWearablesBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wearables = MetaWearablesBridge(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        wearables?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        wearables?.dispose()
        wearables = null
        super.onDestroy()
    }
}

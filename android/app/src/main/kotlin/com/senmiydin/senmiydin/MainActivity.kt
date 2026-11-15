package com.senmiydin.app

import android.content.Intent
import android.os.Bundle
import androidx.core.content.FileProvider
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // The system splash is only the bridge to the Flutter branded splash: it closes as soon as the first frame is
        // drawn and is never held longer. Must run before super.onCreate.
        installSplashScreen()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "senmiydin/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "instagramInstalled" -> result.success(instagramStoryIntent(null, null)?.let { true } ?: false)
                "instagramStory" -> {
                    val path = call.argument<String>("path")
                    val appId = call.argument<String>("appId")
                    result.success(shareInstagramStory(path, appId))
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Instagram's Story composer takes the card as the story background. Returns null when Instagram can't handle it. */
    private fun instagramStoryIntent(path: String?, appId: String?): Intent? {
        val intent = Intent("com.instagram.share.ADD_TO_STORY").setPackage(INSTAGRAM)
        if (path != null) {
            // Only cards from the app's own share folder are handed over. The file is copied into the folder
            // share_plus's FileProvider serves, so Instagram can read it through a content:// URI.
            val source = File(path).canonicalFile
            val allowed = File(cacheDir, "senmiydin_share").canonicalFile
            if (!source.path.startsWith(allowed.path + File.separator) || !source.isFile) return null
            val served = File(cacheDir, "share_plus").apply { mkdirs() }
            val copy = File(served, source.name)
            source.copyTo(copy, overwrite = true)
            val uri = FileProvider.getUriForFile(this, "$packageName.flutter.share_provider", copy)
            intent.setDataAndType(uri, "image/png")
            intent.putExtra("source_application", appId)
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            grantUriPermission(INSTAGRAM, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        return if (packageManager.resolveActivity(intent, 0) != null) intent else null
    }

    private fun shareInstagramStory(path: String?, appId: String?): Boolean {
        if (path == null || appId.isNullOrBlank()) return false
        return try {
            val intent = instagramStoryIntent(path, appId) ?: return false
            startActivity(intent)
            true
        } catch (error: Exception) {
            false
        }
    }

    private companion object {
        const val INSTAGRAM = "com.instagram.android"
    }
}

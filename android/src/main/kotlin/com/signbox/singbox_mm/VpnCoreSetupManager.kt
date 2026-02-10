package com.signbox.singbox_mm

import android.content.Context
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.SetupOptions
import java.io.File

internal object VpnCoreSetupManager {
    @Volatile
    private var setupDone = false

    private val setupLock = Any()

    fun ensure(context: Context) {
        if (setupDone) {
            return
        }

        synchronized(setupLock) {
            if (setupDone) {
                return
            }

            val basePath = context.filesDir.path
            val workingPath = (context.getExternalFilesDir(null) ?: context.filesDir).path
            val tempPath = context.cacheDir.path

            val setupOptions = SetupOptions().apply {
                this.basePath = basePath
                this.workingPath = workingPath
                this.tempPath = tempPath
                this.fixAndroidStack = false
            }
            Libbox.setup(setupOptions)
            runCatching {
                Libbox.redirectStderr(File(workingPath, "stderr.log").path)
            }

            setupDone = true
        }
    }
}

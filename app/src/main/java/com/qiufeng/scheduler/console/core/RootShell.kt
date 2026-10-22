package com.qiufeng.scheduler.console.core
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
object RootShell {
    private val mutex = Mutex()
    @Volatile var moduleDir: String = "/data/adb/modules/qiufeng_geek_scheduler"; private set
    @Volatile var ready: Boolean = false; private set
    suspend fun ensureReady(): Boolean = withContext(Dispatchers.IO) {
        if (ready) return@withContext true
        mutex.withLock {
            if (ready) return@withContext true
            try {
                Shell.getShell()
                if (Shell.isAppGrantedRoot() != true) return@withContext false
                val r = Shell.cmd("if [ -d /data/adb/modules/qiufeng_geek_scheduler ]; then echo /data/adb/modules/qiufeng_geek_scheduler; elif [ -d /data/adb/modules_update/qiufeng_geek_scheduler ]; then echo /data/adb/modules_update/qiufeng_geek_scheduler; fi").exec()
                val dir = r.out.firstOrNull()?.trim()
                if (dir.isNullOrEmpty()) return@withContext false
                val check = Shell.cmd("test -x $dir/webroot/api.sh && echo ok").exec()
                if (check.out.firstOrNull()?.trim() != "ok") return@withContext false
                moduleDir = dir; ready = true; true
            } catch (e: Exception) { false }
        }
    }
    suspend fun api(vararg args: String): String = withContext(Dispatchers.IO) {
        if (!ensureReady()) error("root shell unavailable")
        val cmd = buildString { append("sh ").append(moduleDir).append("/webroot/api.sh"); args.forEach { append(' ').append(shellQuote(it)) } }
        val r = Shell.cmd(cmd).exec()
        if (!r.isSuccess) error("api.sh failed: ${r.err.joinToString(" ")}")
        r.out.joinToString("\n")
    }
    suspend fun readFile(path: String): String = withContext(Dispatchers.IO) {
        if (!ensureReady()) error("root shell unavailable")
        Shell.cmd("cat $path 2>/dev/null").exec().out.joinToString("\n")
    }
    private fun shellQuote(s: String): String = "'" + s.replace("'", "'\\''") + "'"
}

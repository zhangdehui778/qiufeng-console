package com.qiufeng.scheduler.console.core
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.isActive
object StateBus {
    private const val STATE_PATH = "/data/adb/qfs_data/state.txt"
    fun stateFlow(): Flow<Map<String, String>> = flow {
        while (currentCoroutineContext().isActive) {
            val raw = runCatching { RootShell.readFile(STATE_PATH) }.getOrDefault("")
            emit(parse(raw)); delay(1500)
        }
    }.conflate()
    private fun parse(raw: String): Map<String, String> = raw.lineSequence().mapNotNull { line -> val i = line.indexOf('='); if (i <= 0) null else line.substring(0, i) to line.substring(i + 1) }.toMap()
}

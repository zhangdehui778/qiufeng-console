package com.qiufeng.scheduler.console.ui
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.qiufeng.scheduler.console.core.RootShell
import com.qiufeng.scheduler.console.core.StateBus
import com.qiufeng.scheduler.console.data.ModuleState
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
class MainViewModel : ViewModel() {
    val state: StateFlow<ModuleState> = StateBus.stateFlow().map { ModuleState.from(it) }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(3_000), ModuleState())
    val whitelist = MutableStateFlow<List<String>>(emptyList()); val settings = MutableStateFlow<Map<String, String>>(emptyMap()); val toast = MutableStateFlow<String?>(null)
    init { viewModelScope.launch { if (!RootShell.ensureReady()) { toast.value = "未获取 root 或模块未安装" } else { refreshWhitelist(); refreshSettings() } } }
    fun setMode(mode: String) = launchApi("setMode $mode", "已切换：$mode")
    fun addGame(pkg: String) { if (pkg.isBlank()) return; launchApi("addGame $pkg", "已添加：$pkg") { refreshWhitelist() } }
    fun removeGame(pkg: String) = launchApi("removeGame $pkg", "已移除") { refreshWhitelist() }
    fun setSetting(key: String, value: String) = launchApi("setSetting $key=$value", "已保存") { refreshSettings() }
    fun restartDaemon() = launchApi("restartDaemon", "守护进程重启中…")
    private fun refreshWhitelist() { viewModelScope.launch { runCatching { RootShell.api("getWhitelist") }.onSuccess { raw -> whitelist.value = raw.lineSequence().map { it.removePrefix("pkg=").trim() }.filter { it.isNotEmpty() }.toList() } } }
    private fun refreshSettings() { viewModelScope.launch { runCatching { RootShell.api("getSettings") }.onSuccess { raw -> settings.value = raw.lineSequence().mapNotNull { l -> val i = l.indexOf('='); if (i <= 0) null else l.substring(0, i) to l.substring(i + 1) }.toMap() } } }
    private fun launchApi(cmd: String, okMsg: String, onDone: (() -> Unit)? = null) { viewModelScope.launch { runCatching { RootShell.api(*cmd.split(" ").toTypedArray()) }.onSuccess { toast.value = okMsg; onDone?.invoke() }.onFailure { toast.value = "失败：${it.message}" } } }
}

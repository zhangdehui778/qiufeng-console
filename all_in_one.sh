#!/bin/bash
set -e
PKG_PATH="com/qiufeng/scheduler/console"
SRC="app/src/main/java/$PKG_PATH"
RES="app/src/main/res"
mkdir -p "$SRC/core" "$SRC/data" "$SRC/ui" "$RES/values"

cat > settings.gradle.kts <<'EOF'
pluginManagement { repositories { google(); mavenCentral(); gradlePluginPortal() } }
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral(); maven { url = uri("https://jitpack.io") } } }
rootProject.name = "qiufeng-console"
include(":app")
EOF

cat > build.gradle.kts <<'EOF'
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
EOF

mkdir -p app
cat > app/build.gradle.kts <<'EOF'
plugins { id("com.android.application"); id("org.jetbrains.kotlin.android"); id("org.jetbrains.kotlin.plugin.compose") }
android {
    namespace = "com.qiufeng.scheduler.console"
    compileSdk = 35
    defaultConfig { applicationId = "com.qiufeng.scheduler.console"; minSdk = 26; targetSdk = 35; versionCode = 1; versionName = "1.0.0" }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { compose = true }
}
dependencies {
    implementation("androidx.core:core-ktx:1.13.1"); implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7"); implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7"); implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7"); implementation("androidx.activity:activity-compose:1.9.3")
    val composeBom = platform("androidx.compose:compose-bom:2024.12.01")
    implementation(composeBom); implementation("androidx.compose.ui:ui"); implementation("androidx.compose.ui:ui-graphics"); implementation("androidx.compose.ui:ui-tooling-preview"); implementation("androidx.compose.material3:material3"); implementation("androidx.compose.material:material-icons-extended")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0"); implementation("com.github.topjohnwu.libsu:core:6.0.0")
}
EOF

mkdir -p app/src/main
cat > app/src/main/AndroidManifest.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:allowBackup="true" android:icon="@android:drawable/sym_def_app_icon" android:roundIcon="@android:drawable/sym_def_app_icon" android:label="秋风主控台" android:supportsRtl="true" android:theme="@style/Theme.QfConsole">
        <activity android:name=".MainActivity" android:exported="true" android:theme="@style/Theme.QfConsole">
            <intent-filter><action android:name="android.intent.action.MAIN" /><category android:name="android.intent.category.LAUNCHER" /></intent-filter>
        </activity>
    </application>
</manifest>
EOF

cat > "$RES/values/themes.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources><style name="Theme.QfConsole" parent="android:Theme.Material.NoActionBar"><item name="android:windowBackground">#060912</item><item name="android:statusBarColor">#060912</item><item name="android:navigationBarColor">#060912</item></style></resources>
EOF

cat > "$SRC/core/RootShell.kt" <<'EOF'
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
EOF

cat > "$SRC/core/StateBus.kt" <<'EOF'
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
EOF

cat > "$SRC/data/ModuleState.kt" <<'EOF'
package com.qiufeng.scheduler.console.data
data class ModuleState(val temp: Int = 0, val gpuFreq: Int = 0, val memUsed: Int = 0, val memTotal: Int = 0, val battery: Int = 0, val mode: String = "smart", val effMode: String = "balance", val fg: String = "", val uptime: Long = 0, val prime: String = "", val big: String = "", val little: String = "", val cpuFreqs: Map<String, Long> = emptyMap()) {
    companion object {
        fun from(map: Map<String, String>): ModuleState {
            val mem = (map["mem"] ?: "0:0").split(":")
            return ModuleState(temp = map["temp"]?.toIntOrNull() ?: 0, gpuFreq = map["gpu_freq"]?.toIntOrNull() ?: 0, memUsed = mem.getOrNull(0)?.toIntOrNull() ?: 0, memTotal = mem.getOrNull(1)?.toIntOrNull() ?: 0, battery = map["battery"]?.toIntOrNull() ?: 0, mode = map["mode"] ?: "smart", effMode = map["eff_mode"] ?: "balance", fg = map["fg"] ?: "", uptime = map["uptime"]?.toLongOrNull() ?: 0, prime = map["prime"] ?: "", big = map["big"] ?: "", little = map["little"] ?: "", cpuFreqs = (map["cpu_freqs"] ?: "").split(",").mapNotNull { item -> val i = item.indexOf(':'); if (i <= 0) null else item.substring(0, i).removePrefix("cpu") to (item.substring(i + 1).toLongOrNull() ?: 0L) }.toMap())
        }
    }
}
EOF

cat > "$SRC/ui/MainViewModel.kt" <<'EOF'
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
EOF

cat > "$SRC/MainActivity.kt" <<'EOF'
package com.qiufeng.scheduler.console
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.qiufeng.scheduler.console.ui.*
import kotlinx.coroutines.delay
class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme(colorScheme = darkColorScheme(primary = Color(0xFF4FC3F7), secondary = Color(0xFF7C4DFF), surface = Color(0xFF0B1220), background = Color(0xFF060912))) { ConsoleApp(vm) } }
    }
}
@Composable
fun ConsoleApp(vm: MainViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    val toast by vm.toast.collectAsStateWithLifecycle()
    LaunchedEffect(toast) { toast?.let { delay(1800); vm.toast.value = null } }
    Scaffold(
        bottomBar = { NavigationBar(containerColor = Color(0xFF0B1220)) { listOf(Triple("监控", Icons.Default.Speed, 0), Triple("调度", Icons.Default.Bolt, 1), Triple("游戏", Icons.Default.SportsEsports, 2), Triple("设置", Icons.Default.Settings, 3)).forEach { (label, icon, i) -> NavigationBarItem(selected = tab == i, onClick = { tab = i }, icon = { Icon(icon, label) }, label = { Text(label, fontSize = 10.sp) }) } } },
        snackbarHost = { toast?.let { Snackbar(modifier = Modifier.padding(16.dp)) { Text(it) } } }
    ) { pad -> Box(Modifier.padding(pad)) { when (tab) { 0 -> MonitorScreen(vm); 1 -> ModeScreen(vm); 2 -> WhitelistScreen(vm); 3 -> SettingsScreen(vm) } } }
}
EOF

cat > "$SRC/ui/MonitorScreen.kt" <<'EOF'
package com.qiufeng.scheduler.console.ui
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.qiufeng.scheduler.console.data.ModuleState
private val CardBg = Color(0xFF111A2B); private val Accent = Color(0xFF4FC3F7); private val Accent2 = Color(0xFF7C4DFF); private val Muted = Color(0xFF7B8BA3)
@Composable
fun MonitorScreen(vm: MainViewModel) {
    val s by vm.state.collectAsStateWithLifecycle()
    LazyColumn(Modifier.fillMaxSize().background(Color(0xFF060912)), contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item { Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("秋风 · 极客调度", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = Accent); Text("生效：${modeLabel(s.effMode)}  ·  前台：${s.fg.ifEmpty { "--" }}", fontSize = 10.sp, color = Muted, maxLines = 1) }; AssistChip(onClick = {}, label = { Text(modeLabel(s.mode), fontSize = 11.sp) }, colors = AssistChipDefaults.assistChipColors(labelColor = Accent)) } }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { StatCard("SoC 温度", "${s.temp}", "℃", tempColor(s.temp), Modifier.weight(1f)); StatCard("GPU", "${s.gpuFreq}", "MHz", Accent, Modifier.weight(1f)) } }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { StatCard("内存", "${s.memUsed}/${s.memTotal}", "MB", Accent2, Modifier.weight(1f)); StatCard("电量", "${s.battery}", "%", Color(0xFF69F0AE), Modifier.weight(1f)) } }
        item { StatCard("运行时长", fmtUptime(s.uptime), "", Color(0xFFB0BEC5), Modifier.fillMaxWidth()) }
        item { Text("CPU 核心", color = Muted, fontSize = 12.sp, fontWeight = FontWeight.Bold, modifier = Modifier.padding(top = 6.dp)) }
        items(buildCores(s)) { core -> CoreRow(core, s.cpuFreqs[core.id] ?: 0L) }
    }
}
data class Core(val id: String, val type: String, val cls: String)
private fun buildCores(s: ModuleState): List<Core> {
    val list = mutableListOf<Core>(); s.little.split(",").filter { it.isNotBlank() }.forEach { list += Core(it.trim(), "小核", "lit") }; s.big.split(",").filter { it.isNotBlank() }.forEach { list += Core(it.trim(), "大核", "big") }; s.prime.split(",").filter { it.isNotBlank() }.forEach { list += Core(it.trim(), "超大", "prime") }; return list.sortedBy { it.id.toIntOrNull() ?: 0 }
}
@Composable
private fun StatCard(label: String, value: String, unit: String, color: Color, mod: Modifier) {
    Card(mod, shape = RoundedCornerShape(14.dp), colors = CardDefaults.cardColors(containerColor = CardBg)) {
        Column(Modifier.padding(14.dp)) { Row(verticalAlignment = Alignment.Bottom) { Text(value, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold, color = color); if (unit.isNotEmpty()) Text(unit, fontSize = 10.sp, color = Muted, modifier = Modifier.padding(start = 3.dp, bottom = 3.dp)) }; Text(label, fontSize = 10.sp, color = Muted) }
    }
}
@Composable
private fun CoreRow(core: Core, freq: Long) {
    val max = when (core.cls) { "prime" -> 3_200_000L; "big" -> 2_800_000L; else -> 2_000_000L }; val pct = (freq.toFloat() / max).coerceIn(0f, 1f); val tagColor = when (core.cls) { "prime" -> Color(0xFFFF7B7B); "big" -> Color(0xFF9575FF); else -> Color(0xFF4FC3F7) }
    Row(Modifier.fillMaxWidth().background(CardBg, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("CPU${core.id}", fontFamily = FontFamily.Monospace, fontSize = 11.sp, color = Color(0xFFE6EDF5), modifier = Modifier.width(52.dp)); Text(core.type, fontSize = 9.sp, color = tagColor, modifier = Modifier.width(36.dp)); LinearProgressIndicator(progress = { pct }, Modifier.weight(1f).height(6.dp), color = tagColor, trackColor = Color(0xFF1C2A3E), strokeCap = StrokeCap.Round); Text(if (freq > 0) "${freq / 1000} MHz" else "--", fontFamily = FontFamily.Monospace, fontSize = 10.sp, color = Muted, modifier = Modifier.width(72.dp).padding(start = 8.dp))
    }
}
private fun tempColor(t: Int) = when { t > 48 -> Color(0xFFFF5252); t > 42 -> Color(0xFFFFD740); else -> Color(0xFF69F0AE) }
private fun modeLabel(m: String) = when (m) { "smart" -> "智能"; "powersave" -> "省电"; "balance" -> "均衡"; "performance" -> "性能"; "fury" -> "狂暴"; else -> m }
private fun fmtUptime(s: Long): String { if (s <= 0) return "--"; val h = s / 3600; val m = (s % 3600) / 60; return if (h > 0) "${h}h ${m}m" else "${m}m ${s % 60}s" }
EOF

cat > "$SRC/ui/ModeScreen.kt" <<'EOF'
package com.qiufeng.scheduler.console.ui
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
private val MODES = listOf(Triple("smart", "🧠", "智能识别"), Triple("powersave", "🔋", "极省电"), Triple("balance", "⚖️", "均衡"), Triple("performance", "🚀", "性能"), Triple("fury", "🔥", "狂暴"))
private val DESCS = mapOf("smart" to "前台白名单 / 温度 / 电量 三因子自动切档", "powersave" to "大核休眠，频率压至最低", "balance" to "日常流畅与功耗平衡", "performance" to "大核 70% 起跳，GPU 放开", "fury" to "全核满频锁定，GPU 顶格")
@Composable
fun ModeScreen(vm: MainViewModel) {
    val s by vm.state.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize().background(Color(0xFF060912)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("调度档位", color = Color(0xFF7B8BA3), fontSize = 12.sp, fontWeight = FontWeight.Bold)
        MODES.forEach { (id, icon, title) ->
            val selected = s.mode == id
            Card(Modifier.fillMaxWidth().clickable { vm.setMode(id) }, shape = RoundedCornerShape(14.dp), colors = CardDefaults.cardColors(containerColor = if (selected) Color(0xFF15243A) else Color(0xFF111A2B)), border = if (selected) BorderStroke(1.dp, Color(0xFF4FC3F7)) else null) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(icon, fontSize = 22.sp); Spacer(Modifier.width(12.dp)); Column(Modifier.weight(1f)) { Text(title, fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFFE6EDF5)); Text(DESCS[id] ?: "", fontSize = 10.sp, color = Color(0xFF7B8BA3)); if (id == "smart" && s.effMode.isNotEmpty()) Text("当前生效：${modeLabel2(s.effMode)}", fontSize = 10.sp, color = Color(0xFF4FC3F7)) }; RadioButton(selected = selected, onClick = { vm.setMode(id) })
                }
            }
        }
    }
}
private fun modeLabel2(m: String) = when (m) { "smart" -> "智能"; "powersave" -> "省电"; "balance" -> "均衡"; "performance" -> "性能"; "fury" -> "狂暴"; else -> m }
EOF

cat > "$SRC/ui/WhitelistScreen.kt" <<'EOF'
package com.qiufeng.scheduler.console.ui
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
@Composable
fun WhitelistScreen(vm: MainViewModel) {
    val list by vm.whitelist.collectAsStateWithLifecycle(); val state by vm.state.collectAsStateWithLifecycle(); var input by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().background(Color(0xFF060912)).padding(14.dp)) {
        Text("游戏白名单", color = Color(0xFF7B8BA3), fontSize = 12.sp, fontWeight = FontWeight.Bold); Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(value = input, onValueChange = { input = it }, modifier = Modifier.weight(1f), placeholder = { Text("包名，如 com.tencent.tmgp.sgame", fontSize = 11.sp) }, singleLine = true, textStyle = TextStyle(fontSize = 12.sp, fontFamily = FontFamily.Monospace))
            Spacer(Modifier.width(8.dp)); Button(onClick = { vm.addGame(input.trim()); input = "" }) { Icon(Icons.Default.Add, null, modifier = Modifier.size(18.dp)) }
        }
        Spacer(Modifier.height(12.dp))
        if (state.fg.isNotEmpty()) {
            Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFF111A2B))) {
                Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("当前前台", fontSize = 10.sp, color = Color(0xFF7B8BA3)); Text(state.fg, fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Color(0xFFB8C7D8), maxLines = 1) }; TextButton(onClick = { vm.addGame(state.fg) }) { Text("加入白名单", fontSize = 11.sp) } }
            }
            Spacer(Modifier.height(10.dp))
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(list) { pkg ->
                Row(Modifier.fillMaxWidth().background(Color(0xFF111A2B), RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(pkg, Modifier.weight(1f), fontSize = 11.sp, fontFamily = FontFamily.Monospace, color = Color(0xFFB8C7D8), maxLines = 1)
                    IconButton(onClick = { vm.removeGame(pkg) }, modifier = Modifier.size(28.dp)) { Icon(Icons.Default.Delete, null, tint = Color(0xFFFF5252), modifier = Modifier.size(16.dp)) }
                }
            }
        }
    }
}
EOF

cat > "$SRC/ui/SettingsScreen.kt" <<'EOF'
package com.qiufeng.scheduler.console.ui
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
@Composable
fun SettingsScreen(vm: MainViewModel) {
    val settings by vm.settings.collectAsStateWithLifecycle()
    Column(Modifier.fillMaxSize().background(Color(0xFF060912)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("调度行为", color = Color(0xFF7B8BA3), fontSize = 12.sp, fontWeight = FontWeight.Bold)
        SettingRow("Joyose 拦截", "每 60 秒清理小米云控 Joyose", settings["joyose_kill"] == "1") { vm.setSetting("joyose_kill", if (it) "1" else "0") }
        SettingRow("线程绑核", "渲染线程锁定大核（部分机型生效）", settings["thread_bind"] == "1") { vm.setSetting("thread_bind", if (it) "1" else "0") }
        Spacer(Modifier.height(8.dp)); Text("操作", color = Color(0xFF7B8BA3), fontSize = 12.sp, fontWeight = FontWeight.Bold)
        Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFF111A2B))) {
            Column {
                TextButton(onClick = { vm.restartDaemon() }, Modifier.fillMaxWidth().padding(horizontal = 12.dp)) { Text("重启守护进程", fontSize = 13.sp) }
                HorizontalDivider(color = Color(0xFF1C2A3E))
                TextButton(onClick = { vm.setMode("smart") }, Modifier.fillMaxWidth().padding(horizontal = 12.dp)) { Text("重置为智能模式", fontSize = 13.sp) }
            }
        }
        Spacer(Modifier.height(10.dp))
        Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = Color(0xFF111A2B))) {
            Column(Modifier.padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text("秋风 · 极客调度", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = Color(0xFF4FC3F7)); Text("主控台 v1.0.0  ·  模块 v1.3.0", fontSize = 10.sp, color = Color(0xFF7B8BA3), modifier = Modifier.padding(top = 4.dp)) }
        }
    }
}
@Composable
private fun SettingRow(title: String, desc: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().background(Color(0xFF111A2B), RoundedCornerShape(12.dp)).padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) { Text(title, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color(0xFFE6EDF5)); Text(desc, fontSize = 10.sp, color = Color(0xFF7B8BA3)) }; Switch(checked = checked, onCheckedChange = onChange)
    }
}
EOF

mkdir -p .github/workflows
cat > .github/workflows/build.yml <<'EOF'
name: Build APK
on: [push, workflow_dispatch]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '17' }
      - uses: android-actions/setup-android@v3
      - uses: gradle/actions/setup-gradle@v3
        with: { gradle-version: '8.9' }
      - run: gradle assembleDebug --no-daemon --stacktrace
      - uses: actions/upload-artifact@v4
        with: { name: qiufeng-apk, path: app/build/outputs/apk/debug/*.apk }
EOF

cat > .gitignore <<'EOF'
*.iml
.gradle
/local.properties
/.idea
.DS_Store
/build
/captures
.externalNativeBuild
.cxx
EOF

echo "============================================"
echo "  ✅ 项目文件已生成，准备上传"
echo "============================================"
read -rp "GitHub 用户名 (zhangdehui778): " GH_USER
read -rp "仓库名 (qiufeng-console): " GH_REPO
read -rp "Token (ghp_ 开头): " GH_TOKEN

git init -b main >/dev/null 2>&1 || true
git add .
git commit -m "init: 秋风主控台" >/dev/null
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"
git push -u origin main --force

echo ""
echo "============================================"
echo "  ✅ 代码已上传！"
echo "============================================"
echo "  1. 浏览器打开：https://github.com/$GH_USER/$GH_REPO/actions"
echo "  2. 等绿灯后，点进去在最下面下载 APK"
echo "============================================"


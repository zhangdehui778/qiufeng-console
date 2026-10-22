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

package com.qiufeng.scheduler.console

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.qiufeng.scheduler.console.ui.MainViewModel
import com.qiufeng.scheduler.console.ui.ModeScreen
import com.qiufeng.scheduler.console.ui.MonitorScreen
import com.qiufeng.scheduler.console.ui.SettingsScreen
import com.qiufeng.scheduler.console.ui.WhitelistScreen
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private val vm: MainViewModel by viewModels()
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = darkColorScheme(
                primary = Color(0xFF4FC3F7),
                secondary = Color(0xFF7C4DFF),
                surface = Color(0xFF0B1220),
                background = Color(0xFF060912)
            )) { ConsoleApp(vm) }
        }
    }
}

@Composable
fun ConsoleApp(vm: MainViewModel) {
    var tab by remember { mutableIntStateOf(0) }
    val toast by vm.toast.collectAsStateWithLifecycle()
    LaunchedEffect(toast) { toast?.let { delay(1800); vm.toast.value = null } }
    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = Color(0xFF0B1220)) {
                listOf(
                    Triple("监控", Icons.Default.Home, 0),
                    Triple("调度", Icons.Default.Star, 1),
                    Triple("游戏", Icons.Default.PlayArrow, 2),
                    Triple("设置", Icons.Default.Settings, 3)
                ).forEach { (label, icon, i) ->
                    NavigationBarItem(
                        selected = tab == i, onClick = { tab = i },
                        icon = { Icon(icon, label) },
                        label = { Text(label, fontSize = 10.sp) }
                    )
                }
            }
        },
        snackbarHost = {
            toast?.let { Snackbar(modifier = Modifier.padding(16.dp)) { Text(it) } }
        }
    ) { pad ->
        Box(Modifier.padding(pad)) {
            when (tab) {
                0 -> MonitorScreen(vm)
                1 -> ModeScreen(vm)
                2 -> WhitelistScreen(vm)
                3 -> SettingsScreen(vm)
            }
        }
    }
}

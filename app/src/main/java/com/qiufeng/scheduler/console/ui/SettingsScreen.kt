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

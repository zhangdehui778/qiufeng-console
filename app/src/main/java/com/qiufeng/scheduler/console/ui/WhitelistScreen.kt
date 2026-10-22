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

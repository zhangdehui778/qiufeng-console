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

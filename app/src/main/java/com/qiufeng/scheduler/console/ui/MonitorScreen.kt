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

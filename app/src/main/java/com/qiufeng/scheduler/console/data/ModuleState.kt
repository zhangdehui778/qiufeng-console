package com.qiufeng.scheduler.console.data
data class ModuleState(val temp: Int = 0, val gpuFreq: Int = 0, val memUsed: Int = 0, val memTotal: Int = 0, val battery: Int = 0, val mode: String = "smart", val effMode: String = "balance", val fg: String = "", val uptime: Long = 0, val prime: String = "", val big: String = "", val little: String = "", val cpuFreqs: Map<String, Long> = emptyMap()) {
    companion object {
        fun from(map: Map<String, String>): ModuleState {
            val mem = (map["mem"] ?: "0:0").split(":")
            return ModuleState(temp = map["temp"]?.toIntOrNull() ?: 0, gpuFreq = map["gpu_freq"]?.toIntOrNull() ?: 0, memUsed = mem.getOrNull(0)?.toIntOrNull() ?: 0, memTotal = mem.getOrNull(1)?.toIntOrNull() ?: 0, battery = map["battery"]?.toIntOrNull() ?: 0, mode = map["mode"] ?: "smart", effMode = map["eff_mode"] ?: "balance", fg = map["fg"] ?: "", uptime = map["uptime"]?.toLongOrNull() ?: 0, prime = map["prime"] ?: "", big = map["big"] ?: "", little = map["little"] ?: "", cpuFreqs = (map["cpu_freqs"] ?: "").split(",").mapNotNull { item -> val i = item.indexOf(':'); if (i <= 0) null else item.substring(0, i).removePrefix("cpu") to (item.substring(i + 1).toLongOrNull() ?: 0L) }.toMap())
        }
    }
}

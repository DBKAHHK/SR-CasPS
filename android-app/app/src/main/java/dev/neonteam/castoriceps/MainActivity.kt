package dev.neonteam.castoriceps

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.TextView
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.InputStream
import java.util.concurrent.Executors

class MainActivity : AppCompatActivity() {
    private val io = Executors.newSingleThreadExecutor()

    private var process: Process? = null
    private var workingDir: File? = null

    private val prefs by lazy { getSharedPreferences("castoriceps", MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val statusText = findViewById<TextView>(R.id.statusText)
        val pathText = findViewById<TextView>(R.id.pathText)
        val publicPathText = findViewById<TextView>(R.id.publicPathText)
        val logText = findViewById<TextView>(R.id.logText)
        val argsEdit = findViewById<EditText>(R.id.argsEdit)
        val showPopupCheck = findViewById<CheckBox>(R.id.showPopupCheck)
        val usePublicCheck = findViewById<CheckBox>(R.id.usePublicCheck)

        val runBtn = findViewById<Button>(R.id.runBtn)
        val stopBtn = findViewById<Button>(R.id.stopBtn)
        val resetBtn = findViewById<Button>(R.id.resetBtn)
        val openSrtoolsBtn = findViewById<Button>(R.id.openSrtoolsBtn)
        val pickPublicBtn = findViewById<Button>(R.id.pickPublicBtn)
        val pullPublicBtn = findViewById<Button>(R.id.pullPublicBtn)
        val pushPublicBtn = findViewById<Button>(R.id.pushPublicBtn)

        // 默认使用 data/data（内部目录），更稳定；公共目录作为可选调试数据源。
        workingDir = File(filesDir, "castoriceps").also { it.mkdirs() }
        pathText.text = "Dir: ${workingDir?.absolutePath ?: "-"}"
        fun setPublicPathText(text: String) {
            runOnUiThread { publicPathText.text = text }
        }
        fun getPublicTreeUri(): Uri? {
            val s = prefs.getString("public_tree_uri", null) ?: return null
            return runCatching { Uri.parse(s) }.getOrNull()
        }
        fun setPublicTreeUri(uri: Uri) {
            prefs.edit().putString("public_tree_uri", uri.toString()).apply()
        }
        fun updatePublicPathText() {
            val uri = getPublicTreeUri()
            setPublicPathText("PublicDir: ${uri?.toString() ?: "(not set)"}")
        }
        updatePublicPathText()

        fun appendLog(line: String) {
            runOnUiThread {
                logText.append(line)
                if (!line.endsWith("\n")) logText.append("\n")
            }
        }

        fun setRunning(running: Boolean) {
            runOnUiThread {
                statusText.text = if (running) "Status: running" else "Status: stopped"
                runBtn.isEnabled = !running
                stopBtn.isEnabled = running
            }
        }

        fun showStartupPopup() {
            AlertDialog.Builder(this)
                .setTitle("紧急提示")
                .setMessage(
                    "本服务器完全免费。\n\n" +
                        "加入 Discord.gg/dyn9NjBwzZ 获取更多信息。\n\n" +
                        "通过 https://srtools.neonteam.dev/ 修改角色与战斗配置。"
                )
                .setPositiveButton("知道了", null)
                .show()
        }

        fun extractAsset(name: String, dest: File) {
            assets.open(name).use { input ->
                dest.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        }

        fun withPublicDir(action: (DocumentFile) -> Unit) {
            val uri = getPublicTreeUri()
            if (uri == null) {
                appendLog("PublicDir not set. Click '选择公共文件夹' first.")
                return
            }
            val root = DocumentFile.fromTreeUri(this, uri)
            if (root == null || !root.isDirectory) {
                appendLog("PublicDir invalid. Re-pick the folder.")
                return
            }
            action(root)
        }

        fun copyFromPublic(root: DocumentFile, name: String, dest: File) {
            val src = root.findFile(name) ?: return
            if (!src.isFile) return
            contentResolver.openInputStream(src.uri)?.use { input ->
                dest.outputStream().use { output -> input.copyTo(output) }
            }
        }

        fun copyToPublic(root: DocumentFile, name: String, src: File) {
            if (!src.exists()) return
            val existing = root.findFile(name)
            val target = existing ?: root.createFile("application/octet-stream", name) ?: return
            contentResolver.openOutputStream(target.uri, "wt")?.use { output ->
                src.inputStream().use { input -> input.copyTo(output) }
            }
        }

        fun ensureServerFiles() {
            val dir = workingDir ?: return
            val bin = File(dir, "CastoricePS")
            if (!bin.exists()) {
                appendLog("Extracting asset: CastoricePS -> ${bin.absolutePath}")
                extractAsset("CastoricePS", bin)
                bin.setExecutable(true, true)
            }
            val freesr = File(dir, "freesr-data.json")
            if (!freesr.exists()) {
                appendLog("Extracting asset: freesr-data.json")
                extractAsset("freesr-data.json", freesr)
            }
            val misc = File(dir, "misc.json")
            if (!misc.exists()) {
                appendLog("Extracting asset: misc.json")
                extractAsset("misc.json", misc)
            }
            val hotfix = File(dir, "hotfix.json")
            if (!hotfix.exists()) {
                // hotfix.json 对客户端资源 URL 很关键，默认也放一份，方便外部手改
                try {
                    appendLog("Extracting asset: hotfix.json")
                    extractAsset("hotfix.json", hotfix)
                } catch (_: Throwable) {
                    appendLog("hotfix.json asset not found; skipping")
                }
            }
        }

        fun exportDefaultsToPublicIfMissing() {
            val dir = workingDir ?: return
            withPublicDir { root ->
                // 只有在公共目录缺文件时，才从 data/data 导出一份作为默认，避免覆盖用户调试文件
                fun exportIfMissing(name: String) {
                    if (root.findFile(name) != null) return
                    appendLog("PublicDir missing $name, exporting default...")
                    copyToPublic(root, name, File(dir, name))
                }

                exportIfMissing("freesr-data.json")
                exportIfMissing("misc.json")
                exportIfMissing("hotfix.json")
            }
        }

        val pickPublicDir =
            registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
                if (uri == null) return@registerForActivityResult
                try {
                    val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    contentResolver.takePersistableUriPermission(uri, flags)
                } catch (_: Throwable) {
                }
                setPublicTreeUri(uri)
                updatePublicPathText()

                io.execute {
                    // 确保 data/data 里已有默认文件，然后仅在公共目录缺失时导出一份
                    ensureServerFiles()
                    exportDefaultsToPublicIfMissing()
                }
            }

        fun deleteRecursively(file: File) {
            if (file.isDirectory) {
                file.listFiles()?.forEach { deleteRecursively(it) }
            }
            file.delete()
        }

        fun startReading(stream: InputStream, tag: String) {
            io.execute {
                stream.bufferedReader().useLines { lines ->
                    lines.forEach { appendLog("[$tag] $it") }
                }
            }
        }

        fun importConfigsFromPublicIfEnabled() {
            if (!usePublicCheck.isChecked) return
            val dir = workingDir ?: return
            withPublicDir { root ->
                appendLog("Importing configs from PublicDir -> ${dir.absolutePath}")
                copyFromPublic(root, "freesr-data.json", File(dir, "freesr-data.json"))
                copyFromPublic(root, "misc.json", File(dir, "misc.json"))
                copyFromPublic(root, "hotfix.json", File(dir, "hotfix.json"))
            }
        }

        runBtn.setOnClickListener {
            if (process != null) return@setOnClickListener
            if (showPopupCheck.isChecked) showStartupPopup()

            io.execute {
                try {
                    ensureServerFiles()
                    importConfigsFromPublicIfEnabled()
                    val dir = workingDir ?: return@execute
                    val bin = File(dir, "CastoricePS")

                    val args = argsEdit.text.toString()
                        .trim()
                        .split(Regex("\\s+"))
                        .filter { it.isNotBlank() }

                    val cmd = mutableListOf(bin.absolutePath).apply { addAll(args) }
                    appendLog("Starting: ${cmd.joinToString(" ")}")

                    val pb = ProcessBuilder(cmd)
                        .directory(dir)
                        .redirectErrorStream(false)

                    val p = pb.start()
                    process = p
                    setRunning(true)
                    startReading(p.inputStream, "OUT")
                    startReading(p.errorStream, "ERR")

                    val code = p.waitFor()
                    appendLog("Process exited with code=$code")
                } catch (t: Throwable) {
                    appendLog("Start failed: ${t.message}")
                } finally {
                    process = null
                    setRunning(false)
                }
            }
        }

        stopBtn.setOnClickListener {
            io.execute {
                val p = process ?: return@execute
                appendLog("Stopping...")
                p.destroy()
            }
        }

        resetBtn.setOnClickListener {
            io.execute {
                val dir = workingDir ?: return@execute
                if (process != null) {
                    appendLog("Server is running; stop it before reset.")
                    return@execute
                }
                appendLog("Resetting server data in ${dir.absolutePath}")
                deleteRecursively(dir)
                dir.mkdirs()
                appendLog("Reset completed.")
            }
        }

        pickPublicBtn.setOnClickListener {
            pickPublicDir.launch(null)
        }

        pullPublicBtn.setOnClickListener {
            io.execute {
                ensureServerFiles()
                importConfigsFromPublicIfEnabled()
                // Even if checkbox off, allow manual pull.
                if (!usePublicCheck.isChecked) {
                    val dir = workingDir ?: return@execute
                    withPublicDir { root ->
                        appendLog("Manually importing configs from PublicDir -> ${dir.absolutePath}")
                        copyFromPublic(root, "freesr-data.json", File(dir, "freesr-data.json"))
                        copyFromPublic(root, "misc.json", File(dir, "misc.json"))
                        copyFromPublic(root, "hotfix.json", File(dir, "hotfix.json"))
                    }
                }
            }
        }

        pushPublicBtn.setOnClickListener {
            io.execute {
                ensureServerFiles()
                val dir = workingDir ?: return@execute
                withPublicDir { root ->
                    appendLog("Exporting configs to PublicDir")
                    copyToPublic(root, "freesr-data.json", File(dir, "freesr-data.json"))
                    copyToPublic(root, "misc.json", File(dir, "misc.json"))
                    val hotfix = File(dir, "hotfix.json")
                    if (hotfix.exists()) copyToPublic(root, "hotfix.json", hotfix)
                }
            }
        }

        openSrtoolsBtn.setOnClickListener {
            val url = "https://srtools.neonteam.dev/"
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }
    }
}

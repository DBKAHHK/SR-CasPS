package dev.neonteam.castoriceps

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.system.Os
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
    private val prefs by lazy { getSharedPreferences("castoriceps", MODE_PRIVATE) }

    private lateinit var workingDir: File

    private lateinit var statusText: TextView
    private lateinit var pathText: TextView
    private lateinit var execPathText: TextView
    private lateinit var publicPathText: TextView
    private lateinit var logText: TextView
    private lateinit var argsEdit: EditText
    private lateinit var showPopupCheck: CheckBox
    private lateinit var usePublicCheck: CheckBox

    private fun appendLog(line: String) {
        runOnUiThread {
            logText.append(line)
            if (!line.endsWith("\n")) logText.append("\n")
        }
    }

    private fun setRunning(running: Boolean) {
        runOnUiThread {
            statusText.text = if (running) "Status: running" else "Status: stopped"
            findViewById<Button>(R.id.runBtn).isEnabled = !running
            findViewById<Button>(R.id.stopBtn).isEnabled = running
        }
    }

    private fun getPublicTreeUri(): Uri? {
        val s = prefs.getString("public_tree_uri", null) ?: return null
        return runCatching { Uri.parse(s) }.getOrNull()
    }

    private fun setPublicTreeUri(uri: Uri) {
        prefs.edit().putString("public_tree_uri", uri.toString()).apply()
        updatePublicPathText()
    }

    private fun updatePublicPathText() {
        val uri = getPublicTreeUri()
        publicPathText.text = "PublicDir: ${uri?.toString() ?: "(not set)"}"
    }

    private fun withPublicDir(action: (DocumentFile) -> Unit) {
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

    private fun copyFromPublic(root: DocumentFile, name: String, dest: File) {
        val src = root.findFile(name) ?: return
        if (!src.isFile) return
        contentResolver.openInputStream(src.uri)?.use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        }
    }

    private fun copyToPublic(root: DocumentFile, name: String, src: File) {
        if (!src.exists()) return
        val existing = root.findFile(name)
        val target = existing ?: root.createFile("application/octet-stream", name) ?: return
        contentResolver.openOutputStream(target.uri, "wt")?.use { output ->
            src.inputStream().use { input -> input.copyTo(output) }
        }
    }

    private fun extractAsset(name: String, dest: File) {
        assets.open(name).use { input ->
            dest.outputStream().use { output -> input.copyTo(output) }
        }
    }

    private fun ensureServerFiles() {
        val freesr = File(workingDir, "freesr-data.json")
        if (!freesr.exists()) {
            appendLog("Extracting asset: freesr-data.json")
            extractAsset("freesr-data.json", freesr)
        }
        val misc = File(workingDir, "misc.json")
        if (!misc.exists()) {
            appendLog("Extracting asset: misc.json")
            extractAsset("misc.json", misc)
        }
        val hotfix = File(workingDir, "hotfix.json")
        if (!hotfix.exists()) {
            try {
                appendLog("Extracting asset: hotfix.json")
                extractAsset("hotfix.json", hotfix)
            } catch (_: Throwable) {
                appendLog("hotfix.json asset not found; skipping")
            }
        }
    }

    private fun exportDefaultsToPublicIfMissing() {
        withPublicDir { root ->
            fun exportIfMissing(name: String) {
                if (root.findFile(name) != null) return
                appendLog("PublicDir missing $name, exporting default...")
                copyToPublic(root, name, File(workingDir, name))
            }
            exportIfMissing("freesr-data.json")
            exportIfMissing("misc.json")
            exportIfMissing("hotfix.json")
        }
    }

    private fun importConfigsFromPublicIfEnabled() {
        if (!usePublicCheck.isChecked) return
        withPublicDir { root ->
            appendLog("Importing configs from PublicDir -> ${workingDir.absolutePath}")
            copyFromPublic(root, "freesr-data.json", File(workingDir, "freesr-data.json"))
            copyFromPublic(root, "misc.json", File(workingDir, "misc.json"))
            copyFromPublic(root, "hotfix.json", File(workingDir, "hotfix.json"))
        }
    }

    private fun deleteRecursively(file: File) {
        if (file.isDirectory) file.listFiles()?.forEach { deleteRecursively(it) }
        file.delete()
    }

    private fun startReading(stream: InputStream, tag: String) {
        io.execute {
            stream.bufferedReader().useLines { lines ->
                lines.forEach { appendLog("[$tag] $it") }
            }
        }
    }

    private fun showStartupPopup() {
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

    private val pickPublicDir =
        registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            if (uri == null) return@registerForActivityResult
            try {
                val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: Throwable) {
            }
            setPublicTreeUri(uri)
            io.execute {
                ensureServerFiles()
                exportDefaultsToPublicIfMissing()
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        pathText = findViewById(R.id.pathText)
        execPathText = findViewById(R.id.execPathText)
        publicPathText = findViewById(R.id.publicPathText)
        logText = findViewById(R.id.logText)
        argsEdit = findViewById(R.id.argsEdit)
        showPopupCheck = findViewById(R.id.showPopupCheck)
        usePublicCheck = findViewById(R.id.usePublicCheck)

        workingDir = File(filesDir, "castoriceps").also { it.mkdirs() }
        pathText.text = "Dir: ${workingDir.absolutePath}"
        execPathText.text = "Exec: System.loadLibrary(\"castoriceps\")"
        updatePublicPathText()

        findViewById<Button>(R.id.runBtn).setOnClickListener {
            if (showPopupCheck.isChecked) showStartupPopup()

            io.execute {
                try {
                    ensureServerFiles()
                    importConfigsFromPublicIfEnabled()

                    appendLog("Starting embedded server (workDir=${workingDir.absolutePath})")
                    try {
                        Os.setenv("CASTORICEPS_WORKDIR", workingDir.absolutePath, true)
                    } catch (t: Throwable) {
                        appendLog("setenv failed: ${t.message}")
                    }
                    NativeBridge.ensureLoaded()
                    val rc = NativeBridge.start()
                    appendLog("NativeBridge.start() => $rc")
                    if (rc == 0 || rc == 1) {
                        // 0: started; 1: already running
                        setRunning(true)
                    } else {
                        setRunning(false)
                    }
                } catch (t: Throwable) {
                    appendLog("Start failed: ${t.message}")
                    setRunning(false)
                } finally {
                }
            }
        }

        findViewById<Button>(R.id.stopBtn).setOnClickListener {
            io.execute {
                appendLog("Stopping...")
                val rc = NativeBridge.stop()
                appendLog("NativeBridge.stop() => $rc")
                setRunning(false)
            }
        }

        findViewById<Button>(R.id.resetBtn).setOnClickListener {
            io.execute {
                appendLog("Resetting server data in ${workingDir.absolutePath}")
                deleteRecursively(workingDir)
                workingDir.mkdirs()
                appendLog("Reset completed.")
            }
        }

        findViewById<Button>(R.id.pickPublicBtn).setOnClickListener {
            pickPublicDir.launch(null)
        }

        findViewById<Button>(R.id.pullPublicBtn).setOnClickListener {
            io.execute {
                ensureServerFiles()
                withPublicDir { root ->
                    appendLog("Manually importing configs from PublicDir -> ${workingDir.absolutePath}")
                    copyFromPublic(root, "freesr-data.json", File(workingDir, "freesr-data.json"))
                    copyFromPublic(root, "misc.json", File(workingDir, "misc.json"))
                    copyFromPublic(root, "hotfix.json", File(workingDir, "hotfix.json"))
                }
            }
        }

        findViewById<Button>(R.id.pushPublicBtn).setOnClickListener {
            io.execute {
                ensureServerFiles()
                withPublicDir { root ->
                    appendLog("Exporting configs to PublicDir")
                    copyToPublic(root, "freesr-data.json", File(workingDir, "freesr-data.json"))
                    copyToPublic(root, "misc.json", File(workingDir, "misc.json"))
                    val hotfix = File(workingDir, "hotfix.json")
                    if (hotfix.exists()) copyToPublic(root, "hotfix.json", hotfix)
                }
            }
        }

        findViewById<Button>(R.id.openSrtoolsBtn).setOnClickListener {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://srtools.neonteam.dev/")))
        }
    }
}

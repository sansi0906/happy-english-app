package com.example.kuaile_yingyu

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/// 快乐英语：跟读录音本地归档通道
/// 录音保存在公共下载目录 Download/快乐英语录音/（无需权限，adb 可直接读取，
/// 家长也可在文件管理器里查看/拷贝）。
class MainActivity : FlutterActivity() {
    private val channelName = "kuaile_recordings"
    private val folderName = "快乐英语录音"
    private val backupFolderName = "快乐英语备份"

    private var pendingOpen: MethodChannel.Result? = null
    private val pickRequestCode = 1001

    /// 系统文件选择器回传：把选中的 json 读成字符串交回 Dart
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequestCode) return
        val r = pendingOpen
        pendingOpen = null
        val uri = if (resultCode == RESULT_OK) data?.data else null
        if (uri == null) {
            r?.success(null)
            return
        }
        try {
            val text = contentResolver.openInputStream(uri)
                ?.use { it.readBytes().toString(Charsets.UTF_8) }
            r?.success(text)
        } catch (e: Exception) {
            r?.error("READ_FAIL", e.message ?: "读取备份失败", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveWav" -> {
                        val srcPath = call.argument<String>("srcPath")
                        val fileName = call.argument<String>("fileName")
                        val indexJson = call.argument<String>("indexJson")
                        if (srcPath == null || fileName == null || indexJson == null) {
                            result.error("BAD_ARG", "missing args", null)
                        } else {
                            result.success(saveWav(srcPath, fileName, indexJson))
                        }
                    }
                    "copyRecording" -> {
                        val fileName = call.argument<String>("fileName")
                        if (fileName == null) {
                            result.error("BAD_ARG", "missing fileName", null)
                        } else {
                            result.success(copyRecordingToCache(fileName))
                        }
                    }
                    "readIndex" -> result.success(readIndex())
                    "clearAll" -> {
                        clearAll()
                        result.success(true)
                    }
                    "stats" -> result.success(stats())
                    "exportAll" -> result.success(exportAll())
                    "saveText" -> {
                        // 备份文件导出到 Download/快乐英语备份/，家长可自行转发或换机导入
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")
                        if (fileName == null || content == null) {
                            result.error("BAD_ARG", "missing fileName/content", null)
                        } else {
                            result.success(saveText(fileName, content))
                        }
                    }
                    // 让用户从系统文件选择器挑一份备份 json（无需存储权限，
                    // 下载目录、微信、网盘里的都能选）
                    "pickBackupText" -> {
                        pendingOpen = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain", "application/octet-stream")
                            )
                        }
                        try {
                            startActivityForResult(intent, pickRequestCode)
                        } catch (e: Exception) {
                            pendingOpen = null
                            result.error("NO_PICKER", e.message ?: "没有可用的文件选择器", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// 录音目录：应用专属外部目录（Android 10+ 分区存储下无需任何权限即可读写，
    /// 且 adb / 电脑可直接访问）。公共 Download 目录在高版本下只能看到本应用新建的文件，
    /// 历史录音会"消失"，因此统一改到专属目录。
    private fun downloadDir(): File {
        val dir = File(getExternalFilesDir(null) ?: filesDir, folderName)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    /// 查询本应用录音目录下的文件（Android 10+ 分区存储下必须走 MediaStore，
    /// 否则 File API 只能看到本应用刚刚写入的那几个，历史录音全部不可见）。
    /// [nameLike]：文件名 LIKE 条件，如 "%.wav"、"index.json"
    private fun queryDownloads(nameLike: String? = null): List<Triple<String, Long, Uri>> {
        if (Build.VERSION.SDK_INT < 29) return emptyList()
        val out = mutableListOf<Triple<String, Long, Uri>>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE
        )
        val selection = buildString {
            append("${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?")
            if (nameLike != null) append(" AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?")
        }
        val args = if (nameLike != null) {
            arrayOf("%$folderName%", nameLike)
        } else {
            arrayOf("%$folderName%")
        }
        contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI, projection, selection, args, null
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                val name = c.getString(1) ?: continue
                val size = c.getLong(2)
                out.add(
                    Triple(
                        name,
                        size,
                        ContentUris.withAppendedId(MediaStore.Downloads.EXTERNAL_CONTENT_URI, id)
                    )
                )
            }
        }
        return out
    }

    private fun saveWav(srcPath: String, fileName: String, indexJson: String): Boolean = try {
        val src = File(srcPath)
        if (!src.exists()) return false
        if (Build.VERSION.SDK_INT >= 29) {
            // Android 10+：MediaStore 写入公共 Download，免权限
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/wav")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/" + folderName
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return false
            resolver.openOutputStream(uri)?.use { out ->
                src.inputStream().use { it.copyTo(out) }
            } ?: return false
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } else {
            // Android 9-：直接写公共 Download（需要存储权限，无权限时失败由 Dart 端兜底）
            val dest = File(downloadDir(), fileName)
            src.copyTo(dest, overwrite = true)
        }
        // 索引随录音一并更新
        writeIndex(indexJson)
        // 清理同 item 的旧录音：只保留刚写的这条最高分
        cleanupOldRecordings(fileName)
        true
    } catch (e: Exception) {
        false
    }

    /// 删除同 child_book_item 的旧录音，只保留最高分那条
    /// 文件名: {child}_{book}_{item}_{score}_{date}_{time}.wav
    /// child 可能含下划线，从右往左数：最后3段是 time/date/score，前面是 child_book_item
    private fun cleanupOldRecordings(newFileName: String) {
        try {
            val name = newFileName.removeSuffix(".wav")
            val parts = name.split("_")
            if (parts.size < 6) return
            val newScore = parts[parts.size - 3].toIntOrNull() ?: return
            val prefix = parts.take(parts.size - 3).joinToString("_") + "_"
            val dir = downloadDir()
            dir.listFiles()?.forEach { f ->
                if (f.isFile && f.name.endsWith(".wav")
                    && f.name.startsWith(prefix)
                    && f.name != newFileName
                ) {
                    val oldParts = f.name.removeSuffix(".wav").split("_")
                    val oldScore = oldParts.getOrNull(oldParts.size - 3)?.toIntOrNull()
                    if (oldScore != null && oldScore < newScore) {
                        f.delete()
                    }
                }
            }
        } catch (_: Exception) {}
    }

    /// 写索引（专属目录，直接 File 写即可）
    private fun writeIndex(json: String): Boolean = try {
        File(downloadDir(), "index.json").writeText(json)
        true
    } catch (_: Exception) {
        false
    }

    private fun readIndex(): String? {
        val f = File(downloadDir(), "index.json")
        return if (f.exists()) f.readText() else null
    }

    /// 把 Download/快乐英语录音/ 下某条录音拷贝到 app 缓存目录并返回路径（供回听）。
    /// 文件已被"只保留最高分"清理时返回 null。
    private fun copyRecordingToCache(fileName: String): String? = try {
        val src = File(downloadDir(), fileName)
        if (!src.exists()) return null
        val cacheDir = File(cacheDir, "recordings")
        if (!cacheDir.exists()) cacheDir.mkdirs()
        val dest = File(cacheDir, fileName)
        src.copyTo(dest, overwrite = true)
        dest.absolutePath
    } catch (_: Exception) {
        null
    }

    private fun clearAll() {
        downloadDir().listFiles()?.forEach { it.delete() }
    }

    private fun stats(): String {
        var count = 0
        var bytes = 0L
        downloadDir().listFiles()?.forEach { f ->
            if (f.isFile && f.name.endsWith(".wav")) {
                count++
                bytes += f.length()
            }
        }
        return "{\"count\":$count,\"bytes\":$bytes}"
    }

    /// 把一段文本写成文件放到公共 Download/快乐英语备份/。
    /// 返回给 Dart 的可读路径（如 "Download/快乐英语备份/xxx.json"），失败返回 null。
    private fun saveText(fileName: String, content: String): String? = try {
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    Environment.DIRECTORY_DOWNLOADS + "/" + backupFolderName
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return null
            contentResolver.openOutputStream(uri)?.use { out ->
                out.write(content.toByteArray(Charsets.UTF_8))
            } ?: return null
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
        } else {
            val dir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                backupFolderName
            )
            if (!dir.exists()) dir.mkdirs()
            File(dir, fileName).writeText(content, Charsets.UTF_8)
        }
        "Download/$backupFolderName/$fileName"
    } catch (e: Exception) {
        null
    }

    /// 把全部录音 + index.json 打成一个 zip 放到公共 Download 根目录。
    /// 返回给 Dart 的可读路径（如 "Download/快乐英语录音_20261119_143000.zip"）。
    /// 没有录音时返回 null。
    private fun exportAll(): String? = try {
        val wavs = downloadDir().listFiles()
            ?.filter { it.isFile && it.name.endsWith(".wav") } ?: emptyList()
        if (wavs.isEmpty()) return null
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val zipName = "快乐英语录音_$stamp.zip"
        val tmp = File(cacheDir, zipName)
        ZipOutputStream(tmp.outputStream().buffered()).use { zos ->
            wavs.forEach { f ->
                zos.putNextEntry(ZipEntry(f.name))
                f.inputStream().use { input ->
                    input.copyTo(zos)
                }
                zos.closeEntry()
            }
            readIndex()?.let { idx ->
                zos.putNextEntry(ZipEntry("index.json"))
                zos.write(idx.toByteArray(Charsets.UTF_8))
                zos.closeEntry()
            }
        }
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, zipName)
                put(MediaStore.MediaColumns.MIME_TYPE, "application/zip")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: return null
            contentResolver.openOutputStream(uri)?.use { out ->
                tmp.inputStream().use { it.copyTo(out) }
            } ?: return null
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            tmp.delete()
        } else {
            val dest = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                zipName
            )
            tmp.copyTo(dest, overwrite = true)
            tmp.delete()
        }
        "Download/$zipName"
    } catch (e: Exception) {
        null
    }
}

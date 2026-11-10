package com.example.pick_file

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.Collections
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.Continuation
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * PickFilePlugin provides native file selection on Android using the Storage Access Framework (SAF)
 * through [Intent.ACTION_OPEN_DOCUMENT].
 */
class PickFilePlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PickFileHostApi {

    companion object {
        private const val REQUEST_CODE_PICK_FILE = 54101
        private const val CACHE_DIR_NAME = "pick_file"
        private const val BUFFER_SIZE = 64 * 1024 // 64 KB streaming buffer

        private val EXTENSION_MIME_FALLBACK = mapOf(
            "pdf" to "application/pdf",
            "doc" to "application/msword",
            "docx" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "xls" to "application/vnd.ms-excel",
            "xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "ppt" to "application/vnd.ms-powerpoint",
            "pptx" to "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "txt" to "text/plain",
            "csv" to "text/csv",
            "json" to "application/json",
            "rtf" to "application/rtf",
            "zip" to "application/zip",
            "tar" to "application/x-tar",
            "gz" to "application/gzip",
            "7z" to "application/x-7z-compressed",
            "rar" to "application/x-rar-compressed",
            "odt" to "application/vnd.oasis.opendocument.text",
            "ods" to "application/vnd.oasis.opendocument.spreadsheet",
            "odp" to "application/vnd.oasis.opendocument.presentation",
            "xml" to "application/xml",
            "html" to "text/html",
            "htm" to "text/html",
            "png" to "image/png",
            "jpg" to "image/jpeg",
            "jpeg" to "image/jpeg",
            "webp" to "image/webp",
            "gif" to "image/gif",
            "mp4" to "video/mp4",
            "mov" to "video/quicktime",
            "mp3" to "audio/mpeg",
            "wav" to "audio/wav"
        )
    }

    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private val isBusy = AtomicBoolean(false)
    private var pendingContinuation: Continuation<List<PickedFileResult>>? = null
    private var pendingOptions: FilePickOptionsDto? = null

    // Set of file paths currently being written so clearCache() will not touch active files
    private val activeProcessingFiles = Collections.synchronizedSet(mutableSetOf<String>())

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        PickFileHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PickFileHostApi.setUp(binding.binaryMessenger, null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null

        if (isBusy.getAndSet(false)) {
            val cont = pendingContinuation
            pendingContinuation = null
            pendingOptions = null
            cont?.resumeWithException(
                FlutterError(
                    "platform_unavailable",
                    "Activity was detached before file picker operation could complete",
                    null
                )
            )
        }
    }

    // --- Host API Implementation ---

    override suspend fun pickFiles(options: FilePickOptionsDto): List<PickedFileResult> {
        val currentActivity = activity ?: throw FlutterError(
            "platform_unavailable",
            "Activity is null or not attached. Cannot launch document picker.",
            null
        )

        if (!isBusy.compareAndSet(false, true)) {
            throw FlutterError(
                "picker_busy",
                "Another file picker operation is already in progress.",
                null
            )
        }

        return suspendCancellableCoroutine { continuation ->
            pendingContinuation = continuation
            pendingOptions = options

            continuation.invokeOnCancellation {
                if (isBusy.compareAndSet(true, false)) {
                    pendingContinuation = null
                    pendingOptions = null
                }
            }

            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    if (options.allowMultiple) {
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                    applyMimeFilters(this, options)
                }

                currentActivity.startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
            } catch (e: ActivityNotFoundException) {
                isBusy.set(false)
                pendingContinuation = null
                pendingOptions = null
                continuation.resumeWithException(
                    FlutterError(
                        "native_picker_failed",
                        "No application found on device capable of opening documents: ${e.message}",
                        null
                    )
                )
            } catch (e: SecurityException) {
                isBusy.set(false)
                pendingContinuation = null
                pendingOptions = null
                continuation.resumeWithException(
                    FlutterError(
                        "file_access_denied",
                        "Security exception launching file picker: ${e.message}",
                        null
                    )
                )
            } catch (e: Exception) {
                isBusy.set(false)
                pendingContinuation = null
                pendingOptions = null
                continuation.resumeWithException(
                    FlutterError(
                        "native_picker_failed",
                        "Failed to launch native file picker: ${e.message}",
                        null
                    )
                )
            }
        }
    }

    override suspend fun clearCache() {
        withContext(Dispatchers.IO) {
            val ctx = context ?: return@withContext
            val cacheDir = File(ctx.cacheDir, CACHE_DIR_NAME)
            if (!cacheDir.exists() || !cacheDir.isDirectory) return@withContext

            val files = cacheDir.listFiles() ?: return@withContext
            for (file in files) {
                if (!activeProcessingFiles.contains(file.absolutePath)) {
                    file.delete()
                }
            }
        }
    }

    // --- Activity Result Handling ---

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_FILE) return false

        val continuation = pendingContinuation
        val options = pendingOptions

        pendingContinuation = null
        pendingOptions = null

        if (continuation == null) {
            isBusy.set(false)
            return true
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            // User cancelled or no result returned
            isBusy.set(false)
            continuation.resume(emptyList())
            return true
        }

        val uris = extractUris(data)
        if (uris.isEmpty()) {
            isBusy.set(false)
            continuation.resume(emptyList())
            return true
        }

        // Validate maxFiles upfront
        val maxFiles = options?.maxFiles
        if (maxFiles != null && uris.size > maxFiles) {
            isBusy.set(false)
            continuation.resumeWithException(
                FlutterError(
                    "maximum_file_count_exceeded",
                    "Selected ${uris.size} files exceeds maximum allowed count of $maxFiles",
                    null
                )
            )
            return true
        }

        // Process files asynchronously off the main thread
        CoroutineScope(Dispatchers.IO).launch {
            val createdFiles = mutableListOf<File>()
            try {
                val results = mutableListOf<PickedFileResult>()
                val ctx = context ?: throw FlutterError(
                    "platform_unavailable",
                    "Application context is null while processing file results",
                    null
                )

                val cacheDir = File(ctx.cacheDir, CACHE_DIR_NAME)
                if (!cacheDir.exists()) {
                    cacheDir.mkdirs()
                }

                for (uri in uris) {
                    val result = processSingleUri(ctx, uri, options, cacheDir, createdFiles)
                    results.add(result)
                }

                withContext(Dispatchers.Main) {
                    isBusy.set(false)
                    continuation.resume(results)
                }
            } catch (e: FlutterError) {
                cleanupBatchFiles(createdFiles)
                withContext(Dispatchers.Main) {
                    isBusy.set(false)
                    continuation.resumeWithException(e)
                }
            } catch (e: Exception) {
                cleanupBatchFiles(createdFiles)
                withContext(Dispatchers.Main) {
                    isBusy.set(false)
                    continuation.resumeWithException(
                        FlutterError(
                            "file_copy_failed",
                            "Unexpected error processing selected file: ${e.message}",
                            null
                        )
                    )
                }
            }
        }

        return true
    }

    private fun extractUris(data: Intent): List<Uri> {
        val list = mutableListOf<Uri>()
        val clipData = data.clipData
        if (clipData != null) {
            for (i in 0 until clipData.itemCount) {
                val item = clipData.getItemAt(i)
                item.uri?.let { list.add(it) }
            }
        } else {
            data.data?.let { list.add(it) }
        }
        return list
    }

    private fun processSingleUri(
        ctx: Context,
        uri: Uri,
        options: FilePickOptionsDto?,
        cacheDir: File,
        createdFiles: MutableList<File>
    ): PickedFileResult {
        val resolver = ctx.contentResolver
            ?: throw FlutterError("platform_unavailable", "ContentResolver is unavailable", null)

        val rawDisplayName = getDisplayName(ctx, uri)
        val detectedMime = resolver.getType(uri) ?: getMimeFromUriOrName(uri, rawDisplayName)
        val extension = getExtension(rawDisplayName, detectedMime)
        val displayName = sanitizeFileName(rawDisplayName ?: "file_${System.currentTimeMillis()}.$extension")

        // Validate extension if allowedExtensions is configured
        val allowedExts = options?.allowedExtensions
        if (!allowedExts.isNullOrEmpty()) {
            val normalizedExt = extension.lowercase()
            val isAllowed = allowedExts.any { it.trim().lowercase() == normalizedExt }
            if (!isAllowed) {
                throw FlutterError(
                    "unsupported_file_type",
                    "Selected file '$displayName' with extension '.$extension' is not allowed",
                    null
                )
            }
        }

        // Validate MIME type if allowedMimeTypes is configured
        val allowedMimes = options?.allowedMimeTypes
        if (!allowedMimes.isNullOrEmpty()) {
            val normalizedMime = detectedMime.lowercase()
            val isAllowed = allowedMimes.any { mimeMatches(normalizedMime, it.trim().lowercase()) }
            if (!isAllowed) {
                throw FlutterError(
                    "unsupported_file_type",
                    "Selected file '$displayName' with MIME type '$detectedMime' is not allowed",
                    null
                )
            }
        }

        // Prepare unique destination file to prevent collisions and path traversal
        val uniqueName = "${UUID.randomUUID()}_$displayName"
        val targetFile = File(cacheDir, uniqueName)
        activeProcessingFiles.add(targetFile.absolutePath)
        createdFiles.add(targetFile)

        val maxSizeBytes = options?.maxSizeBytes

        try {
            val inputStream = resolver.openInputStream(uri)
                ?: throw FlutterError(
                    "file_read_failed",
                    "Unable to open stream for URI: $uri",
                    null
                )

            inputStream.use { input ->
                FileOutputStream(targetFile).use { output ->
                    val buffer = ByteArray(BUFFER_SIZE)
                    var bytesRead: Int
                    var totalWritten: Long = 0

                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        totalWritten += bytesRead
                        if (maxSizeBytes != null && totalWritten > maxSizeBytes) {
                            throw FlutterError(
                                "maximum_size_exceeded",
                                "File '$displayName' exceeds maximum size of $maxSizeBytes bytes (copied $totalWritten bytes)",
                                null
                            )
                        }
                        output.write(buffer, 0, bytesRead)
                    }
                    output.flush()
                }
            }
        } catch (e: FlutterError) {
            targetFile.delete()
            throw e
        } catch (e: SecurityException) {
            targetFile.delete()
            throw FlutterError(
                "file_access_denied",
                "Permission denied reading file '$displayName': ${e.message}",
                null
            )
        } catch (e: IOException) {
            targetFile.delete()
            val msg = e.message?.lowercase() ?: ""
            if (msg.contains("enospc") || msg.contains("no space left")) {
                throw FlutterError(
                    "insufficient_storage",
                    "Device storage full while copying '$displayName'",
                    null
                )
            }
            throw FlutterError(
                "file_copy_failed",
                "IO failure while copying '$displayName': ${e.message}",
                null
            )
        } finally {
            activeProcessingFiles.remove(targetFile.absolutePath)
        }

        val finalLength = targetFile.length()
        return PickedFileResult(
            path = targetFile.absolutePath,
            name = displayName,
            fileExtension = extension,
            mimeType = detectedMime,
            sizeBytes = finalLength
        )
    }

    private fun cleanupBatchFiles(files: List<File>) {
        for (file in files) {
            try {
                activeProcessingFiles.remove(file.absolutePath)
                if (file.exists()) {
                    file.delete()
                }
            } catch (_: Exception) {
            }
        }
    }

    private fun applyMimeFilters(intent: Intent, options: FilePickOptionsDto) {
        val mimeList = resolveMimeTypes(options)
        if (mimeList.size == 1 && !mimeList[0].contains(",")) {
            intent.type = mimeList[0]
        } else {
            intent.type = "*/*"
            intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeList.toTypedArray())
        }
    }

    private fun resolveMimeTypes(options: FilePickOptionsDto): List<String> {
        val type = options.filterType ?: "any"
        val mimes = mutableSetOf<String>()

        when (type) {
            "images" -> mimes.add("image/*")
            "videos" -> mimes.add("video/*")
            "audio" -> mimes.add("audio/*")
            "documents" -> {
                mimes.addAll(
                    listOf(
                        "application/pdf",
                        "application/msword",
                        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                        "application/vnd.ms-excel",
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                        "application/vnd.ms-powerpoint",
                        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
                        "text/plain",
                        "text/csv",
                        "application/json",
                        "application/rtf",
                        "application/vnd.oasis.opendocument.text",
                        "application/vnd.oasis.opendocument.spreadsheet",
                        "application/vnd.oasis.opendocument.presentation",
                        "text/html",
                        "text/xml",
                        "application/xml"
                    )
                )
            }
            "archives" -> {
                mimes.addAll(
                    listOf(
                        "application/zip",
                        "application/x-tar",
                        "application/gzip",
                        "application/x-7z-compressed",
                        "application/x-rar-compressed",
                        "application/x-bzip2",
                        "application/x-xz"
                    )
                )
            }
            else -> {
                // custom or any
                options.allowedMimeTypes?.forEach { mime ->
                    val clean = mime.trim()
                    if (clean.isNotEmpty()) mimes.add(clean)
                }

                options.allowedExtensions?.forEach { ext ->
                    val clean = ext.trim().lowercase().removePrefix(".")
                    val mime = EXTENSION_MIME_FALLBACK[clean]
                        ?: MimeTypeMap.getSingleton().getMimeTypeFromExtension(clean)
                    if (mime != null) {
                        mimes.add(mime)
                    } else {
                        // Extension without a known MIME type, SAF needs */*
                        mimes.add("*/*")
                    }
                }
            }
        }

        if (mimes.isEmpty() || mimes.contains("*/*")) {
            return listOf("*/*")
        }
        return mimes.toList()
    }

    private fun mimeMatches(actualMime: String, pattern: String): Boolean {
        if (pattern == "*/*" || pattern == actualMime) return true
        if (pattern.endsWith("/*")) {
            val prefix = pattern.substringBefore('/')
            return actualMime.startsWith("$prefix/")
        }
        return false
    }

    private fun getDisplayName(ctx: Context, uri: Uri): String? {
        val resolver = ctx.contentResolver ?: return null
        return try {
            resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index != -1 && cursor.moveToFirst()) {
                    cursor.getString(index)
                } else null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun getMimeFromUriOrName(uri: Uri, displayName: String?): String {
        val path = displayName ?: uri.path ?: ""
        val ext = path.substringAfterLast('.', "").lowercase()
        if (ext.isNotEmpty()) {
            EXTENSION_MIME_FALLBACK[ext]?.let { return it }
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext)?.let { return it }
        }
        return "application/octet-stream"
    }

    private fun getExtension(displayName: String?, mimeType: String): String {
        if (!displayName.isNullOrBlank() && displayName.contains('.')) {
            val ext = displayName.substringAfterLast('.').lowercase()
            if (ext.isNotBlank() && ext.length in 1..10 && ext.all { it.isLetterOrDigit() }) {
                return ext
            }
        }
        val fromMime = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType)
        if (!fromMime.isNullOrBlank()) return fromMime.lowercase()

        // Reverse search in fallback
        for ((k, v) in EXTENSION_MIME_FALLBACK) {
            if (v.equals(mimeType, ignoreCase = true)) return k
        }
        return "bin"
    }

    private fun sanitizeFileName(rawName: String): String {
        val base = File(rawName).name // Strips any directory traversal prefixes
        val cleaned = base.replace(Regex("[^a-zA-Z0-9._-]"), "_")
        return if (cleaned.isBlank() || cleaned == "." || cleaned == "..") {
            "file_${System.currentTimeMillis()}"
        } else {
            cleaned
        }
    }
}

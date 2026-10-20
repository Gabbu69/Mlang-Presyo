package app.presyomlang.personal

import java.io.IOException
import java.io.OutputStream

/** No Android dependency: stream lifetime and failures can be tested on the JVM. */
internal object CheckedExportWriter {
    fun write(bytes: ByteArray, openStream: () -> OutputStream?) {
        val stream = openStream() ?: throw IOException("No writable export stream")
        stream.use { output ->
            output.write(bytes)
            output.flush()
        }
    }
}

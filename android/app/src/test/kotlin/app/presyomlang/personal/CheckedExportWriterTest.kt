package app.presyomlang.personal

import java.io.IOException
import java.io.OutputStream
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CheckedExportWriterTest {
    private class RecordingStream(
        val writeFailure: IOException? = null,
        val flushFailure: IOException? = null,
        val closeFailure: IOException? = null,
    ) : OutputStream() {
        val events = mutableListOf<String>()
        var received = byteArrayOf()

        override fun write(value: Int) {
            received += value.toByte()
        }

        override fun write(bytes: ByteArray) {
            events += "write"
            writeFailure?.let { throw it }
            received = bytes.copyOf()
        }

        override fun flush() {
            events += "flush"
            flushFailure?.let { throw it }
        }

        override fun close() {
            events += "close"
            closeFailure?.let { throw it }
        }
    }

    @Test
    fun successRequiresWriteFlushAndCloseInOrder() {
        val stream = RecordingStream()
        val bytes = "Fictional export ₱".toByteArray(Charsets.UTF_8)
        CheckedExportWriter.write(bytes) { stream }
        assertArrayEquals(bytes, stream.received)
        assertEquals(listOf("write", "flush", "close"), stream.events)
    }

    @Test
    fun nullProviderStreamFailsInsteadOfConfirmingBackup() {
        assertThrows(IOException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1, 2)) { null }
        }
    }

    @Test
    fun permissionFailureIsPropagatedToTheBridgeErrorHandler() {
        val failure = SecurityException("Fictional denied grant")
        assertSame(failure, assertThrows(SecurityException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1)) { throw failure }
        })
    }

    @Test
    fun writeFailureStillClosesTheStreamAndCannotSucceed() {
        val failure = IOException("Fictional write failure")
        val stream = RecordingStream(writeFailure = failure)
        assertSame(failure, assertThrows(IOException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1)) { stream }
        })
        assertEquals(listOf("write", "close"), stream.events)
    }

    @Test
    fun flushFailureStillClosesTheStreamAndCannotSucceed() {
        val failure = IOException("Fictional flush failure")
        val stream = RecordingStream(flushFailure = failure)
        assertSame(failure, assertThrows(IOException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1)) { stream }
        })
        assertEquals(listOf("write", "flush", "close"), stream.events)
    }

    @Test
    fun closeFailureCannotBeReportedAsSuccessfulExport() {
        val failure = IOException("Fictional close failure")
        val stream = RecordingStream(closeFailure = failure)
        assertSame(failure, assertThrows(IOException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1)) { stream }
        })
        assertTrue(stream.events.contains("close"))
    }

    @Test
    fun closeFailureDoesNotHideTheOriginalWriteFailure() {
        val writeFailure = IOException("Fictional write failure")
        val closeFailure = IOException("Fictional close failure")
        val stream = RecordingStream(writeFailure = writeFailure, closeFailure = closeFailure)
        val result = assertThrows(IOException::class.java) {
            CheckedExportWriter.write(byteArrayOf(1)) { stream }
        }
        assertSame(writeFailure, result)
        assertArrayEquals(arrayOf(closeFailure), result.suppressed)
    }
}

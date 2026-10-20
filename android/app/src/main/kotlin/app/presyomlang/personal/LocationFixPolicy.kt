package app.presyomlang.personal

import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

internal data class CheckedLocationFix(
    val latitudeE6: Int,
    val longitudeE6: Int,
    val accuracyM: Int,
    val capturedAtMillis: Long,
)

internal enum class PhoneLocationProvider { GPS, NETWORK }

/** Pure validation/conversion shared by fresh fixes and eligible cached fixes. */
internal object LocationFixPolicy {
    /** Approximate access may use network location, but must never enable GPS. */
    fun permittedProviders(
        fineGranted: Boolean,
        coarseGranted: Boolean,
        gpsEnabled: Boolean,
        networkEnabled: Boolean,
    ): List<PhoneLocationProvider> = buildList {
        if (fineGranted && gpsEnabled) add(PhoneLocationProvider.GPS)
        if ((fineGranted || coarseGranted) && networkEnabled) add(PhoneLocationProvider.NETWORK)
    }

    /** Freshness wins across providers; reported accuracy breaks timestamp ties. */
    fun newestCached(fixes: Iterable<CheckedLocationFix>): CheckedLocationFix? =
        fixes.maxWithOrNull(
            compareBy<CheckedLocationFix> { it.capturedAtMillis }
                .thenByDescending { it.accuracyM },
        )

    fun check(
        latitude: Double,
        longitude: Double,
        accuracyM: Double,
        capturedAtMillis: Long,
        nowMillis: Long,
    ): CheckedLocationFix? {
        if (!latitude.isFinite() || latitude !in -90.0..90.0 ||
            !longitude.isFinite() || longitude !in -180.0..180.0 ||
            !accuracyM.isFinite() || accuracyM < 0 || accuracyM > 100000 ||
            capturedAtMillis <= 0 || nowMillis <= 0 ||
            capturedAtMillis < nowMillis - 120000 ||
            capturedAtMillis > nowMillis + 5000
        ) return null
        return CheckedLocationFix(
            (latitude * 1000000).roundToInt(),
            (longitude * 1000000).roundToInt(),
            max(1, ceil(accuracyM).toInt()),
            capturedAtMillis,
        )
    }
}

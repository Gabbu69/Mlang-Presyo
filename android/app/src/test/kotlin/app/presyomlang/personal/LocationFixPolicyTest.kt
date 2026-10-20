package app.presyomlang.personal

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class LocationFixPolicyTest {
    private val now = 1800000000000L

    @Test
    fun finePermissionKeepsBothEnabledProvidersEligible() {
        assertEquals(
            listOf(PhoneLocationProvider.GPS, PhoneLocationProvider.NETWORK),
            LocationFixPolicy.permittedProviders(true, true, true, true),
        )
        // Fine is sufficient even if a vendor reports coarse separately false.
        assertEquals(
            listOf(PhoneLocationProvider.GPS, PhoneLocationProvider.NETWORK),
            LocationFixPolicy.permittedProviders(true, false, true, true),
        )
    }

    @Test
    fun approximatePermissionUsesNetworkAndNeverGps() {
        assertEquals(
            listOf(PhoneLocationProvider.NETWORK),
            LocationFixPolicy.permittedProviders(false, true, true, true),
        )
        assertEquals(
            emptyList<PhoneLocationProvider>(),
            LocationFixPolicy.permittedProviders(false, true, true, false),
        )
    }

    @Test
    fun providerSelectionExcludesDisabledAndUnpermittedSources() {
        assertEquals(
            emptyList<PhoneLocationProvider>(),
            LocationFixPolicy.permittedProviders(false, false, true, true),
        )
        assertEquals(
            emptyList<PhoneLocationProvider>(),
            LocationFixPolicy.permittedProviders(true, true, false, false),
        )
        assertEquals(
            listOf(PhoneLocationProvider.GPS),
            LocationFixPolicy.permittedProviders(true, true, true, false),
        )
        assertEquals(
            listOf(PhoneLocationProvider.NETWORK),
            LocationFixPolicy.permittedProviders(true, true, false, true),
        )
    }

    @Test
    fun newestCachedFixWinsAcrossProvidersBeforeAccuracy() {
        val olderGps = LocationFixPolicy.check(7.0, 125.0, 5.0, now - 60000, now)!!
        val newerNetwork = LocationFixPolicy.check(8.0, 126.0, 1500.0, now - 1000, now)!!
        assertEquals(newerNetwork, LocationFixPolicy.newestCached(listOf(olderGps, newerNetwork)))
        assertEquals(newerNetwork, LocationFixPolicy.newestCached(listOf(newerNetwork, olderGps)))
    }

    @Test
    fun cachedChoiceIgnoresInvalidFixesAndUsesAccuracyForEqualTimes() {
        val staleGps = LocationFixPolicy.check(7.0, 125.0, 1.0, now - 120001, now)
        val approximate = LocationFixPolicy.check(8.0, 126.0, 1500.0, now, now)!!
        val precise = LocationFixPolicy.check(8.0, 126.0, 10.0, now, now)!!
        assertEquals(precise, LocationFixPolicy.newestCached(listOfNotNull(staleGps, approximate, precise)))
        assertEquals(precise, LocationFixPolicy.newestCached(listOf(precise, approximate)))
        assertNull(LocationFixPolicy.newestCached(emptyList()))
        assertNull(LocationFixPolicy.newestCached(listOfNotNull(staleGps)))
    }

    @Test
    fun convertsMicrodegreesAndRoundsApproximateAccuracyUp() {
        val fix = LocationFixPolicy.check(7.1234567, 125.7654321, 1499.1, now - 1000, now)!!
        assertEquals(7123457, fix.latitudeE6)
        assertEquals(125765432, fix.longitudeE6)
        assertEquals(1500, fix.accuracyM)
        assertEquals(now - 1000, fix.capturedAtMillis)
    }

    @Test
    fun acceptsExactFreshnessAndAccuracyBounds() {
        assertNotNull(LocationFixPolicy.check(-90.0, -180.0, 100000.0, now - 120000, now))
        assertNotNull(LocationFixPolicy.check(90.0, 180.0, 1.0, now + 5000, now))
        assertNull(LocationFixPolicy.check(7.0, 125.0, 1.0, now - 120001, now))
        assertNull(LocationFixPolicy.check(7.0, 125.0, 1.0, now + 5001, now))
    }

    @Test
    fun retainsZeroCoordinatesAndUsesOneMetreMinimumAccuracy() {
        val fix = LocationFixPolicy.check(0.0, 0.0, 0.0, now, now)!!
        assertEquals(0, fix.latitudeE6)
        assertEquals(0, fix.longitudeE6)
        assertEquals(1, fix.accuracyM)
    }

    @Test
    fun rejectsUnknownOrExcessiveAccuracy() {
        for (accuracy in listOf(-1.0, 100000.1, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertNull(LocationFixPolicy.check(7.0, 125.0, accuracy, now, now))
        }
    }

    @Test
    fun rejectsInvalidAndNonFiniteCoordinates() {
        for (latitude in listOf(-90.1, 90.1, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertNull(LocationFixPolicy.check(latitude, 125.0, 1.0, now, now))
        }
        for (longitude in listOf(-180.1, 180.1, Double.NaN, Double.NEGATIVE_INFINITY)) {
            assertNull(LocationFixPolicy.check(7.0, longitude, 1.0, now, now))
        }
    }

    @Test
    fun rejectsMissingTimestampInsteadOfReplacingItWithRequestTime() {
        assertNull(LocationFixPolicy.check(7.0, 125.0, 1.0, 0, now))
        assertNull(LocationFixPolicy.check(7.0, 125.0, 1.0, -1, now))
    }
}

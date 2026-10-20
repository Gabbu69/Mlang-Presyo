package app.presyomlang.personal

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** A foreground, user-initiated one-shot request using only Android providers. */
internal class AndroidLocation(private val activity: Activity) : LocationListener {
    private class Pending(val result: MethodChannel.Result) {
        var timeout: Runnable? = null
    }

    private val handler = Handler(Looper.getMainLooper())
    private val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
    private var pending: Pending? = null
    private var requestingPermission = false
    private var listening = false
    private val activeProviders = mutableSetOf<String>()
    private var started = false
    private var destroyed = false

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "currentLocation") {
            result.notImplemented()
            return
        }
        // A queued channel call can arrive after onStop even though the
        // Activity remains alive. Never start a new capture while stopped.
        if (!started || destroyed || activity.isFinishing || activity.isDestroyed) {
            result.error("canceled", "Location capture was canceled.", null)
            return
        }
        if (pending != null || requestingPermission) {
            result.error("busy", "A location request is already open.", null)
            return
        }
        val request = Pending(result)
        pending = request
        try {
            if (!hasPermission()) {
                requestingPermission = true
                // Android 12+ requires requesting approximate and precise
                // together; approximate alone is an accepted final grant.
                activity.requestPermissions(
                    arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION, Manifest.permission.ACCESS_FINE_LOCATION),
                    PERMISSION_REQUEST_CODE,
                )
            } else {
                beginCapture()
            }
        } catch (_: SecurityException) {
            requestingPermission = false
            finishError("denied")
        } catch (_: Exception) {
            requestingPermission = false
            finishError("unavailable")
        }
    }

    fun onPermissionResult(requestCode: Int): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        requestingPermission = false
        if (pending == null) return true
        if (!started || destroyed) {
            finishError("canceled")
            return true
        }
        if (!hasPermission()) finishError("denied") else beginCapture()
        return true
    }

    private fun hasPermission(): Boolean =
        activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun beginCapture() {
        val request = pending ?: return
        if (!started || destroyed) {
            finishError("canceled")
            return
        }
        val locationManager = manager
        if (locationManager == null) {
            finishError("unavailable")
            return
        }
        // Time only acquisition. The user may take as long as needed to read
        // and answer Android's permission dialog before capture starts.
        if (request.timeout == null) {
            request.timeout = Runnable {
                if (pending === request) finishError("timeout")
            }.also { handler.postDelayed(it, 20000) }
        }
        try {
            val fine = activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val coarse = activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
            val gps = providerEnabled(locationManager, LocationManager.GPS_PROVIDER)
            val network = providerEnabled(locationManager, LocationManager.NETWORK_PROVIDER)
            val providers = LocationFixPolicy.permittedProviders(fine, coarse, gps, network).map {
                when (it) {
                    PhoneLocationProvider.GPS -> LocationManager.GPS_PROVIDER
                    PhoneLocationProvider.NETWORK -> LocationManager.NETWORK_PROVIDER
                }
            }
            if (providers.isEmpty()) {
                finishError(when {
                    !fine && !coarse -> "denied"
                    !gps && !network -> "disabled"
                    // Approximate access cannot use a GPS-only provider.
                    else -> "unavailable"
                })
                return
            }
            // Inspect all eligible caches before choosing: enabling GPS must
            // not hide a newer usable approximate/network position indoors.
            val cached = LocationFixPolicy.newestCached(providers.mapNotNull { provider ->
                try {
                    locationManager.getLastKnownLocation(provider)?.let(::checkedFix)
                } catch (_: Exception) {
                    // One unavailable/revoked provider must not block another.
                    null
                }
            })
            if (cached != null && accept(cached)) return
            for (provider in providers) {
                if (pending !== request) return
                activeProviders.add(provider)
                // Set before requesting so even a partially failed platform
                // registration is covered by the shared listener cleanup.
                listening = true
                try {
                    locationManager.requestLocationUpdates(provider, 0L, 0f, this, Looper.getMainLooper())
                } catch (_: Exception) {
                    activeProviders.remove(provider)
                }
            }
            if (pending === request && activeProviders.isEmpty()) {
                finishError(if (hasPermission()) "unavailable" else "denied")
            }
        } catch (_: SecurityException) {
            finishError("denied")
        } catch (_: Exception) {
            finishError("unavailable")
        }
    }

    override fun onLocationChanged(location: Location) {
        // Ignore callbacks already queued for a previous capture/provider.
        if (pending != null && location.provider in activeProviders) {
            checkedFix(location)?.let(::accept)
        }
    }

    private fun providerEnabled(locationManager: LocationManager, provider: String): Boolean =
        try {
            locationManager.isProviderEnabled(provider)
        } catch (_: Exception) {
            false
        }

    private fun checkedFix(location: Location): CheckedLocationFix? {
        if (!location.hasAccuracy()) return null
        return LocationFixPolicy.check(
            location.latitude, location.longitude, location.accuracy.toDouble(),
            location.time, System.currentTimeMillis(),
        )
    }

    private fun accept(fix: CheckedLocationFix): Boolean {
        val request = pending ?: return false
        pending = null
        cleanup(request)
        val utc = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date(fix.capturedAtMillis))
        request.result.success(mapOf(
            "latitudeE6" to fix.latitudeE6,
            "longitudeE6" to fix.longitudeE6,
            "accuracyM" to fix.accuracyM,
            "capturedAtUtc" to utc,
        ))
        return true
    }

    override fun onProviderDisabled(provider: String) {
        val wasActive = activeProviders.remove(provider)
        if (wasActive && pending != null && activeProviders.isEmpty()) finishError("disabled")
    }

    override fun onProviderEnabled(provider: String) = Unit

    @Deprecated("Required for older Android location callbacks")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun finishError(code: String) {
        val request = pending ?: return
        pending = null
        cleanup(request)
        // Coordinates and system exception details never enter errors or logs.
        request.result.error(code, "A current location could not be captured. Enter it manually.", null)
    }

    private fun cleanup(request: Pending) {
        request.timeout?.let(handler::removeCallbacks)
        activeProviders.clear()
        if (listening) {
            listening = false
            try {
                manager?.removeUpdates(this)
            } catch (_: Exception) {
                // A revoked grant must still complete and stop this request.
            }
        }
    }

    fun onStart() {
        if (!destroyed) started = true
    }

    fun onStop() {
        started = false
        finishError("canceled")
    }

    fun onDestroy() {
        started = false
        destroyed = true
        finishError("canceled")
        handler.removeCallbacksAndMessages(null)
    }

    private companion object {
        const val PERMISSION_REQUEST_CODE = 0x504E
    }
}

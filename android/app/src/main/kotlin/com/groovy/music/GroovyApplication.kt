package com.groovy.music

import android.app.Application
import android.util.Log

/**
 * Custom Application class declared in AndroidManifest.xml via
 * `android:name=".GroovyApplication"`.
 *
 * Android requires this class to exist at process startup.
 */
class GroovyApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        Log.d("GroovyApplication", "Groovy application started")
    }
}

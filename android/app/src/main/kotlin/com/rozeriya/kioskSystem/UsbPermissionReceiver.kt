package com.rozeriya.kiosksystem

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.util.Log

class UsbPermissionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "UsbPermissionReceiver"
        const val ACTION_USB_PERMISSION = "com.example.smart_usb.USB_PERMISSION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (ACTION_USB_PERMISSION == action) {
            try {
                val device: UsbDevice? = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                val granted: Boolean = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                
                if (granted && device != null) {
                    Log.d(TAG, "Permission granted for device ${device.deviceName}")
                } else {
                    Log.d(TAG, "Permission denied for device")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in USB permission receiver: ${e.message}")
            }
        }
    }
}
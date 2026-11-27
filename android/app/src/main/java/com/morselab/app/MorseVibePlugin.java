package com.morselab.app;

import android.content.Context;
import android.media.AudioAttributes;
import android.os.Build;
import android.os.VibrationAttributes;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

/**
 * Vibration pour le Morse.
 * Le plugin Haptics standard vibre sans catégorie d'usage : sur Android 13+ (Samsung surtout),
 * ces vibrations sont souvent coupées par le mode silencieux ou le réglage « retour tactile ».
 * Ici on vibre à amplitude maximale avec l'usage ALARM, et on expose cancel() pour la clé.
 */
@CapacitorPlugin(name = "MorseVibe")
public class MorseVibePlugin extends Plugin {

    private Vibrator vibrator;

    @Override
    public void load() {
        Context ctx = getContext();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            VibratorManager vm = (VibratorManager) ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
            vibrator = vm != null ? vm.getDefaultVibrator() : null;
        } else {
            vibrator = (Vibrator) ctx.getSystemService(Context.VIBRATOR_SERVICE);
        }
    }

    @PluginMethod
    public void vibrate(PluginCall call) {
        int duration = Math.max(1, call.getInt("duration", 100));
        if (vibrator == null || !vibrator.hasVibrator()) {
            call.reject("Pas de vibreur");
            return;
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) {
                VibrationEffect fx = VibrationEffect.createOneShot(duration, 255);
                vibrator.vibrate(fx, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM));
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                VibrationEffect fx = VibrationEffect.createOneShot(duration, 255);
                AudioAttributes aa = new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build();
                vibrator.vibrate(fx, aa);
            } else {
                vibratePre26(duration);
            }
            call.resolve();
        } catch (Exception e) {
            call.reject(e.getMessage());
        }
    }

    @PluginMethod
    public void cancel(PluginCall call) {
        if (vibrator != null) vibrator.cancel();
        call.resolve();
    }

    @SuppressWarnings("deprecation")
    private void vibratePre26(int duration) {
        vibrator.vibrate(duration);
    }
}

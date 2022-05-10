package dev.pharsh.logcat;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.util.Log;

import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.security.InvalidAlgorithmParameterException;
import java.security.InvalidKeyException;
import java.security.NoSuchAlgorithmException;
import java.security.spec.AlgorithmParameterSpec;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import javax.crypto.Cipher;
import javax.crypto.CipherOutputStream;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/**
 * LogcatPlugin
 */
public class LogcatPlugin implements MethodCallHandler {
    private Context moContext;
    private static final String TAG = LogcatPlugin.class.getSimpleName();
    public static final String LOG_FILE_NAME = "android_app.log";

    public LogcatPlugin(Context moContext) {
        this.moContext = moContext;
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "app.channel.logcat");
        channel.setMethodCallHandler(new LogcatPlugin(registrar.context()));
    }


    @Override
    public void onMethodCall(MethodCall call, Result result) {
        switch (call.method) {
            case "execLogcat":
                String logs = getLogs();
                if (logs != null) {
                    result.success(logs);
                } else {
                    result.error("UNAVAILABLE", "logs not available.", null);
                }
                break;
            case "zipLogFile":
                zipLogFile(call, result);
                break;
            case "encrypt":
                encrypt(call, result);
                break;
            case "isAutoRotateMode":
                result.success(isAutoRotateMode());
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    boolean isAutoRotateMode() {
        if (android.provider.Settings.System.getInt(moContext.getContentResolver(),
                Settings.System.ACCELEROMETER_ROTATION, 0) == 1){
            return true;
        }
        else{
            return false;
        }
    }

    String getLogs() {
        try {
            Process process = Runtime.getRuntime().exec("logcat -d");
            BufferedReader bufferedReader = new BufferedReader(new InputStreamReader(process.getInputStream()));

            StringBuilder log = new StringBuilder();
            String line;
            while ((line = bufferedReader.readLine()) != null) {
                log.append(line);
            }
            return log.toString();
        } catch (IOException e) {
            return "EXCEPTION" + e.toString();
        }
    }

    private void zipLogFile(final MethodCall poCall, final Result poResult) {

        new Thread() {
            public void run() {
                String srcFilePath = poCall.argument("srcFilePath");
                String dstFilePath = poCall.argument("dstFilePath");

                final boolean connected = zipLogFile(srcFilePath, dstFilePath);

                final Handler handler = new Handler(Looper.getMainLooper());
                handler.post(new Runnable() {
                    @Override
                    public void run () {
                        poResult.success(connected);
                    }
                });
            }
        }.start();
    }


    /**
     * Should use this zip method for unzip on web
     * @param srcFilePath log file path (hubblelog.log)
     * @param dstFilePath zipped file path (hubblelog.zip)
     * @return
     */
    public static boolean zipLogFile(String srcFilePath, String dstFilePath) {
        final int BUFFER = 2048;
        try {
            BufferedInputStream origin;
            FileOutputStream dest = new FileOutputStream(dstFilePath);
            ZipOutputStream out = new ZipOutputStream(new BufferedOutputStream(dest));

            File logFile = new File(srcFilePath);
            try {
                byte data[] = new byte[BUFFER];
                Log.i(TAG, "FILE PATH: " + srcFilePath);
                FileInputStream fi = new FileInputStream(logFile);
                origin = new BufferedInputStream(fi, BUFFER);
                ZipEntry entry = new ZipEntry(LOG_FILE_NAME);
                out.putNextEntry(entry);
                int count;
                while ((count = origin.read(data, 0, BUFFER)) != -1) {
                    out.write(data, 0, count);
                }
                origin.close();
            } catch (Exception ex) {
                ex.printStackTrace();
                ZipEntry entry = new ZipEntry("Phone is rooted");
                out.putNextEntry(entry);
            }

            out.close();
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
        return true;
    }


    private void encrypt(final MethodCall poCall, final Result poResult) {

        new Thread() {
            public void run() {
                String plainFilePath = poCall.argument("plainFilePath");
                String cipherFilePath = poCall.argument("cipherFilePath");
                String key = poCall.argument("key");
                try {
                    encrypt(plainFilePath, cipherFilePath, key);
                } catch (IOException e) {
                    e.printStackTrace();
                } catch (NoSuchAlgorithmException e) {
                    e.printStackTrace();
                } catch (NoSuchPaddingException e) {
                    e.printStackTrace();
                } catch (InvalidKeyException e) {
                    e.printStackTrace();
                } catch (InvalidAlgorithmParameterException e) {
                    e.printStackTrace();
                }

                final Handler handler = new Handler(Looper.getMainLooper());
                handler.post(new Runnable() {
                    @Override
                    public void run () {
                        poResult.success(null);
                    }
                });
            }
        }.start();
    }

    public static void encrypt(String plainFilePath, String cipherFilePath, String encryptString)
            throws IOException, NoSuchAlgorithmException,
            NoSuchPaddingException, InvalidKeyException, InvalidAlgorithmParameterException {
        // String encryptString="Super-LovelyDuck";
        // Here you read the cleartext.
        FileInputStream fis = new FileInputStream(plainFilePath);
        // This stream write the encrypted text. This stream will be wrapped by
        // another stream.
        FileOutputStream fos = new FileOutputStream(cipherFilePath);

        // Length is 16 byte
        AlgorithmParameterSpec iv;
        SecretKeySpec sks;
        try {
            sks = new SecretKeySpec(encryptString.getBytes(), "AES");
            iv = new IvParameterSpec(encryptString.getBytes());
        } catch (Exception e) {
            Log.e(TAG, e.toString());
            throw e;
        }
        // Create cipher
        Cipher cipher = Cipher.getInstance("AES/CBC/PKCS5Padding");
        cipher.init(Cipher.ENCRYPT_MODE, sks, iv);
        // Wrap the output stream
        CipherOutputStream cos = new CipherOutputStream(fos, cipher);
        // Write bytes
        int b;
        byte[] d = new byte[4096];
        while ((b = fis.read(d)) != -1) {
            cos.write(d, 0, b);
        }
        // Flush and close streams.
        cos.flush();
        cos.close();
        fis.close();
    }

}

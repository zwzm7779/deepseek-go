package com.daiyihui.app;

import android.annotation.SuppressLint;
import android.content.pm.ActivityInfo;
import android.os.Build;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;


public class MainActivity extends android.app.Activity {
    private WebView web;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        applyBars();
        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        if (Build.VERSION.SDK_INT >= 21) s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        web.setWebViewClient(new WebViewClient() {
            @Override
            public void onReceivedError(WebView view, int errorCode, String description, String failingUrl) {
                view.loadUrl("file:///android_asset/index.html");
            }
        });
        web.addJavascriptInterface(new OrientationBridge(), "dshOrientation");
        setContentView(web);
        // 开发模式：优先加载本机服务器上的页面，便于快速迭代；不可用时自动回退到内置页面
        web.loadUrl("http://127.0.0.1:8765/index.html");
    }

    private void applyBars() {
        if (Build.VERSION.SDK_INT >= 21) {
            getWindow().setStatusBarColor(Color.TRANSPARENT);
            getWindow().setNavigationBarColor(Color.TRANSPARENT);
        }
        if (Build.VERSION.SDK_INT >= 23) {
            View v = getWindow().getDecorView();
            int f = v.getSystemUiVisibility()
                    | View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                    | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                    | View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR;
            if (Build.VERSION.SDK_INT >= 26) f |= View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR;
            v.setSystemUiVisibility(f);
            web.post(new Runnable() {
                public void run() {
                    int id = getResources().getIdentifier("status_bar_height", "dimen", "android");
                    int h = (id > 0) ? getResources().getDimensionPixelSize(id) : (int) (24 * getResources().getDisplayMetrics().density);
                    web.evaluateJavascript("document.documentElement.style.setProperty('--sys-top','" + h + "px')", null);
                }
            });
        }
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        applyBars();
    }

    public class OrientationBridge {
        @JavascriptInterface
        public void setOrientation(final String mode) {
            runOnUiThread(new Runnable() {
                public void run() {
                    if ("auto".equals(mode)) {
                        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR);
                    } else {
                        setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
        applyBars();
                    }
                }
            });
        }
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) { web.goBack(); return; }
        super.onBackPressed();
    }
}

"""Apply Nilvai's settings to the Android project that `flutter create` generates.

    flutter create --org org.nilvai --project-name nilvai --platforms android .
    python tool/patch_android.py

Safe to run more than once. Fails loudly if Flutter's template has changed shape.
- app id org.nilvai.app, label "Nilvai"
- INTERNET permission (OCR server) and plain HTTP to the laptop on the local network / Tailscale
- release signing from environment variables (CI secrets); never a key in the repo
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent / "android" / "app"
manifest = root / "src" / "main" / "AndroidManifest.xml"
kts = root / "build.gradle.kts"
groovy = root / "build.gradle"


def fail(msg):
    sys.exit(f"patch_android: {msg}")


# ---------- Manifest ----------
m = manifest.read_text(encoding="utf-8")
if "android.permission.INTERNET" not in m:
    m = m.replace("<application", '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
if "usesCleartextTraffic" not in m:
    m = m.replace("<application", '<application\n        android:usesCleartextTraffic="true"', 1)
m = re.sub(r'android:label="[^"]*"', 'android:label="Nilvai"', m, count=1)
manifest.write_text(m, encoding="utf-8")

# ---------- Gradle ----------
if kts.exists():
    g = kts.read_text(encoding="utf-8")
    g, n = re.subn(r'applicationId\s*=\s*"[^"]*"', 'applicationId = "org.nilvai.app"', g, count=1)
    if n != 1:
        fail("applicationId not found in build.gradle.kts")
    if "NILVAI_KEYSTORE" not in g:
        block = '''    signingConfigs {
        create("release") {
            val ks = System.getenv("NILVAI_KEYSTORE")
            if (ks != null) {
                storeFile = file(ks)
                storePassword = System.getenv("NILVAI_STORE_PASSWORD")
                keyAlias = System.getenv("NILVAI_KEY_ALIAS") ?: "nilvai"
                keyPassword = System.getenv("NILVAI_KEY_PASSWORD") ?: System.getenv("NILVAI_STORE_PASSWORD")
            }
        }
    }

    buildTypes {'''
        g, n = re.subn(r"^    buildTypes \{", block, g, count=1, flags=re.M)
        if n != 1:
            fail("buildTypes block not found in build.gradle.kts")
        g, n = re.subn(
            r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)',
            'signingConfig = if (System.getenv("NILVAI_KEYSTORE") != null) signingConfigs.getByName("release") '
            'else signingConfigs.getByName("debug")',
            g, count=1)
        if n != 1:
            fail("release signingConfig line not found in build.gradle.kts")
    kts.write_text(g, encoding="utf-8")
elif groovy.exists():
    g = groovy.read_text(encoding="utf-8")
    g, n = re.subn(r'applicationId\s*=?\s*"[^"]*"', 'applicationId = "org.nilvai.app"', g, count=1)
    if n != 1:
        fail("applicationId not found in build.gradle")
    if "NILVAI_KEYSTORE" not in g:
        block = '''    signingConfigs {
        release {
            if (System.getenv("NILVAI_KEYSTORE")) {
                storeFile = file(System.getenv("NILVAI_KEYSTORE"))
                storePassword = System.getenv("NILVAI_STORE_PASSWORD")
                keyAlias = System.getenv("NILVAI_KEY_ALIAS") ?: "nilvai"
                keyPassword = System.getenv("NILVAI_KEY_PASSWORD") ?: System.getenv("NILVAI_STORE_PASSWORD")
            }
        }
    }

    buildTypes {'''
        g, n = re.subn(r"^    buildTypes \{", block, g, count=1, flags=re.M)
        if n != 1:
            fail("buildTypes block not found in build.gradle")
        g = re.sub(r"signingConfig\s*=?\s*signingConfigs\.debug",
                   'signingConfig = System.getenv("NILVAI_KEYSTORE") ? signingConfigs.release : signingConfigs.debug',
                   g, count=1)
    groovy.write_text(g, encoding="utf-8")
else:
    fail("no android/app/build.gradle(.kts): run flutter create first")

print("patch_android: done")

# BUILD.md

## Supported build target

Primary build target:
- armv7
- iOS 5.1 deployment target
- iOS 6.1 legacy SDK
- Theos

Expected Makefile settings:
```make
ARCHS = armv7
TARGET = iphone:clang:6.1:5.1
```

## Known user environment

Theos:
```text
/home/yeliz/theos
```

Legacy SDK source:
```text
/home/yeliz/legacy-ios-sdks/iPhoneOS6.1-extracted/iPhoneOS6.1.sdk
```

The SDK is symlinked into the Theos SDK directory.

## Build

From the version directory:
```bash
make clean
make package FINALPACKAGE=1
```

Example expected artifact for beta3:
```text
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
```

A warning such as:
```text
ld: warning: building for iOS 5.1.0 is deprecated
```
is expected and is not by itself a build failure.

## Common legacy compiler failures

### Misleading indentation
Old/strict Clang configuration may fail builds with `-Werror`.

Fix by expanding compressed loops/conditionals into explicit braces rather than disabling the warning.

### Protocol method missing
If a class declares protocol conformance, implement every required protocol method.

### Legacy SDK missing SecureTransport declarations
Some symbols may exist differently across legacy SDK/runtime combinations. Experimental TLS code must be availability-safe and must fail cleanly rather than forcing a modern SDK.

### Malformed class extension
Inside:
```objc
@interface AppDelegate ()
```
only put method declarations ending in `;`.

Never put a method body there.

## Copy package to iPad over LAN

Current iPad test address has been:
```text
192.168.1.2
```

Because its SSH server is old, modern OpenSSH may require RSA compatibility:
```bash
scp \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
packages/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb \
root@192.168.1.2:/var/mobile/
```

If the old server requires DSS, add it only to this command/host configuration. Do not enable obsolete algorithms globally.

## SSH to iPad

```bash
ssh \
-o HostKeyAlgorithms=+ssh-rsa \
-o PubkeyAcceptedAlgorithms=+ssh-rsa \
root@192.168.1.2
```

## Install on iPad

Run these **on the iPad**, not in WSL:
```bash
dpkg -i /var/mobile/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
killall SpringBoard
```

Optional verification before install:
```bash
ls -lh /var/mobile/com.olap.ipad1vnc_2.2.0-beta3_iphoneos-arm.deb
```

## Development rule

Do not overwrite the last known-good source directory during a risky beta change. Keep the previous build tree until the new version:
1. compiles,
2. installs,
3. launches,
4. passes baseline VNC tests.

# AURORA Analyzer V1.1.24.1 — Changelog

**Release Date:** 2026.05.27
**Current Version:** V1.1.24.1
**Previous Version:** V1.1.24.0
**Author:** AURORA VelociRaptor-GR Dev PRJ.
**Update Type:** Security Hardening & Defense-in-Depth Enhancement

---

## 🛡️ New Security Features

### 1. Named Pipe Watchdog Guardian

> **Overview:** On top of the existing RSA handshake protocol, a bidirectional HMAC-SHA256 challenge-response heartbeat mechanism between the EXE and PS1 has been added. Even if all PS1-level verifications are commented out or bypassed, the EXE watchdog can still detect anomalies and terminate the process. This forms an **independent fifth defense layer** in the defense-in-depth model.

**Core Mechanism:**

| Component | Description |
|---|---|
| **HMAC Key Derivation** | PBKDF2-SHA256(MasterPassword, WatchdogSalt, 10,000 iterations) → 32-byte HMAC key. Independently generated per build. |
| **Named Pipe Communication** | `AURORA_WD_{8-char random ID}` named pipe, PipeDirection.InOut, Byte transmission mode. |
| **Handshake Protocol** | EXE → PS1: `[0x10] [32B HMAC Key] [16B SessionID]`; PS1 → EXE: `[0x11]` ACK confirmation. |
| **Challenge-Response** | EXE: `[0x03] [16B Nonce] [8B Timestamp]` → PS1: `[0x04] [32B HMAC(Nonce,Key)] [8B SystemUptime] [32B SelfSHA256]` |
| **Dual Timer** | 5-second fixed interval + 2-7 second random interval. |
| **Failure Threshold** | 3 consecutive failures → EXE immediately kills the PS1 process. |
| **Timeout Protection** | Connect timeout 15 seconds, response timeout 3 seconds. |

**Attack Model Coverage:**

- Attacker comments out all PS1 verification code → EXE watchdog independently detects → Kill process
- Attacker replaces PS1 script → Self-hash mismatch → Challenge failure → Kill process
- Attacker injects hooks → Heartbeat lost → 3 failures → Kill process

---

### 2. Embedded C# Integrity Guard (AuroraGuard)

> **Overview:** Added a runtime-compiled C# IL code block `AuroraGuard` in LauncherGUI.ps1 that performs independent SHA256 integrity verification of 16 sub-module core files. Being compiled to native IL instructions, it is significantly harder to analyze and modify than pure PowerShell code. Hash values are securely injected by `build.ps1` at build time.

**Verification Coverage:**

| # | Protected File | Description |
|:--:|---|---|
| 1 | `Scripts\AURORA-SmartEngine.ps1` | Intelligent diagnostic engine |
| 2 | `Scripts\AURORA-CoreEngine.ps1` | Shared core engine |
| 3 | `Scripts\AURORA-AnalyzerCHSPRO.ps1` | Chinese PRO export |
| 4 | `Scripts\AURORA-ProgressManager.ps1` | Progress persistence management |
| 5 | `Scripts\AURORA-GUI-Functions.ps1` | GUI helper functions |
| 6 | `Scripts\AURORA-RepairTools.ps1` | Repair tools |
| 7 | `Scripts\AURORA-UndoManager.ps1` | Undo management |
| 8 | `Scripts\AURORA-RestoreManager.ps1` | System restore |
| 9 | `Scripts\AURORA-RepairLogger.ps1` | Repair log audit |
| 10 | `Scripts\AURORA-UndoViewer.ps1` | Repair history viewer |
| 11 | `Scripts\AURORA-AnalyzerPRO.ps1` | PRO mode entry |
| 12 | `Scripts\AURORA-ProgressManager-Integration.ps1` | Progress integration bridge |
| 13 | `Scripts\AURORA-ProgressManager-Integration-CHS.ps1` | Chinese progress integration |
| 14 | `Scripts\AURORA-ProgressManager-Integration-ENG.ps1` | English progress integration |
| 15 | `Scripts\Core\AURORA-AnimationCoreEngine.ps1` | Animation engine |
| 16 | `Data\AURORA-TechData.json` | Diagnostic knowledge base |

**Technical Characteristics:**
- `Add-Type` runtime compilation to IL, visible across Runspaces
- `VerifyOrDie()` method returns `bool`, can be actively called by sub-modules
- Hash values automatically injected at build time (build.ps1 `[2.5/6]` step)
- Graceful degradation on load failure (does not affect normal functionality)

---

## 🔧 Runtime Integrity Monitoring Enhancements

### 3. Elevation Security Token (AURORA-SEC-2026-001)

> **Overview:** P0-level security fix. When users perform operations requiring admin privileges (e.g., exporting security logs), the PowerShell process restarts with UAC elevation. The original RSA token file gets cleaned up by the old process, causing the elevated process to be unable to verify the EXE identity (trust chain break).

**Implementation:**

| Step | Description |
|---|---|
| **1. Token Generation** | Before launching, EXE generates a separate elevation token file with Nonce + Timestamp + AES-256-CBC encrypted hash list. |
| **2. Parameter Passing** | Token path is passed via `-ElevationTokenPath` command-line argument, bypassing UAC environment variable clearing. |
| **3. Independent Decryption** | The elevated PS1 process independently derives the AES key using the Nonce in the token to decrypt the hash list, without depending on the now-deleted RSA token. |
| **4. Time-Based Control** | 120-second independent expiration window (longer than the standard 60 seconds, compensating for elevation delay). |

**Security:**
- Token contains only encrypted hash list, no passwords or private keys
- Token file is immediately deleted after successful verification
- Decryption failure (key mismatch/expired) → falls back to password verification path

---

### 4. Anti-Spoofing Launch Parameter Protection

> **Overview:** Fixed a security vulnerability where an attacker could forge the `-LaunchedByExe` command-line parameter to bypass all RSA/AES security verification. Now, if this parameter is true but no valid token has passed validation, the system forces a security state reset.

```
Detection Logic:
  if (IsLaunchedByExe == true AND PassedHashListFromExe == null)
      → Reset IsLaunchedByExe = false
      → Clear all environment variable markers
      → Force password verification path
```

---

### 5. LastWriteTime Pre-Check Optimization

> **Overview:** P2-level performance optimization. In the integrity check loop, the file's `LastWriteTime` is checked first, and the full SHA256 hash calculation is only performed when the modification time has changed. Significantly reduces the repeated hashing overhead of 19 files every 3 seconds.

**Effect:**
- Files unchanged: Skip SHA256, compare timestamp only → ~0ms
- Files modified: Full SHA256 verification → 50-200ms/file
- Stable runtime (no file changes): CPU overhead drops to near zero

---

## 🎨 UI Enhancements

### 6. C# Embedded Countdown Alert Window

> **Overview:** Changed the integrity check alert window from PowerShell Timer implementation to the C# embedded class `AuroraExitCountdown`, avoiding PowerShell Timer scope issues and countdown instability.

**Features:**
- Dark-themed alert window (dark red background + white text)
- Final 5-second red countdown warning
- Bilingual support (Chinese and English)
- TopMost ensures user visibility
- `Show()` non-modal display + timer-driven

---

## 🔨 Build System Enhancements

### 7. AuroraGuard Hash Injection

> **Overview:** `build.ps1` adds a `[2.5/6]` step that automatically injects the current build's 16 sub-module SHA256 hashes into the `AuroraGuard` C# source code in LauncherGUI.ps1, replacing placeholder hash values.

### 8. Enhanced Intelligent Security Code Injection

> **Overview:** Enhanced the security code injection logic in build.ps1, which now automatically detects and updates hash values in AuroraGuard's `_expected` dictionary, and correctly replaces placeholder functions. Supports three modes: first-time injection, key update, and hash update.

---

## 🐛 Bug Fixes

| # | Issue | Resolution |
|---|-------|------------|
| 1 | **UAC Elevation Trust Chain Break** | Independent elevation security token with 120-second expiration window. |
| 2 | **Forged -LaunchedByExe Parameter** | Force reset security state when token validation fails. |
| 3 | **Duplicate Add-Type Loading** | Check if System.Windows.Forms and System.Drawing are already loaded before calling Add-Type. |
| 4 | **PowerShell Timer Countdown Instability** | Switched to C# embedded class `AuroraExitCountdown`. |
| 5 | **Integrity Check Sustained High CPU** | LastWriteTime pre-check skips SHA256 for unmodified files. |

---

## 📊 Change Statistics

| Metric | Value |
|--------|-------|
| **New Security Features** | 3 |
| **Security Fixes** | 3 |
| **Performance Optimizations** | 1 |
| **UI Enhancements** | 1 |
| **Build System Enhancements** | 2 |
| **Bug Fixes** | 5 |
| **Total Changes** | 15 |

---

## 🔐 Defense-in-Depth Upgrade Summary

V1.1.24.0's defense-in-depth model expands from four layers to **five layers**:

```
🛡️ Layer 1: Build-Time Security        — RSA keys + password obfuscation + SHA256 signing
🛡️ Layer 2: Launch-Time Security       — Anti-debug + AES decryption + RSA handshake
🛡️ Layer 3: Runtime Security           — Dual timers + FileSystemWatcher + integrity checks
🛡️ Layer 4: Multi-Module Detection     — GUI_Mode + syncHash + RSA Token
🛡️ Layer 5: Watchdog Guardian — 🆕    — Named Pipe HMAC challenge-response + independent process kill
```

**Characteristics of the New Fifth Defense Layer:**
- Completely independent of PS1 script layer, natively controlled by C# EXE
- Even if all PS1-layer verifications are bypassed, the watchdog still detects independently
- Challenge-response carries PS1 script self-hash, unforgeable
- Consecutive failure threshold + timeout mechanism, multi-layer fault tolerance

---

**Copyright:** &copy; 2026 AURORA VelociRaptor-GR Dev PRJ. All rights reserved.
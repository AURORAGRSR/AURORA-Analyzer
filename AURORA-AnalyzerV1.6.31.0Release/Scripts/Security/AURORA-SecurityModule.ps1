<#
.SYNOPSIS
    AURORA 系统安全模块
.DESCRIPTION
    提供系统安全相关的功能，如会话管理、加密操作等。
.NOTES
    版本：V1.6.31.0Release | 构建时间：2026.09.28
    作者：AURORA VelociRaptor-GR Dev PRJ.
    已独立至独立文件，避免与主脚本代码混合。
#>

# ==========================================
# 🌐 守卫日志双语化辅助（_GL = Guard Log localize）
# ==========================================
# SecurityModule.ps1 无 param 块，$Language 来自 dot-source 父作用域（PRO.ps1 / SmartEngine.ps1）。
# 若父作用域未定义 $Language（如直接运行），回退 "CHS"。
if (-not (Get-Variable -Name Language -ErrorAction SilentlyContinue)) {
    $Language = "CHS"
}
function _GL {
    # _GL <chsText> <engText> → 根据 $Language 返回对应字符串
    param([string]$Chs, [string]$Eng)
    if ($Language -eq "ENG") { return $Eng } else { return $Chs }
}

# ==========================================
# 🔐 RSA 公钥验证模块（构建时注入）
# ==========================================
$global:AURORA_PublicKeyXml = @'
<RSAKeyValue><Modulus>1HI00dpv2Cd/mEtQCkmY6Xk0LRMK0SYlw7j+DVPMfD5ooQ5q6ZCQ78lajMJtILlR7SwZSPSdkVxOpOEc/Pmy/MGFl14mihHc0zqpasHacrNPMgrl5spw7XASmQ7jkxz/6j6X9W0QityjBDqr0a9L52QzW2WG9OEBrPElhWBkKenoFxcpXWUM4iC/qWujy0jTfU+K07JfUGBtlsweYXvTGvf/y954039H/123wvfGJTyQzlcp4y3hXf8sL0G1vQ1DmIGuKIRQf1PfggUflf0ceIThHZ8BlRiarQTeBIYYiT2rDb7KNL44hwSqhoBpil3Yw/8VL3JSN3lRi4wT0g01iQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>
'@

$global:AURORA_SessionSalt = [Convert]::FromBase64String('vsx4QdCG6WZzi8KRXcYUwMOkOt8n4ucODyTmSpx9t20=')

$global:AURORA_AesSalt = [Convert]::FromBase64String('GFaOCdv9e8cGH9xXKv/530iFZWYC6KyXbdavNYnALnE=')
# 🔒 安全修复 H-8：AES salt 不再硬编码为固定字符串
# 改为构建时由 build.ps1 随机生成并注入（与 SessionSalt 相同机制）
# 上述 Base64 值为初始占位符，构建时会被替换为随机生成的 32 字节 salt

function Test-RSATokenSignature {
    param(
        [string]$Nonce,
        [long]$Timestamp,
        [string]$HashPayload,
        [string]$Signature
    )
    try {
        $rsa = New-Object System.Security.Cryptography.RSACryptoServiceProvider
        $rsa.FromXmlString($global:AURORA_PublicKeyXml)
        $signInput = "$($Nonce):$($Timestamp):$($HashPayload)"
        $signBytes = [System.Text.Encoding]::UTF8.GetBytes($signInput)
        $sigBytes = [Convert]::FromBase64String($Signature)
        $valid = $rsa.VerifyData($signBytes, $sigBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        $rsa.Dispose()
        return $valid
    } catch {
        # 🔒 M-3：不输出异常详情和堆栈跟踪到控制台，防止泄露内部实现
        Write-Warning "RSA token verification failed"
        return $false
    }
}

function Decrypt-HashListFromToken {
    param(
        [string]$Nonce,
        [string]$HashPayload
    )
    try {
        # 🔐 [SEC-FIX T1.5] 令牌 v2（Encrypt-then-MAC，与启动器模板/RsaTokenService 逐字节对齐）：
        #   hashPayload = "AV2:" + base64( "AV2" | IV 16B | cipher | HMAC-SHA256(macKey, magic+IV+cipher) 32B )
        #   PBKDF2 派生 64B（前 32B AES / 后 32B HMAC），先验 MAC 再解密。
        #   非 v2 前缀一律拒绝（同批构建自洽，硬切）。
        if (-not $HashPayload.StartsWith('AV2:', [System.StringComparison]::Ordinal)) {
            Write-Warning "Hash list decryption failed"
            return $null
        }
        $payloadBytes = [Convert]::FromBase64String($HashPayload.Substring(4))
        # 最小长度：3(magic) + 16(IV) + 16(最小完整 AES 块) + 32(MAC)
        if ($payloadBytes.Length -lt 67) { throw 'Invalid hash payload' }
        if ($payloadBytes[0] -ne 0x41 -or $payloadBytes[1] -ne 0x56 -or $payloadBytes[2] -ne 0x32) { throw 'Invalid hash payload' }

        $macOffset = $payloadBytes.Length - 32
        $sessionIv = $payloadBytes[3..18]
        $cipher = $payloadBytes[19..($macOffset - 1)]
        if ($cipher.Length -lt 16) { throw 'Invalid hash payload' }

        # PBKDF2 派生密钥材料（64B：AES key + MAC key）
        $keyMaterial = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
            $Nonce,
            $global:AURORA_AesSalt,
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )).GetBytes(64)
        $sessionKey = $keyMaterial[0..31]
        $macKey = $keyMaterial[32..63]

        # 先验 MAC（恒定时间循环——不提前 break，防时序侧信道）
        $hmac = New-Object System.Security.Cryptography.HMACSHA256 (,$macKey)
        $macCalc = $hmac.ComputeHash($payloadBytes, 0, $macOffset)
        $hmac.Dispose()
        $macOk = $true
        for ($mi = 0; $mi -lt 32; $mi++) {
            if ($macCalc[$mi] -ne $payloadBytes[$macOffset + $mi]) { $macOk = $false }
        }
        if (-not $macOk) { throw 'HMAC verification failed' }

        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $sessionKey
        $aes.IV = $sessionIv
        $aes.Mode = [System.Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7

        $plainBytes = $aes.CreateDecryptor().TransformFinalBlock($cipher, 0, $cipher.Length)
        return [System.Text.Encoding]::UTF8.GetString($plainBytes).TrimEnd("`r", "`n")
    } catch {
        # 🔒 M-3：不输出异常详情和堆栈跟踪到控制台
        Write-Warning "Hash list decryption failed"
        return $null
    }
}

# ==========================================
# 🔴 P0 修复：启动时强制清理残留看门狗资源 + 进程退出处理程序
# ==========================================
function Clear-AuroraWatchdogEnv {
    # 清理看门狗相关环境变量
    [Environment]::SetEnvironmentVariable("AURORA_WD_PIPE", $null)
    [Environment]::SetEnvironmentVariable("AURORA_WD_SESSION", $null)
    # 🔴 P1 修复：同时清理启动验证相关环境变量，防止重复启动时误判
    [Environment]::SetEnvironmentVariable("AURORA_LAUNCHED_BY_EXE", $null)
    [Environment]::SetEnvironmentVariable("AURORA_TOKEN_PATH", $null)
    [Environment]::SetEnvironmentVariable("AURORA_EXE_VERIFIED", $null)
    [Environment]::SetEnvironmentVariable("AURORA_HASH_PATH", $null)
}

function Register-AuroraExitHandler {
    if ($script:AuroraExitHandlerRegistered) { return }

    $cleanupAction = {
        Set-StrictMode -Off
        try {
            if ($AURORA_WD_PIPE -ne $null) {
                Invoke-SafeOperation -Operation {
                    if ($AURORA_WD_PIPE.IsConnected) { $AURORA_WD_PIPE.Close() }; $AURORA_WD_PIPE.Dispose()
                } -OperationName "看门狗管道清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($AURORA_WD_PS -ne $null) {
                Invoke-SafeOperation -Operation {
                    if (-not $AURORA_WD_PS.InvocationStateInfo.Completed) { $AURORA_WD_PS.Stop() }; $AURORA_WD_PS.Dispose()
                } -OperationName "看门狗 PS 清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($AURORA_WD_RUNSPACE -ne $null) {
                Invoke-SafeOperation -Operation {
                    if ($AURORA_WD_RUNSPACE.RunspaceStateInfo.State -eq 'Opened') { $AURORA_WD_RUNSPACE.Close() }; $AURORA_WD_RUNSPACE.Dispose()
                } -OperationName "看门狗 Runspace 清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($global:ActivePS -ne $null) {
                Invoke-SafeOperation -Operation {
                    if (-not $global:ActivePS.InvocationStateInfo.Completed) { $global:ActivePS.Stop() }; $global:ActivePS.Dispose()
                } -OperationName "ActivePS 清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($global:ActiveRunspace -ne $null) {
                Invoke-SafeOperation -Operation {
                    if ($global:ActiveRunspace.RunspaceStateInfo.State -eq 'Opened') { $global:ActiveRunspace.Close() }; $global:ActiveRunspace.Dispose()
                } -OperationName "ActiveRunspace 清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($script:debuggerTimer -ne $null) {
                Invoke-SafeOperation -Operation {
                    $script:debuggerTimer.Enabled = $false; $script:debuggerTimer.Stop(); $script:debuggerTimer.Dispose()
                } -OperationName "调试器定时器清理" -LogLevel "Warning" -ContinueOnError
            }
            if ($script:debuggerWmiWatcher -ne $null) {
                Invoke-SafeOperation -Operation {
                    Unregister-Event -SourceIdentifier $script:debuggerWmiWatcher.Name -ErrorAction SilentlyContinue
                } -OperationName "WMI 监听器清理" -LogLevel "Warning" -ContinueOnError
            }
            Clear-AuroraWatchdogEnv
            Write-Host (_GL "[退出处理] 资源已紧急清理" "[Exit Handler] Resources cleaned up") -ForegroundColor DarkGray
        } catch {
            Write-AuroraLog "退出处理程序异常: $($_.Exception.Message)" -Level "Error"
        }
    }

    try {
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -SupportEvent -Action $cleanupAction | Out-Null
    } catch {
        Write-AuroraLog "无法注册 PowerShell.Exiting 事件处理器: $($_.Exception.Message)" -Level "Warning"
    }

    try {
        $handler = [System.EventHandler]{ param($s, $e) & $cleanupAction }
        [AppDomain]::CurrentDomain.add_ProcessExit($handler)
    } catch {
        Write-Host (_GL "[退出处理] 无法注册 ProcessExit 事件" "[Exit Handler] Failed to register ProcessExit event") -ForegroundColor DarkGray
    }

    $script:AuroraExitHandlerRegistered = $true
    Write-Host (_GL "[退出处理] 已注册进程级退出清理程序" "[Exit Handler] Process-level exit cleanup registered") -ForegroundColor DarkGray
}

# 🔐 C# 嵌入式完整性守卫 (运行时编译验证)
# 此代码编译为本地IL，比PS1难分析和修改
# 哈希值由build.ps1在安全构建时注入
$AURORA_GUARD_INITIALIZED = $false
$AURORA_GUARD_SOURCE = @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Linq;

public class AuroraGuard
{
    private static readonly Dictionary<string, string> _expected = new Dictionary<string, string>
    {
        { "Scripts\\UI\\Controls\\AURORA-UIControls.ps1", "51091ece65525f1b3b45277dd52d119379116773e48fc674575c749b91030bba" },
        { "Scripts\\UI\\Controls\\AURORA-Animations.ps1", "553434cde61da690c18722ef358c7b7f03193f67404f6b19bb6ef9562e6659c4" },
        { "Scripts\\UI\\Views\\View-SplashScreen.ps1", "7b423ec593a50348dbb4f1fb23a113c8a36e98c396f35a1fe16f0d5c4383c7c1" },
        { "Scripts\\UI\\Views\\View-MainForm.ps1", "700f9f70df73a5b9dc4cb54e98e20ee4cc14fced66c04fcf8fc20716ebdf1e24" },
        { "Scripts\\UI\\Views\\View-ProMode.ps1", "f49ccae68dc5217c462cda774a8f5b78bd91589484726c952463435b95586a44" },
        { "Scripts\\UI\\Views\\Dialogs\\View-SessionRestoreDialog.ps1", "b2dac178d055c44a9b968a0f668435d4b043d40cefebb93d6ccd9f79712ee373" },
        { "Scripts\\UI\\Views\\Dialogs\\View-ElevationDialog.ps1", "a11f041afde6f8e9e29ee6a504e09a84d78833c5b8087b09098148a0e80a36e1" },
        { "Scripts\\UI\\Views\\Dialogs\\View-PermissionInfo.ps1", "cf86ff45d0c55d9bf557a06e1bc88f3f382d604815697fa2e1593d78ca2d1380" },
        { "Scripts\\UI\\Views\\Dialogs\\View-AdminElevation.ps1", "f6aa9c8a373f81ef909528b848b9defc5a9bc0815f15f2386f0b19658f3c80e1" },
        { "Scripts\\Engines\\AURORA-SmartEngine.ps1", "a2637b562f4241818d28b9129bfacde080ec984ac830d39aff2e949ec76721ca" },
        { "Scripts\\Core\\AURORA-CoreEngine.ps1", "c068fc02ae4839a84d04cfdb6281a08ff7bbc62f8fec50a2bfce06f9443077fe" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO-Engine.ps1", "559d1be8b46e2152a3c409de835e5ee2ce885bd7498a9e32a32a01bb98dc7922" },
        { "Scripts\\Session\\AURORA-ProgressManager.ps1", "80cac5d3ef49c5d60f58cc66a834c151edaf2cc40343cd10198115d75d16e27c" },
        { "Scripts\\GUI\\AURORA-GUI-Functions.ps1", "d9f179e72680dd77a8ee922c138c9b8559f0c2741cecf04a08bf3a6e5b43335b" },
        { "Scripts\\Repair\\AURORA-RepairTools.ps1", "5dc75c539154db238fc69f6ad5a47e11be9fccc765c8d85ec89b7df12d27a785" },
        { "Scripts\\Session\\AURORA-UndoManager.ps1", "c1c8ee5d7436010a67a7abbd4cf3e64f6509b1c17349a61e434424568ff6fb68" },
        { "Scripts\\Repair\\AURORA-RestoreManager.ps1", "dc3cb56002e93a10228e2d1e69631158f340cb9d2ce79d12e38261a6600398e5" },
        { "Scripts\\Repair\\AURORA-RepairLogger.ps1", "94eb3a8a32deccc853c457bba449c14f03005afcc60047dfe1db01099d9781bb" },
        { "Scripts\\Session\\AURORA-UndoViewer.ps1", "960ac1dff712602b8c4a80deb4fbff657ee11aece4c47cee199bdfef672a6143" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO.ps1", "1f11170269ead3aa3353d3a84de3467041a5b17736e70e1e041b9389bc174b66" },
        { "Scripts\\Session\\AURORA-ProgressManager-Integration.ps1", "2d484d52292a7a23665657c8a7ebe019d095536232f1048750fd9df72aa33e47" },
        { "Scripts\\Core\\AURORA-AnimationCoreEngine.ps1", "5c7fcd32385e33e3f7cce7f8bf57a7532d4d8d37127a7a4468b02fca7990d626" },
        { "Scripts\\Core\\AURORA-LaunchGuard.ps1", "bf43ca6d369aa3aa9f8b36a2672fe9610e39847a5a0f3a2c83c1891b62d00e5a" },
        { "Scripts\\AURORA-AnalyzerLauncherGUI.ps1", "931a35570a4afa76a6abb60c450c0f949361e225677351512647de292ec6e0ef" },
        { "Data\\AURORA-TechData.json", "9d7e80943b9074fbd04eeacd3633ca136611e00d0e5c58d26846e454f9d64b29" }
    };

    private static string _baseDir;
    private static DateTime _lastIntegrityCheck = DateTime.MinValue;
    private static bool _lastIntegrityResult = false;
    // 🔒 安全修复 M-8：消除完整性校验缓存 TOCTOU 窗口
    // 缓存设为 Zero，每次 CheckIntegrity 调用都重新计算哈希
    // 完整性校验是安全关键路径，不应为性能牺牲安全性
    private static readonly TimeSpan _integrityCacheDuration = TimeSpan.Zero;
    private static readonly object _integrityLock = new object();

    [DllImport("kernel32.dll")]
    private static extern bool IsDebuggerPresent();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CheckRemoteDebuggerPresent(IntPtr hProcess, ref bool isDebuggerPresent);

    [DllImport("ntdll.dll", SetLastError = true)]
    private static extern int NtQueryInformationProcess(
        IntPtr hProcess,
        int processInformationClass,
        IntPtr processInformation,
        int processInformationLength,
        ref int returnLength);

    [DllImport("ntdll.dll", SetLastError = true)]
    private static extern int NtSetInformationThread(
        IntPtr hThread,
        int threadInformationClass,
        IntPtr threadInformation,
        int threadInformationLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetCurrentThread();

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetThreadContext(IntPtr hThread, IntPtr lpContext);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int SuspendThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern int ResumeThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenThread(uint dwDesiredAccess, bool bInheritHandle, uint dwThreadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr hObject);

    private const int ProcessDebugPort = 7;
    private const int ProcessDebugFlags = 31;
    private const int ProcessHandleTracing = 34;
    private const int ProcessBasicInformation = 0;

    private const int THREAD_GET_CONTEXT = 0x0008;
    private const int THREAD_SUSPEND_RESUME = 0x0002;
    private const int THREAD_QUERY_INFORMATION = 0x0040;

    private const int ThreadHideFromDebugger = 0x11;

    private const uint CONTEXT_DEBUG_REGISTERS = 0x00000010;
    private const uint CONTEXT_FULL = 0x00010007;

    [StructLayout(LayoutKind.Sequential)]
    private struct CONTEXT_X86
    {
        public uint ContextFlags;
        public uint Dr0;
        public uint Dr1;
        public uint Dr2;
        public uint Dr3;
        public uint Dr6;
        public uint Dr7;
    }

    private static readonly string[] DEBUGGER_PROCESS_NAMES = new string[]
    {
        "windbg", "windbgx", "windbgpreview", "cdb", "ntsd", "x64dbg", "x32dbg",
        "dbgx", "dbgx.shell",
        "ida", "ida64", "idag", "idag64", "idaw", "idaw64",
        "ollydbg", "x64ollydbg", "immunitydebugger",
        "ghidra", "ghidrarun",
        "radare2", "r2", "rizin", "rz",
        "dbgshell", "mdb", "mdbx",
        "vsjitdebugger", "mdbg", "cordebug",
        "dnspy", "dnspy64",
        "scylla", "scyllahide", "titancall", "phant0m"
    };

    // 🔐 [T2.1] 清单验签公钥（由 Initialize 重载注入，来自 $global:AURORA_PublicKeyXml）
    private static string _manifestPublicKeyXml;

    public static void Initialize(string baseDir)
    {
        _baseDir = baseDir;
        // fail-closed：单参调用视为未提供清单公钥，必须清除残留（防跨初始化状态
        //   的旧密钥意外放行清单——功能测试 TEST F 抓获的静态字段状态残留缺陷）
        _manifestPublicKeyXml = null;
    }

    public static void Initialize(string baseDir, string manifestPublicKeyXml)
    {
        _baseDir = baseDir;
        _manifestPublicKeyXml = manifestPublicKeyXml;
    }

    // 🔐 [T2.1] 加载并验签构建机签名清单（aurora-manifest.sig）。
    //   格式与 build.ps1 [5.8/6] 生成端逐字节对齐：行1 头"AURORA-MANIFEST-V1"，
    //   行2+ "hash relpath"（单空格），末行 "SIG:base64"；签名数据 = 头行+条目行
    //   CRLF 连接（无尾随换行）。与 WPF IntegrityGuardService.TryLoadSignedManifest 逻辑对称。
    //   任何结构异常返回 false（fail-closed：发行版不应存在损坏清单）。
    private static bool TryLoadSignedManifest(string manifestPath, out System.Collections.Generic.List<string[]> entries, out string error)
    {
        entries = null;
        error = null;

        string content = System.IO.File.ReadAllText(manifestPath, System.Text.Encoding.UTF8);
        int sigIdx = content.LastIndexOf("\r\nSIG:", System.StringComparison.Ordinal);
        if (sigIdx < 0) { error = "SIG line missing"; return false; }
        string signedText = content.Substring(0, sigIdx);
        string sigB64 = content.Substring(sigIdx + 6);
        if (string.IsNullOrEmpty(sigB64)) { error = "signature empty"; return false; }
        if (string.IsNullOrEmpty(_manifestPublicKeyXml)) { error = "public key not initialized"; return false; }

        using (System.Security.Cryptography.RSACryptoServiceProvider rsa = new System.Security.Cryptography.RSACryptoServiceProvider())
        {
            rsa.FromXmlString(_manifestPublicKeyXml);
            byte[] sigBytes = System.Convert.FromBase64String(sigB64);
            if (!rsa.VerifyData(
                    System.Text.Encoding.UTF8.GetBytes(signedText),
                    sigBytes,
                    System.Security.Cryptography.HashAlgorithmName.SHA256,
                    System.Security.Cryptography.RSASignaturePadding.Pkcs1))
            {
                error = "signature invalid (not signed by this build's key)";
                return false;
            }
        }

        string[] lines = signedText.Split(new string[] { "\r\n" }, System.StringSplitOptions.None);
        if (lines.Length < 1 || lines[0] != "AURORA-MANIFEST-V1") { error = "bad header"; return false; }
        System.Collections.Generic.List<string[]> list = new System.Collections.Generic.List<string[]>();
        for (int i = 1; i < lines.Length; i++)
        {
            if (lines[i].Length == 0) continue;
            int sp = lines[i].IndexOf(' ');
            if (sp <= 0) { error = "bad entry at line " + (i + 1); return false; }
            list.Add(new string[] { lines[i].Substring(0, sp), lines[i].Substring(sp + 1) });
        }
        if (list.Count == 0) { error = "empty manifest"; return false; }
        entries = list;
        return true;
    }

    private static bool CheckDebuggerAPIs()
    {
        try
        {
            if (IsDebuggerPresent())
                return true;

            bool isRemoteDebugger = false;
            if (CheckRemoteDebuggerPresent(Process.GetCurrentProcess().Handle, ref isRemoteDebugger) && isRemoteDebugger)
                return true;

            IntPtr hProcess = Process.GetCurrentProcess().Handle;
            int returnLength = 0;
            IntPtr portInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)));
            
            try
            {
                int result = NtQueryInformationProcess(hProcess, ProcessDebugPort, portInfo, Marshal.SizeOf(typeof(IntPtr)), ref returnLength);
                if (result == 0 && Marshal.ReadIntPtr(portInfo) != IntPtr.Zero)
                    return true;
            }
            finally
            {
                Marshal.FreeHGlobal(portInfo);
            }

            returnLength = 0;
            IntPtr flagsInfo = Marshal.AllocHGlobal(sizeof(int));
            
            try
            {
                int result = NtQueryInformationProcess(hProcess, ProcessDebugFlags, flagsInfo, sizeof(int), ref returnLength);
                if (result == 0)
                {
                    int flags = Marshal.ReadInt32(flagsInfo);
                    if ((flags & 0x1) == 0)
                        return true;
                }
            }
            finally
            {
                Marshal.FreeHGlobal(flagsInfo);
            }

            returnLength = 0;
            IntPtr tracingInfo = Marshal.AllocHGlobal(Marshal.SizeOf(typeof(IntPtr)));
            
            try
            {
                int result = NtQueryInformationProcess(hProcess, ProcessHandleTracing, tracingInfo, Marshal.SizeOf(typeof(IntPtr)), ref returnLength);
                if (result == 0)
                {
                    long count = (long)Marshal.ReadIntPtr(tracingInfo);
                    if (count > 1000000)
                        return true;
                }
            }
            finally
            {
                Marshal.FreeHGlobal(tracingInfo);
            }

            if (CheckPEBNtGlobalFlag())
                return true;

            if (CheckHardwareBreakpoints())
                return true;
        }
        catch
        {
        }

        return false;
    }

    private static bool CheckPEBNtGlobalFlag()
    {
        try
        {
            IntPtr hProcess = Process.GetCurrentProcess().Handle;
            int returnLength = 0;
            int structSize = IntPtr.Size == 8 ? 48 : 28;
            IntPtr pbi = Marshal.AllocHGlobal(structSize);
            try
            {
                int result = NtQueryInformationProcess(hProcess, ProcessBasicInformation, pbi, structSize, ref returnLength);
                if (result == 0)
                {
                    IntPtr pebAddress = IntPtr.Size == 8 ? Marshal.ReadIntPtr(pbi, 8) : Marshal.ReadIntPtr(pbi, 4);
                    if (pebAddress != IntPtr.Zero)
                    {
                        int ntGlobalFlagOffset = IntPtr.Size == 8 ? 0xBC : 0x68;
                        int ntGlobalFlag = Marshal.ReadInt32(pebAddress, ntGlobalFlagOffset);
                        const int FLG_HEAP_ENABLE_TAIL_CHECK = 0x10;
                        const int FLG_HEAP_ENABLE_FREE_CHECK = 0x20;
                        const int FLG_HEAP_VALIDATE_PARAMETERS = 0x40;
                        int debugMask = FLG_HEAP_ENABLE_TAIL_CHECK | FLG_HEAP_ENABLE_FREE_CHECK | FLG_HEAP_VALIDATE_PARAMETERS;
                        if ((ntGlobalFlag & debugMask) == debugMask)
                            return true;
                    }
                }
            }
            finally
            {
                Marshal.FreeHGlobal(pbi);
            }
        }
        catch (Exception ex) {
            System.Diagnostics.Debug.WriteLine("CheckNtGlobalFlag probe failed: " + ex.Message);
        }
        return false;
    }

    private static bool CheckHardwareBreakpoints()
    {
        try
        {
            if (IntPtr.Size == 4)
            {
                int ctxSize = 716;
                IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);
                try
                {
                    Marshal.WriteInt32(ctxBuffer, 0, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
                    IntPtr hThread = GetCurrentThread();
                    if (GetThreadContext(hThread, ctxBuffer))
                    {
                        int drOffset = 4;
                        uint dr0 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset);
                        uint dr1 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset + 4);
                        uint dr2 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset + 8);
                        uint dr3 = (uint)Marshal.ReadInt32(ctxBuffer, drOffset + 12);
                        if (dr0 != 0 || dr1 != 0 || dr2 != 0 || dr3 != 0)
                            return true;
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(ctxBuffer);
                }
            }
            else
            {
                int ctxSize = 1232;
                IntPtr ctxBuffer = Marshal.AllocHGlobal(ctxSize);
                try
                {
                    Marshal.WriteInt32(ctxBuffer, 0x30, (int)(CONTEXT_DEBUG_REGISTERS | CONTEXT_FULL));
                    IntPtr hThread = GetCurrentThread();
                    if (GetThreadContext(hThread, ctxBuffer))
                    {
                        int drOffset = 0x48;
                        long dr0 = Marshal.ReadInt64(ctxBuffer, drOffset);
                        long dr1 = Marshal.ReadInt64(ctxBuffer, drOffset + 8);
                        long dr2 = Marshal.ReadInt64(ctxBuffer, drOffset + 16);
                        long dr3 = Marshal.ReadInt64(ctxBuffer, drOffset + 24);
                        if (dr0 != 0 || dr1 != 0 || dr2 != 0 || dr3 != 0)
                            return true;
                    }
                }
                finally
                {
                    Marshal.FreeHGlobal(ctxBuffer);
                }
            }
        }
        catch (Exception ex) {
            System.Diagnostics.Debug.WriteLine("CheckHardwareBreakpoints probe failed: " + ex.Message);
        }
        return false;
    }

    private static void HideThreadFromDebugger()
    {
        try
        {
            IntPtr hThread = GetCurrentThread();
            NtSetInformationThread(hThread, ThreadHideFromDebugger, IntPtr.Zero, 0);
        }
        catch (Exception ex) {
            System.Diagnostics.Debug.WriteLine("HideThreadFromDebugger failed: " + ex.Message);
        }
    }

    private static bool CheckDebuggerProcesses()
    {
        try
        {
            Process currentProcess = Process.GetCurrentProcess();
            int currentPid = currentProcess.Id;
            
            Process[] allProcesses = Process.GetProcesses();
            foreach (Process proc in allProcesses)
            {
                if (proc.Id == currentPid)
                    continue;
                    
                try
                {
                    string processName = proc.ProcessName.ToLowerInvariant();
                    foreach (string debuggerName in DEBUGGER_PROCESS_NAMES)
                    {
                        if (processName == debuggerName || processName == debuggerName + ".exe")
                            return true;
                    }
                }
                catch
                {
                }
                finally
                {
                    proc.Dispose();
                }
            }
        }
        catch
        {
        }
        
        return false;
    }

    private static bool CheckDLLInjection()
    {
        try
        {
            Process currentProcess = Process.GetCurrentProcess();
            string expectedDirectory = AppDomain.CurrentDomain.BaseDirectory;
            
            foreach (ProcessModule module in currentProcess.Modules)
            {
                try
                {
                    if (!string.IsNullOrEmpty(module.FileName))
                    {
                        string modulePath = module.FileName.ToLowerInvariant();
                        
                        // 排除系统 DLL 和 .NET Framework DLL
                        if (modulePath.Contains("\\windows\\") || 
                            modulePath.Contains("\\microsoft.net\\") ||
                            modulePath.Contains("\\assembly\\") ||
                            modulePath.Contains("system.") ||
                            modulePath.Contains("microsoft.") ||
                            modulePath.Contains("netstandard") ||
                            modulePath.Contains("mscorlib"))
                        {
                            continue;  // 跳过系统 DLL
                        }
                        
                        if (!modulePath.StartsWith(expectedDirectory.ToLowerInvariant()))
                        {
                            string moduleName = Path.GetFileNameWithoutExtension(modulePath).ToLowerInvariant();
                            
                            // 只检测明显的恶意关键词，排除常见误报
                            if (moduleName.Contains("inject") || 
                                moduleName.Contains("detour") ||
                                moduleName.Contains("spy"))
                            {
                                return true;
                            }
                        }
                    }
                }
                catch
                {
                }
            }
        }
        catch
        {
        }
        
        return false;
    }

    public static bool CheckIntegrity()
    {
        lock (_integrityLock)
        {
            if (DateTime.UtcNow - _lastIntegrityCheck < _integrityCacheDuration)
                return _lastIntegrityResult;
        }

        bool result = false;
        bool computedFresh = true;
        try
        {
            if (_baseDir == null)
            {
                // 🔒 SEC-FIX AUD-L4：不输出 _baseDir 值（含安装绝对路径），仅输出状态
                DiagLog("CheckIntegrity: _baseDir=NULL");
                result = false;
                return result;
            }

            // 🔐 [T2.1] 清单模式：清单存在即为权威（构建机私钥签名，不可重签）。
            //   验签失败/文件缺失/哈希不匹配 → fail-closed 返回 false；
            //   清单缺失 → 留痕后降级下方注入哈希表模式（开发树直启可用）。
            string manifestPath = System.IO.Path.Combine(_baseDir, "aurora-manifest.sig");
            if (File.Exists(manifestPath))
            {
                System.Collections.Generic.List<string[]> mEntries;
                string mError;
                if (!TryLoadSignedManifest(manifestPath, out mEntries, out mError))
                {
                    DiagLog("CheckIntegrity FAIL: manifest invalid - " + mError);
                    result = false;
                    return result;
                }
                foreach (string[] mEntry in mEntries)
                {
                    string mPath = System.IO.Path.Combine(_baseDir, mEntry[1]);
                    if (!File.Exists(mPath))
                    {
                        // 🔒 SEC-FIX AUD-L4：输出清单相对路径（逻辑名），不含安装绝对路径
                        DiagLog("CheckIntegrity FAIL: manifest file not found: " + mEntry[1]);
                        result = false;
                        return result;
                    }
                    string mActual = null;
                    bool mHashOk = false;
                    int mRetry = 0;
                    while (mRetry < 3)
                    {
                        try
                        {
                            using (var mSha = SHA256.Create())
                            {
                                byte[] mHash = mSha.ComputeHash(File.ReadAllBytes(mPath));
                                mActual = BitConverter.ToString(mHash).Replace("-", "").ToLowerInvariant();
                            }
                            mHashOk = true;
                            break;
                        }
                        catch (IOException)
                        {
                            // 对齐表模式的抗瞬态占用重试（防杀软扫描误报）
                            mRetry++;
                            if (mRetry >= 3) throw;
                            System.Threading.Thread.Sleep(100 * mRetry);
                        }
                    }
                    if (!mHashOk || !string.Equals(mActual, mEntry[0], StringComparison.OrdinalIgnoreCase))
                    {
                        // 🔒 SEC-FIX H-9：不输出哈希值，仅记录清单相对路径
                        DiagLog("CheckIntegrity FAIL: manifest hash mismatch: " + mEntry[1]);
                        result = false;
                        return result;
                    }
                }
                DiagLog("CheckIntegrity: manifest OK (" + mEntries.Count + " sealed entries)");
                result = true;
                return result;
            }
            DiagLog("MANIFEST_MISSING - falling back to embedded hash table");

            if (_expected.Count == 0)
            {
                DiagLog("CheckIntegrity: _expected.Count=0");
                result = false;
                return result;
            }
            // 🔒 SEC-FIX AUD-L4：同上，仅输出条目计数
            DiagLog("CheckIntegrity: checking " + _expected.Count + " files");
            foreach (var kv in _expected)
            {
                string path = System.IO.Path.Combine(_baseDir, kv.Key);
                if (!File.Exists(path))
                {
                    // 🔒 SEC-FIX AUD-L4：输出 kv.Key 逻辑名而非 path 完整路径（path 含安装绝对路径，
                    //   H-9 修掉了临时文件写入但 stderr 仍泄露受保护文件位置），可运维性不损失
                    DiagLog("CheckIntegrity FAIL: File not found: " + kv.Key);
                    result = false;
                    return result;
                }
                string actual = null;
                bool hashOk = false;
                int retryCount = 0;
                int maxRetry = 3;

                while (retryCount < maxRetry)
                {
                    try
                    {
                        using (var sha = SHA256.Create())
                        {
                            byte[] hash = sha.ComputeHash(File.ReadAllBytes(path));
                            actual = BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
                        }
                        hashOk = true;
                        break;
                    }
                    catch (IOException)
                    {
                        retryCount++;
                        if (retryCount >= maxRetry) throw;
                        System.Threading.Thread.Sleep(100 * retryCount);
                    }
                }

                if (!hashOk || !string.Equals(actual, kv.Value, StringComparison.OrdinalIgnoreCase))
                {
                    // 🔒 安全修复 H-9：不输出哈希值到日志，仅记录文件名和匹配结果
                    DiagLog("CheckIntegrity FAIL: Hash mismatch for " + kv.Key);
                    result = false;
                    return result;
                }
            }
            result = true;
            DiagLog("CheckIntegrity: All " + _expected.Count + " files OK");
            return result;
        }
        catch (IOException ex)
        {
            DiagLog("CheckIntegrity IOException - triggering security alert: " + ex.Message);
            result = false;
            return result;
        }
        catch (Exception ex)
        {
            DiagLog("CheckIntegrity Exception: " + ex.GetType().Name + " - " + ex.Message);
            result = false;
            return result;
        }
        finally
        {
            if (computedFresh)
            {
                lock (_integrityLock)
                {
                    _lastIntegrityCheck = DateTime.UtcNow;
                    _lastIntegrityResult = result;
                }
            }
        }
    }

    public static bool VerifyOrDie()
    {
        HideThreadFromDebugger();

        if (CheckDebuggerAPIs())
            return false;
            
        if (CheckDebuggerProcesses())
            return false;
            
        if (CheckDLLInjection())
            return false;
            
        if (!CheckIntegrity())
            return false;
            
        return true;
    }

    private static void DiagLog(string msg)
    {
        // 🔒 安全修复 H-9：仅输出到 stderr，不写入临时文件（防止泄露受保护文件路径和检测逻辑）
        try
        {
            Console.Error.WriteLine(msg);
            Console.Error.Flush();
        }
        catch (Exception ex) {
            System.Diagnostics.Debug.WriteLine("DiagLog failed: " + ex.Message);
        }
    }

    public static string GetDetectionReason()
    {
        DiagLog("GetDetectionReason START");

        try
        {
            DiagLog("CheckDebuggerAPIs...");
            if (CheckDebuggerAPIs())
            {
                DiagLog("CheckDebuggerAPIs -> DEBUGGER_API");
                return "DEBUGGER_API";
            }
            DiagLog("CheckDebuggerAPIs OK");
        }
        catch (Exception ex)
        {
            DiagLog("CheckDebuggerAPIs EXCEPTION: " + ex.GetType().Name + " - " + ex.Message);
        }

        try
        {
            DiagLog("CheckDebuggerProcesses...");
            if (CheckDebuggerProcesses())
            {
                DiagLog("CheckDebuggerProcesses -> DEBUGGER_PROCESS");
                return "DEBUGGER_PROCESS";
            }
            DiagLog("CheckDebuggerProcesses OK");
        }
        catch (Exception ex)
        {
            DiagLog("CheckDebuggerProcesses EXCEPTION: " + ex.GetType().Name + " - " + ex.Message);
        }

        try
        {
            DiagLog("CheckDLLInjection...");
            if (CheckDLLInjection())
            {
                DiagLog("CheckDLLInjection -> DLL_INJECTION");
                return "DLL_INJECTION";
            }
            DiagLog("CheckDLLInjection OK");
        }
        catch (Exception ex)
        {
            DiagLog("CheckDLLInjection EXCEPTION: " + ex.GetType().Name + " - " + ex.Message);
        }

        try
        {
            DiagLog("CheckIntegrity...");
            if (!CheckIntegrity())
            {
                DiagLog("CheckIntegrity -> INTEGRITY_FAILURE");
                return "INTEGRITY_FAILURE";
            }
            DiagLog("CheckIntegrity OK");
        }
        catch (Exception ex)
        {
            DiagLog("CheckIntegrity EXCEPTION: " + ex.GetType().Name + " - " + ex.Message);
        }

        DiagLog("GetDetectionReason -> NONE");
        return "NONE";
    }
}
"@

# 检测系统语言（需在 AuroraExitCountdown 编译前设置）
$UseChinese = $false
try {
    $uiCulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture.Name
    if ($uiCulture -like "zh*") {
        $UseChinese = $true
    }
} catch { Write-AuroraLog "语言检测失败，默认使用中文: $($_.Exception.Message)" -Level "Warning" }

#  提前编译倒计时窗口类（在 AuroraGuard 之前，以便检测时可用）
# 🔴 关键修复：显式引用 System.Drawing 和 System.Windows.Forms，
# 否则在某些 PowerShell 运行时下 Add-Type 会因缺少程序集引用而失败，
# 导致安全倒计时窗口无法创建，程序直接闪退。
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Windows.Forms;
using System.Threading;

public class AuroraExitCountdown {
    public static void Show(string titleCN, string titleEN, string messageCN, string messageEN, int seconds, bool forceExit, bool useChinese) {
        var form = new Form();
        form.Text = useChinese ? "AURORA 安全警报" : "AURORA Security Alert";
        form.Size = new Size(550, 350);
        form.FormBorderStyle = FormBorderStyle.FixedDialog;
        form.StartPosition = FormStartPosition.CenterScreen;
        form.MaximizeBox = false;
        form.MinimizeBox = false;
        form.TopMost = true;
        form.BackColor = Color.FromArgb(30, 20, 20);

        var titleLabel = new Label();
        titleLabel.Text = useChinese ? titleCN : titleEN;
        titleLabel.Location = new Point(25, 20);
        titleLabel.Size = new Size(480, 50);
        titleLabel.Font = new Font("Microsoft YaHei UI", 12, FontStyle.Bold);
        titleLabel.ForeColor = Color.FromArgb(255, 100, 100);
        titleLabel.AutoSize = false;

        var messageLabel = new Label();
        messageLabel.Text = useChinese ? messageCN : messageEN;
        messageLabel.Location = new Point(25, 80);
        messageLabel.Size = new Size(480, 150);
        messageLabel.Font = new Font("Microsoft YaHei UI", 9);
        messageLabel.ForeColor = Color.White;
        messageLabel.AutoSize = false;

        var countdownLabel = new Label();
        countdownLabel.Text = (useChinese ? "倒计时：" : "Countdown: ") + seconds + " " + (useChinese ? "秒" : "s");
        countdownLabel.Location = new Point(25, 240);
        countdownLabel.Size = new Size(480, 30);
        countdownLabel.Font = new Font("Microsoft YaHei UI", 10, FontStyle.Bold);
        countdownLabel.ForeColor = Color.FromArgb(255, 150, 100);

        var warningIcon = new Label();
        warningIcon.Text = "⚠";
        warningIcon.Location = new Point(25, 200);
        warningIcon.Size = new Size(480, 30);
        warningIcon.Font = new Font("Segoe UI Symbol", 14, FontStyle.Bold);
        warningIcon.ForeColor = Color.FromArgb(255, 100, 100);
        warningIcon.TextAlign = ContentAlignment.MiddleCenter;

        form.Controls.Add(titleLabel);
        form.Controls.Add(messageLabel);
        form.Controls.Add(countdownLabel);
        form.Controls.Add(warningIcon);

        var timer = new System.Windows.Forms.Timer();
        timer.Interval = 1000;
        int remaining = seconds;

        timer.Tick += (sender, e) => {
            if (remaining > 0) {
                remaining--;
                string countdownText = useChinese ? "[倒计时] 剩余时间：" : "[Countdown] Remaining: ";
                string secondsText = useChinese ? "秒" : "s";
                Console.WriteLine(countdownText + remaining + " " + secondsText);
                if (!form.IsDisposed) {
                    countdownLabel.Text = (useChinese ? "倒计时：" : "Countdown: ") + remaining + " " + (useChinese ? "秒" : "s");
                    if (remaining <= 5) {
                        countdownLabel.ForeColor = Color.FromArgb(255, 50, 50);
                    }
                }
            }
            if (remaining <= 0) {
                timer.Stop();
                timer.Dispose();
                if (!form.IsDisposed) { form.Close(); }
                if (forceExit) {
                    Environment.Exit(1);
                }
            }
        };

        form.Show();
        timer.Start();
        
        // 处理消息循环，让 Timer 能正常工作
        DateTime endTime = DateTime.Now.AddSeconds(seconds + 1);
        while (DateTime.Now < endTime) {
            Application.DoEvents();
            Thread.Sleep(100);
        }
    }
}
"@ -ReferencedAssemblies "System.Windows.Forms", "System.Drawing"

try {
    # [P1 修复：重复初始化] 进程级去重：本模块被 PRO 主脚本 / PRO-Engine / LauncherGUI 等
    # 各自无条件 dot-source，原初始化序列每次都把 $AURORA_GUARD_INITIALIZED 重置为 $false
    # 再完整重跑——同进程启动两份持续性检测（每 1s）与两份 WMI 实时监控（实测 2026-09-04
    # promode_console.log：PRO 与 PRO-Engine 各初始化一遍）。进程级环境变量跨 Runspace/
    # 脚本作用域可见：已初始化则跳过初始化与监控启动（本行之前的函数定义照常重执行，
    # dot-source 语义不变；初始化失败不设标记，后续 dot-source 仍可重试）。
    if ([Environment]::GetEnvironmentVariable('AURORA_GUARD_PROCESS_INITIALIZED', 'Process') -eq '1') {
        Write-Host (_GL "[安全守卫] 已完成进程级初始化，跳过重复初始化" "[Guard] Process-level init already done, skipping re-initialization") -ForegroundColor DarkGray
        return
    }
    $AURORA_GUARD_INITIALIZED = $false
    $guardInitRetryCount = 0
    $guardInitMaxRetry = 3
    $guardInitRetryDelayMs = 500

    while ($guardInitRetryCount -lt $guardInitMaxRetry -and -not $AURORA_GUARD_INITIALIZED) {
        try {
            if ($guardInitRetryCount -gt 0) {
                Write-Host (_GL "[安全守卫] 等待 $($guardInitRetryDelayMs * $guardInitRetryCount)ms 后重试..." "[Guard] Waiting $($guardInitRetryDelayMs * $guardInitRetryCount)ms before retry...") -ForegroundColor DarkGray
                Start-Sleep -Milliseconds ($guardInitRetryDelayMs * $guardInitRetryCount)
            }
            Write-Host (_GL "[安全守卫] 正在初始化 (第 $($guardInitRetryCount + 1) 次)..." "[Guard] Initializing (attempt $($guardInitRetryCount + 1))...") -ForegroundColor Cyan

            # 🔴 P1 修复：使用 try-catch 处理类型已存在的情况
            try {
                Add-Type -TypeDefinition $AURORA_GUARD_SOURCE -ReferencedAssemblies "System.Core" -ErrorAction Stop

                # 🔴 关键修复：正确计算项目根目录（通用逻辑，兼容任意子目录）
                # 调用方可能位于 Scripts\、Scripts\Security\、Scripts\Engines\、Scripts\PRO\ 等任意位置
                # 策略：从 $baseForGuard 开始向上查找包含 "Security" 子目录的目录作为 Scripts 目录
                $baseForGuard = if ($scriptDir) {
                    $scriptDir
                } elseif ($PSScriptRoot) {
                    $PSScriptRoot
                } else {
                    Split-Path -Parent $MyInvocation.MyCommand.Definition
                }

                # 向上查找 Scripts 目录（特征：包含 Security 子目录）
                # 注意：使用 $guardSearchDir / $guardScriptsDir 避免覆盖调用方的 $scriptsDir 变量
                $guardSearchDir = $baseForGuard
                $guardScriptsDir = $null
                for ($i = 0; $i -lt 5; $i++) {
                    if (Test-Path (Join-Path $guardSearchDir "Security")) {
                        $guardScriptsDir = $guardSearchDir
                        break
                    }
                    $parent = Split-Path -Parent $guardSearchDir
                    if (-not $parent -or $parent -eq $guardSearchDir) { break }
                    $guardSearchDir = $parent
                }

                if ($guardScriptsDir) {
                    $rootDir = Split-Path -Parent $guardScriptsDir
                } else {
                    # 兜底：直接上两级（适用于 Scripts\Security 场景）
                    $rootDir = Split-Path -Parent (Split-Path -Parent $baseForGuard)
                }

                # 诊断：输出路径信息
                Write-Host (_GL "[安全守卫] baseForGuard: $baseForGuard" "[Guard] baseForGuard: $baseForGuard") -ForegroundColor DarkGray
                Write-Host (_GL "[安全守卫] rootDir: $rootDir" "[Guard] rootDir: $rootDir") -ForegroundColor DarkGray

                # 🔐 [T2.1] 双参重载：同时注入清单验签公钥（与令牌验签同一密钥对）
                [AuroraGuard]::Initialize($rootDir, $global:AURORA_PublicKeyXml)
                $AURORA_GUARD_INITIALIZED = $true
                Write-Host (_GL "[安全守卫] 初始化成功" "[Guard] Initialized successfully") -ForegroundColor Green
            } catch [System.Management.Automation.MethodInvocationException] {
                # 🔒 安全修复 C-6：类型替换攻击防护
                # "already exists" 不等于安全——攻击者可能预加载同名伪类绕过检测
                # 必须验证已存在类型的来源程序集是否可信
                if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -like "*already exists*") {
                    Write-Host (_GL "[安全守卫] AuroraGuard 类型已存在，验证来源..." "[Guard] AuroraGuard type already exists, verifying source...") -ForegroundColor DarkGray

                    # 验证已存在的 AuroraGuard 类型是否来自可信源
                    $existingType = [System.Type]::GetType('AuroraGuard')
                    if ($null -ne $existingType) {
                        $assemblyLoc = $existingType.Assembly.Location
                        # 可信来源：动态程序集（Add-Type 编译的，Location 为空或临时路径）
                        # 不可信来源：外部加载的 DLL（Location 指向可疑路径）
                        if ([string]::IsNullOrEmpty($assemblyLoc) -or $assemblyLoc -match 'Anonymously\s+Hosted') {
                            Write-Host (_GL "[安全守卫] AuroraGuard 来源验证通过（动态程序集）" "[Guard] AuroraGuard source verified (dynamic assembly)") -ForegroundColor DarkGray

                            # 🔴 关键修复：正确计算项目根目录（与上面一致，通用逻辑）
                            $baseForGuard2 = if ($scriptDir) {
                                $scriptDir
                            } elseif ($PSScriptRoot) {
                                $PSScriptRoot
                            } else {
                                Split-Path -Parent $MyInvocation.MyCommand.Definition
                            }

                            $guardSearchDir2 = $baseForGuard2
                            $guardScriptsDir2 = $null
                            for ($j = 0; $j -lt 5; $j++) {
                                if (Test-Path (Join-Path $guardSearchDir2 "Security")) {
                                    $guardScriptsDir2 = $guardSearchDir2
                                    break
                                }
                                $parent2 = Split-Path -Parent $guardSearchDir2
                                if (-not $parent2 -or $parent2 -eq $guardSearchDir2) { break }
                                $guardSearchDir2 = $parent2
                            }

                            if ($guardScriptsDir2) {
                                $rootDir2 = Split-Path -Parent $guardScriptsDir2
                            } else {
                                $rootDir2 = Split-Path -Parent (Split-Path -Parent $baseForGuard2)
                            }

                            # 🔐 [T2.1] 双参重载：同时注入清单验签公钥（与令牌验签同一密钥对）
                            [AuroraGuard]::Initialize($rootDir2, $global:AURORA_PublicKeyXml)
                            $AURORA_GUARD_INITIALIZED = $true
                            Write-Host (_GL "[安全守卫] 初始化成功" "[Guard] Initialized successfully") -ForegroundColor Green
                        } else {
                            # 类型来自外部 DLL，可能是类型替换攻击
                            Write-Host (_GL "[安全守卫] 警告：AuroraGuard 来自不可信程序集: $assemblyLoc" "[Guard] Warning: AuroraGuard from untrusted assembly: $assemblyLoc") -ForegroundColor Red
                            Write-Host (_GL "[安全守卫] 可能存在类型替换攻击，拒绝使用该类型" "[Guard] Possible type substitution attack detected, rejecting this type") -ForegroundColor Red
                            # 不初始化，降级模式会触发强制退出（C-7 修复）
                        }
                    }
                } else {
                    # 其他异常，重新抛出
                    Write-Host (_GL "[安全守卫] 初始化异常：$($_.Exception.Message)" "[Guard] Init exception: $($_.Exception.Message)") -ForegroundColor Red
                    throw
                }
            } catch {
                Write-Host (_GL "[安全守卫] 初始化异常：$($_.Exception.Message)" "[Guard] Init exception: $($_.Exception.Message)") -ForegroundColor Red
                throw
            }

            # 🔐 启动时立即执行环境安全扫描（类似完整性检测）
            Write-Host (_GL "[诊断] 正在执行环境安全扫描..." "[Diag] Running environment security scan...") -ForegroundColor DarkGray
            $envDetectionReason = [AuroraGuard]::GetDetectionReason()
            Write-Host (_GL "[诊断] 扫描结果: $envDetectionReason" "[Diag] Scan result: $envDetectionReason") -ForegroundColor DarkGray
            if ($envDetectionReason -ne "NONE") {
                Write-Host (_GL "[安全守卫] 启动时检测到威胁：$envDetectionReason" "[Guard] Threat detected at startup: $envDetectionReason") -ForegroundColor Red

                $reasonText = switch ($envDetectionReason) {
                    "DEBUGGER_API" { (_GL "调试器 API 检测" "Debugger API detection") }
                    "DEBUGGER_PROCESS" { (_GL "调试工具进程检测" "Debugger process detection") }
                    "DLL_INJECTION" { (_GL "DLL 注入检测" "DLL injection detection") }
                    "INTEGRITY_FAILURE" { (_GL "文件完整性验证失败" "File integrity verification failed") }
                    default { (_GL "未知威胁" "Unknown threat") }
                }

                Write-Host (_GL "[Security Alert] 启动时检测到调试或注入，程序将在 15 秒后退出..." "[Security Alert] Debugging or injection detected at startup, program will exit in 15 seconds...") -ForegroundColor Red

                # 🔴 关键修复：使用模态窗口阻塞，等待用户确认或倒计时结束
                $script:ExitCountdownStarted = $true
                [AuroraExitCountdown]::Show(
                    " 安全警报：$reasonText！",
                    " Security Alert: $envDetectionReason!",
                    "启动时检测到程序正在被调试或注入：$reasonText`n`n程序将在 15 秒后自动退出。",
                    "Debugging or injection detected at startup: $reasonText`n`nProgram will exit in 15 seconds.",
                    15,
                    $true,
                    $UseChinese
                )

                # 等待倒计时结束（Environment.Exit 会在 C# 端执行）
                while ($true) {
                    Start-Sleep -Milliseconds 500
                }
            } else {
                Write-Host (_GL "[安全守卫] 启动环境扫描完成 - 安全" "[Guard] Startup environment scan complete - Safe") -ForegroundColor DarkGray
            }

            # 🔐 添加持续性调试器检测定时器（类似完整性检测）
            # 🔒 安全修复 H-11：检测间隔从 3 秒降到 1 秒，缩小攻击窗口
            $script:DebuggerCheckInterval = 1  # 每 1 秒检测一次（原 3 秒窗口过大）
            $script:DebuggerCheckCount = 0
    
    $script:checkDebugger = {
        # 🔒 安全修复 H-4：移除 ExitCountdownStarted 提前返回，防止攻击者预设该标志禁用所有检测
        # 即使倒计时已启动，也继续检测（倒计时期间仍可发现新威胁并记录日志）
        
        $script:DebuggerCheckCount++
        $detectionReason = [AuroraGuard]::GetDetectionReason()
        
        if ($detectionReason -ne "NONE") {
            # 🔒 安全修复 H-11：首次检测即触发警报，消除原 6 秒攻击窗口
            # 原方案要求连续 2 次检测（3秒×2=6秒窗口），攻击者可在窗口内提取内存/密钥
            # 现改为首次检测立即触发，配合 1 秒检测间隔，窗口缩至 1 秒以内
            if (-not $script:LastDetectionReason) {
                # 首次检测到威胁
                $script:LastDetectionReason = $detectionReason
                $script:LastDetectionTime = Get-Date
                $script:ConsecutiveDetectionCount = 1
            } elseif ($script:LastDetectionReason -eq $detectionReason) {
                # 同一威胁持续存在
                $script:ConsecutiveDetectionCount++
            } else {
                # 不同的威胁，更新记录
                $script:LastDetectionReason = $detectionReason
                $script:ConsecutiveDetectionCount = 1
            }

            # 🔒 H-11：首次检测即触发警报（ConsecutiveDetectionCount >= 1）
            if ($script:ConsecutiveDetectionCount -ge 1) {
                $reasonText = switch ($detectionReason) {
                    "DEBUGGER_API" { "调试器 API 检测" }
                    "DEBUGGER_PROCESS" { "调试工具进程检测" }
                    "DLL_INJECTION" { "DLL 注入检测" }
                    "INTEGRITY_FAILURE" { "文件完整性验证失败" }
                    default { "未知威胁" }
                }

                if (-not $script:ExitCountdownStarted) {
                    $script:ExitCountdownStarted = $true

                    Write-Host (_GL "[Security Alert] 检测到调试或注入：$reasonText，程序将在 15 秒后退出..." "[Security Alert] Debug/injection detected: $reasonText, program will exit in 15 seconds...") -ForegroundColor Red
                    [AuroraExitCountdown]::Show(
                        " 安全警报：$reasonText！",
                        " Security Alert: $detectionReason!",
                        "持续性检测发现程序正在被调试或注入：$reasonText`n`n程序将在 15 秒后自动退出。",
                        "Continuous monitoring detected debugging/injection: $reasonText`n`nProgram will exit in 15 seconds.",
                        15,
                        $true,
                        $UseChinese
                    )
                }
            }
        } else {
            # 正常检查，重置可疑记录
            if ($script:LastDetectionReason) {
                Write-Host (_GL "[安全守卫] 可疑活动消失，判定为误报" "[Guard] Suspicious activity cleared, judged as false positive") -ForegroundColor DarkGray
                $script:LastDetectionReason = $null
                $script:ConsecutiveDetectionCount = 0
            }
            
            # 原地刷新正常日志
            $timestamp = Get-Date -Format "HH:mm:ss"
            $logLine = _GL "[安全守卫] 环境安全检查通过 - 第 $($script:DebuggerCheckCount) 次 - $timestamp" "[Guard] Environment security check passed - #$($script:DebuggerCheckCount) - $timestamp"
            $clearLine = New-Object String(' ', $Host.UI.RawUI.WindowSize.BufferWidth)
            Write-Host "`r$clearLine" -NoNewline
            Write-Host "`r$logLine" -ForegroundColor DarkGray -NoNewline
        }
    }
    
    # 启动持续性检测定时器
    # [P0-修复] 支持 $AuroraGuardSkipMonitoring 开关：当调用方（如 SmartEngine）设置为 $true 时，
    #   跳过定时器和 WMI 监控的启动，只保留 AuroraGuard 类的静态验证（VerifyOrDie）。
    #   原因：SmartEngine 是"短跑型"脚本，dot-source 后立即独占 Runspace 执行分析，
    #   不会像 PRO Engine 那样进入交互循环让出 Runspace。定时器事件回调需要借用 Runspace
    #   执行 $script:checkDebugger 脚本块，与 SmartEngine 主流程抢占 RunspacePool，导致
    #   ProModeViewModel.IsAlive(2000) 超时失败，触发"主动健康检查失败"误报循环。
    if ($AuroraGuardSkipMonitoring) {
        Write-Host (_GL "[安全守卫] 持续性检测已跳过（AuroraGuardSkipMonitoring=true）" "[Guard] Continuous detection skipped (AuroraGuardSkipMonitoring=true)") -ForegroundColor DarkGray
    } else {
        $script:debuggerTimer = New-Object System.Timers.Timer
        $script:debuggerTimer.Interval = $script:DebuggerCheckInterval * 1000
        $script:debuggerTimer.AutoReset = $true
        $script:debuggerTimer.Enabled = $true

        $action = [System.Timers.ElapsedEventHandler]$script:checkDebugger
        $script:debuggerTimer.add_Elapsed($action)

        Write-Host (_GL "[安全守卫] 已启动持续性检测（每 $($script:DebuggerCheckInterval) 秒）" "[Guard] Continuous detection started (every $($script:DebuggerCheckInterval)s)") -ForegroundColor DarkGray
    }
    
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  WMI 实时进程创建监控（零延迟）
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    $script:debuggerWmiWatcher = $null
    # [P0-修复] 同上 $AuroraGuardSkipMonitoring 开关：跳过 WMI 监控启动，
    #   避免 Register-ObjectEvent 在 RunspacePool 模式下与 SmartEngine 主流程冲突。
    if ($AuroraGuardSkipMonitoring) {
        Write-Host (_GL "[安全守卫] WMI 实时监控已跳过（AuroraGuardSkipMonitoring=true）" "[Guard] WMI real-time monitoring skipped (AuroraGuardSkipMonitoring=true)") -ForegroundColor DarkGray
    } else {
    try {
        $wmiQuery = "SELECT * FROM Win32_ProcessStartTrace"
        $wmiWatcher = New-Object System.Management.ManagementEventWatcher
        $wmiWatcher.Query = $wmiQuery
        $wmiWatcher.Options.Timeout = [System.TimeSpan]::MaxValue

        $wmiProcessNames = @(
            "windbg", "windbgx", "windbgpreview", "cdb", "ntsd", "x64dbg", "x32dbg",
            "dbgx", "dbgx.shell",
            "ida", "ida64", "idag", "idag64", "idaw", "idaw64",
            "ollydbg", "x64ollydbg", "immunitydebugger",
            "ghidra", "ghidrarun",
            "radare2", "r2", "rizin", "rz",
            "dbgshell", "mdb", "mdbx",
            "vsjitdebugger", "mdbg", "cordebug",
            "dnspy", "dnspy64",
            "scylla", "scyllahide", "titancall", "phant0m"
        )

        $wmiEventAction = {
            $procName = $EventArgs.NewEvent.Properties["ProcessName"].Value
            if ($procName) {
                $lowerName = $procName.ToLowerInvariant().Replace(" ", "").Replace(".exe", "")
                foreach ($wmiName in $Event.MessageData) {
                    if ($lowerName -eq $wmiName) {
                        Write-Host ""
                        Write-Host (_GL "[安全守卫-WMI] 实时检测到调试器进程启动: $procName" "[Guard-WMI] Real-time debugger process launch detected: $procName") -ForegroundColor Red
                        if (-not $script:ExitCountdownStarted) {
                            $script:ExitCountdownStarted = $true
                            Write-Host (_GL "[Security Alert] WMI实时检测到调试器进程，程序将在 15 秒后退出..." "[Security Alert] WMI detected debugger process, program will exit in 15 seconds...") -ForegroundColor Red
                            [AuroraExitCountdown]::Show(
                                " 安全警报：调试工具进程启动检测！",
                                " Security Alert: Debugger Process Detected!",
                                "WMI 实时监控检测到调试器进程已被启动：$procName`n`n程序将在 15 秒后自动退出。",
                                "WMI real-time monitoring detected debugger process launched: $procName`n`nProgram will exit in 15 seconds.",
                                15,
                                $true,
                                $UseChinese
                            )
                        }
                        break
                    }
                }
            }
        }

        $script:debuggerWmiWatcher = Register-ObjectEvent -InputObject $wmiWatcher -EventName "EventArrived" `
            -Action $wmiEventAction -MessageData $wmiProcessNames -SupportEvent
        $wmiWatcher.Start()
        Write-Host (_GL "[安全守卫] 已启动 WMI 实时进程监控（零延迟）" "[Guard] WMI real-time process monitoring started (zero latency)") -ForegroundColor DarkGray
    } catch {
        Write-Host (_GL "[安全守卫] WMI 实时监控启动失败，将仅使用轮询模式" "[Guard] WMI real-time monitoring failed, falling back to polling mode") -ForegroundColor Yellow
    }
    }  # end if ($AuroraGuardSkipMonitoring) else

    # [P1 修复：重复初始化] 初始化+监控启动成功 → 设置进程级标记（跨 Runspace/脚本作用域
    # 可见），后续任何 dot-source 不再重复初始化/启动监控（启动扫描发现威胁时上方死等
    # 退出，不会走到这里——标记仅在守卫真正就绪后设置）
    [Environment]::SetEnvironmentVariable('AURORA_GUARD_PROCESS_INITIALIZED', '1', 'Process')

} catch {
        $guardInitRetryCount++
        Write-Host (_GL "[守卫] 初始化失败 (第 $guardInitRetryCount 次): $($_.Exception.Message)" "[Guard] Init failed (attempt $guardInitRetryCount): $($_.Exception.Message)") -ForegroundColor Yellow
        if ($_.Exception.InnerException) {
            Write-Host (_GL "[守卫] 内部错误：$($_.Exception.InnerException.Message)" "[Guard] Inner error: $($_.Exception.InnerException.Message)") -ForegroundColor Red
        }

        if ($guardInitRetryCount -ge $guardInitMaxRetry) {
            # 🔒 安全修复 C-7：初始化失败必须强制退出，不能以降级模式继续运行
            # 降级模式会让进程在无安全守卫保护下运行，攻击者可通过让初始化失败来绕过所有检测
            Write-Host (_GL "[安全守卫] 已达到最大重试次数，安全守卫初始化失败" "[Guard] Max retries reached, security guard init failed") -ForegroundColor Red
            Write-Host (_GL "[安全守卫] 为安全起见，进程将强制退出" "[Guard] For safety, process will force exit") -ForegroundColor Red
            # 🔒 M-3：堆栈跟踪仅写入日志文件，不输出到控制台
            try {
                $logDir = Join-Path $env:LOCALAPPDATA "AURORA\Logs"
                if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
                Add-Content -Path (Join-Path $logDir "security_error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Init failed`r`n$($_.ScriptStackTrace)`r`n---`r`n" -Encoding UTF8
            } catch {}
            # 强制退出（fail-closed）
            [Environment]::Exit(1)
        }
    }
}
} catch {
    # 🔒 安全修复 C-7：外层 catch 同样必须强制退出
    Write-Host (_GL "[安全守卫] 加载失败，进程将强制退出" "[Guard] Load failed, process will force exit") -ForegroundColor Red
    # 🔒 M-3：错误详情和堆栈跟踪仅写入日志文件，不输出到控制台
    try {
        $logDir = Join-Path $env:LOCALAPPDATA "AURORA\Logs"
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        $errDetail = "$($_.Exception.Message)"
        if ($_.Exception.InnerException) { $errDetail += "`r`nInner: $($_.Exception.InnerException.Message)" }
        $errDetail += "`r`n$($_.ScriptStackTrace)"
        Add-Content -Path (Join-Path $logDir "security_error.log") -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Load failed`r`n$errDetail`r`n---`r`n" -Encoding UTF8
    } catch {}
    # 强制退出（fail-closed）
    [Environment]::Exit(1)
}

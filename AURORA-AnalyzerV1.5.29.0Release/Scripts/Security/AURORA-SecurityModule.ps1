<#
.SYNOPSIS
    AURORA 系统安全模块
.DESCRIPTION
    提供系统安全相关的功能，如会话管理、加密操作等。
.NOTES
    版本：V1.5.29.0Release | 构建时间：2026.07.21
    作者：AURORA VelociRaptor-GR Dev PRJ.
    已独立至独立文件，避免与主脚本代码混合。
#>

# ==========================================
# 🔐 RSA 公钥验证模块（构建时注入）
# ==========================================
$global:AURORA_PublicKeyXml = @'
<RSAKeyValue><Modulus>oh3xIbuXM96tQoBUoTcmLEhy3VAVImBmY7iAK4BRfB0yjX+j2Vk4NTPmM85HW9BkoZCbcdSXTUJvzKNN4HJ4A2dbIU5SnNiBGDhusMLBEK777k5g6Xm0zUXCCdPStZl14wR0Z1yRtqJamYZUWNOil6i6Lngy+2eWw/LveUOgbj6YvFARJe+FzdRR8oMyxk5ngtHaK9BdTX25L5hGtvcCfOrGCLO0bAESIBDHriF/3CL45EwoC0V5D6zil13PRr3RdkugxNTYPX2kvBwnUVi9cQ8GzJtS1oYD4P+subZ+XWMAySeG4au195fkVnrCU/83n3DLvxSfUqk47G8juGaBjQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>
'@

$global:AURORA_SessionSalt = [Convert]::FromBase64String('yQFd5xBibxjnLVk4d+vc+J62HzSTMwLFPI4FzRkuols=')

$global:AURORA_AesSalt = [Convert]::FromBase64String('L3MqekRYHemtNhssdm7N0kmeQo6iiwTvvGWC/QSjVRA=')
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
        $sessionKey = (New-Object System.Security.Cryptography.Rfc2898DeriveBytes(
            $Nonce,
            $global:AURORA_AesSalt,
            100000,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )).GetBytes(32)
        
        $payloadBytes = [Convert]::FromBase64String($HashPayload)
        if ($payloadBytes.Length -lt 17) { throw 'Invalid hash payload' }
        
        $sessionIv = $payloadBytes[0..15]
        $cipher = $payloadBytes[16..($payloadBytes.Length - 1)]
        
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
            Write-Host "[退出处理] 资源已紧急清理" -ForegroundColor DarkGray
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
        Write-Host "[退出处理] 无法注册 ProcessExit 事件" -ForegroundColor DarkGray
    }

    $script:AuroraExitHandlerRegistered = $true
    Write-Host "[退出处理] 已注册进程级退出清理程序" -ForegroundColor DarkGray
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
        { "Scripts\\UI\\Controls\\AURORA-UIControls.ps1", "5461b9225c39f7343f966cf9c23e760c15883a8654522ec6163a8a6c642b15cd" },
        { "Scripts\\UI\\Controls\\AURORA-Animations.ps1", "1b9d5b3813aba884143fb7d470206d365235966f855e36aada7bc9fe263eba0d" },
        { "Scripts\\UI\\Views\\View-SplashScreen.ps1", "0da490d6c01511c0035cc04aee2264b4aeb14b94ad836f1e780dd9251a2c3a33" },
        { "Scripts\\UI\\Views\\View-MainForm.ps1", "e41e7b3f97d1727be6a277b14b028279ad3974f852ebabac6f4320c2e7ee7517" },
        { "Scripts\\UI\\Views\\View-ProMode.ps1", "a6e5b20eaac8cf3020011cf5b069a8d5927740b5db03a68a9d67f40b1fe7f06a" },
        { "Scripts\\UI\\Views\\Dialogs\\View-SessionRestoreDialog.ps1", "4452ae40728e8089600157fb13f17a63f4113c784f51db3a145eccf7e26d85fb" },
        { "Scripts\\UI\\Views\\Dialogs\\View-ElevationDialog.ps1", "b12733c71b003806ba9123e1aac6ef3935dd593b00f85bf15c12a4b0fe1d30fc" },
        { "Scripts\\UI\\Views\\Dialogs\\View-PermissionInfo.ps1", "4c7e369c02e474a48b574cd26f987c0605fc4bdd5e5d370c5539310437a7bd70" },
        { "Scripts\\UI\\Views\\Dialogs\\View-AdminElevation.ps1", "3cf039b32cbfd10b9e970dd2b064d082aa5df1994077378d36d82da551946b59" },
        { "Scripts\\Engines\\AURORA-SmartEngine.ps1", "785d5086f4f2878c80ef0fee9066d9ffb658f33707d1f09c95b6b0759c2dd85e" },
        { "Scripts\\Core\\AURORA-CoreEngine.ps1", "b92f5e5bdb383723736213260c0a87e19c692388bb0bda1b8168af3f9ccff382" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO-Engine.ps1", "20c4bb1a3a47b66b1d08b3a35db28a30192ca800dece05fb31e6e9afe5fde570" },
        { "Scripts\\Session\\AURORA-ProgressManager.ps1", "7ac0557aaf81c7192eb4f9bcaa6a14a924a070fe62ba02fc3d87757857299ac3" },
        { "Scripts\\GUI\\AURORA-GUI-Functions.ps1", "6dc8f50311bf8dc5c773126141327b920c745f4a4a98670f7ff5714d5c1ba2c4" },
        { "Scripts\\Repair\\AURORA-RepairTools.ps1", "98c94801f051805dbc1fffc819778f858e60f6b127bc4c80303b865ce8c4d1d5" },
        { "Scripts\\Session\\AURORA-UndoManager.ps1", "08a8bd479e2c8ccc48203067c62d8177fdaeba8c112d4cc5594270376d28802e" },
        { "Scripts\\Repair\\AURORA-RestoreManager.ps1", "e6c293a9ece6328f43112e5be4483acd2439b37f01b331f8921ed64c87094a43" },
        { "Scripts\\Repair\\AURORA-RepairLogger.ps1", "e7c6e7c21b86b61e1248ab73181e1bab4005245fc3149b15d9fc28623d80725f" },
        { "Scripts\\Session\\AURORA-UndoViewer.ps1", "5630c1331d1a14760fb02160faa358ee5063d2b7aabaac788ffefa24d0e96aeb" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO.ps1", "dc975b268079d18740893f701e72f8f6c30e1d75b4da62a9ee43c0e30ea1eddb" },
        { "Scripts\\Session\\AURORA-ProgressManager-Integration.ps1", "0baa62dae76aadda7a9848a7bbf2d13d5ed9bd5537d3246113c8165965f40fe7" },
        { "Scripts\\Core\\AURORA-AnimationCoreEngine.ps1", "958cc8f079b1633f7bd7531228848af0ded0ef9e74a5f4dea30269f74753f2d4" },
        { "Scripts\\Core\\AURORA-LaunchGuard.ps1", "35fc9ce7ea399c6995fa0f8f22249a248522e2d7562733bf951b11118cad057f" },
        { "Scripts\\AURORA-AnalyzerLauncherGUI.ps1", "cacf4c49ddc48959de08e27bf435459de90ff912e7149007162cce443fd66000" },
        { "Data\\AURORA-TechData.json", "2338419e55b31168bf42a8191329f2668104f769ab3195a8ad8562db2656aa1d" }
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

    public static void Initialize(string baseDir)
    {
        _baseDir = baseDir;
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
            if (_baseDir == null || _expected.Count == 0)
            {
                DiagLog("CheckIntegrity: _baseDir=" + (_baseDir ?? "NULL") + ", _expected.Count=" + _expected.Count);
                result = false;
                return result;
            }
            DiagLog("CheckIntegrity: _baseDir=" + _baseDir + ", checking " + _expected.Count + " files");
            foreach (var kv in _expected)
            {
                string path = System.IO.Path.Combine(_baseDir, kv.Key);
                if (!File.Exists(path))
                {
                    DiagLog("CheckIntegrity FAIL: File not found: " + path);
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
    $AURORA_GUARD_INITIALIZED = $false
    $guardInitRetryCount = 0
    $guardInitMaxRetry = 3
    $guardInitRetryDelayMs = 500

    while ($guardInitRetryCount -lt $guardInitMaxRetry -and -not $AURORA_GUARD_INITIALIZED) {
        try {
            if ($guardInitRetryCount -gt 0) {
                Write-Host "[安全守卫] 等待 $($guardInitRetryDelayMs * $guardInitRetryCount)ms 后重试..." -ForegroundColor DarkGray
                Start-Sleep -Milliseconds ($guardInitRetryDelayMs * $guardInitRetryCount)
            }
            Write-Host "[安全守卫] 正在初始化 (第 $($guardInitRetryCount + 1) 次)..." -ForegroundColor Cyan

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
                Write-Host "[安全守卫] baseForGuard: $baseForGuard" -ForegroundColor DarkGray
                Write-Host "[安全守卫] rootDir: $rootDir" -ForegroundColor DarkGray

                [AuroraGuard]::Initialize($rootDir)
                $AURORA_GUARD_INITIALIZED = $true
                Write-Host "[安全守卫] 初始化成功" -ForegroundColor Green
            } catch [System.Management.Automation.MethodInvocationException] {
                # 🔒 安全修复 C-6：类型替换攻击防护
                # "already exists" 不等于安全——攻击者可能预加载同名伪类绕过检测
                # 必须验证已存在类型的来源程序集是否可信
                if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -like "*already exists*") {
                    Write-Host "[安全守卫] AuroraGuard 类型已存在，验证来源..." -ForegroundColor DarkGray

                    # 验证已存在的 AuroraGuard 类型是否来自可信源
                    $existingType = [System.Type]::GetType('AuroraGuard')
                    if ($null -ne $existingType) {
                        $assemblyLoc = $existingType.Assembly.Location
                        # 可信来源：动态程序集（Add-Type 编译的，Location 为空或临时路径）
                        # 不可信来源：外部加载的 DLL（Location 指向可疑路径）
                        if ([string]::IsNullOrEmpty($assemblyLoc) -or $assemblyLoc -match 'Anonymously\s+Hosted') {
                            Write-Host "[安全守卫] AuroraGuard 来源验证通过（动态程序集）" -ForegroundColor DarkGray

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

                            [AuroraGuard]::Initialize($rootDir2)
                            $AURORA_GUARD_INITIALIZED = $true
                            Write-Host "[安全守卫] 初始化成功" -ForegroundColor Green
                        } else {
                            # 类型来自外部 DLL，可能是类型替换攻击
                            Write-Host "[安全守卫] 警告：AuroraGuard 来自不可信程序集: $assemblyLoc" -ForegroundColor Red
                            Write-Host "[安全守卫] 可能存在类型替换攻击，拒绝使用该类型" -ForegroundColor Red
                            # 不初始化，降级模式会触发强制退出（C-7 修复）
                        }
                    }
                } else {
                    # 其他异常，重新抛出
                    Write-Host "[安全守卫] 初始化异常：$($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            } catch {
                Write-Host "[安全守卫] 初始化异常：$($_.Exception.Message)" -ForegroundColor Red
                throw
            }

            # 🔐 启动时立即执行环境安全扫描（类似完整性检测）
            Write-Host "[诊断] 正在执行环境安全扫描..." -ForegroundColor DarkGray
            $envDetectionReason = [AuroraGuard]::GetDetectionReason()
            Write-Host "[诊断] 扫描结果: $envDetectionReason" -ForegroundColor DarkGray
            if ($envDetectionReason -ne "NONE") {
                Write-Host "[安全守卫] 启动时检测到威胁：$envDetectionReason" -ForegroundColor Red

                $reasonText = switch ($envDetectionReason) {
                    "DEBUGGER_API" { "调试器 API 检测" }
                    "DEBUGGER_PROCESS" { "调试工具进程检测" }
                    "DLL_INJECTION" { "DLL 注入检测" }
                    "INTEGRITY_FAILURE" { "文件完整性验证失败" }
                    default { "未知威胁" }
                }

                Write-Host "[Security Alert] 启动时检测到调试或注入，程序将在 15 秒后退出..." -ForegroundColor Red

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
                Write-Host "[安全守卫] 启动环境扫描完成 - 安全" -ForegroundColor DarkGray
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

                    Write-Host "[Security Alert] 检测到调试或注入：$reasonText，程序将在 15 秒后退出..." -ForegroundColor Red
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
                Write-Host "[安全守卫] 可疑活动消失，判定为误报" -ForegroundColor DarkGray
                $script:LastDetectionReason = $null
                $script:ConsecutiveDetectionCount = 0
            }
            
            # 原地刷新正常日志
            $timestamp = Get-Date -Format "HH:mm:ss"
            $logLine = "[安全守卫] 环境安全检查通过 - 第 $($script:DebuggerCheckCount) 次 - $timestamp"
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
        Write-Host "[安全守卫] 持续性检测已跳过（AuroraGuardSkipMonitoring=true）" -ForegroundColor DarkGray
    } else {
        $script:debuggerTimer = New-Object System.Timers.Timer
        $script:debuggerTimer.Interval = $script:DebuggerCheckInterval * 1000
        $script:debuggerTimer.AutoReset = $true
        $script:debuggerTimer.Enabled = $true

        $action = [System.Timers.ElapsedEventHandler]$script:checkDebugger
        $script:debuggerTimer.add_Elapsed($action)

        Write-Host "[安全守卫] 已启动持续性检测（每 $($script:DebuggerCheckInterval) 秒）" -ForegroundColor DarkGray
    }
    
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  WMI 实时进程创建监控（零延迟）
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    $script:debuggerWmiWatcher = $null
    # [P0-修复] 同上 $AuroraGuardSkipMonitoring 开关：跳过 WMI 监控启动，
    #   避免 Register-ObjectEvent 在 RunspacePool 模式下与 SmartEngine 主流程冲突。
    if ($AuroraGuardSkipMonitoring) {
        Write-Host "[安全守卫] WMI 实时监控已跳过（AuroraGuardSkipMonitoring=true）" -ForegroundColor DarkGray
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
                        Write-Host "[安全守卫-WMI] 实时检测到调试器进程启动: $procName" -ForegroundColor Red
                        if (-not $script:ExitCountdownStarted) {
                            $script:ExitCountdownStarted = $true
                            Write-Host "[Security Alert] WMI实时检测到调试器进程，程序将在 15 秒后退出..." -ForegroundColor Red
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
        Write-Host "[安全守卫] 已启动 WMI 实时进程监控（零延迟）" -ForegroundColor DarkGray
    } catch {
        Write-Host "[安全守卫] WMI 实时监控启动失败，将仅使用轮询模式" -ForegroundColor Yellow
    }
    }  # end if ($AuroraGuardSkipMonitoring) else

} catch {
        $guardInitRetryCount++
        Write-Host "[守卫] 初始化失败 (第 $guardInitRetryCount 次): $($_.Exception.Message)" -ForegroundColor Yellow
        if ($_.Exception.InnerException) {
            Write-Host "[守卫] 内部错误：$($_.Exception.InnerException.Message)" -ForegroundColor Red
        }

        if ($guardInitRetryCount -ge $guardInitMaxRetry) {
            # 🔒 安全修复 C-7：初始化失败必须强制退出，不能以降级模式继续运行
            # 降级模式会让进程在无安全守卫保护下运行，攻击者可通过让初始化失败来绕过所有检测
            Write-Host "[安全守卫] 已达到最大重试次数，安全守卫初始化失败" -ForegroundColor Red
            Write-Host "[安全守卫] 为安全起见，进程将强制退出" -ForegroundColor Red
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
    Write-Host "[安全守卫] 加载失败，进程将强制退出" -ForegroundColor Red
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

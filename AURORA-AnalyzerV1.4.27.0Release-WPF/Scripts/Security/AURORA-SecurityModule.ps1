<#
.SYNOPSIS
    AURORA 系统安全模块
.DESCRIPTION
    提供系统安全相关的功能，如会话管理、加密操作等。
.NOTES
    版本：V1.4.27.0Release | 构建时间：2026.07.01
    作者：AURORA VelociRaptor-GR Dev PRJ.
    已独立至独立文件，避免与主脚本代码混合。
#>

# ==========================================
# 🔐 RSA 公钥验证模块（构建时注入）
# ==========================================
$global:AURORA_PublicKeyXml = @'
<RSAKeyValue><Modulus>r/tRBiXvQ0BHtqUqnahRcsp/PLA+9/O9osjfJbCpva1stIUm1S8kVP3c2HvJO5dOG/Hi+/FT8N2eCNteE2GJ21tbbNAfLZlVXTT/6XveS4ivWJmDk96KTl/+J7wnwujpNv/10mXqfvRrwO5q1gNPujsWrhLcNDrNuB+HUsUkrzV/rxKhXLSoYdHgj2DHlubfl+CHbAZ7ByzgkEtSIeQ5i7LLDz622EWVHZdxf9CmSI6m33KgNqUMBOmjz6SciGx49PkUetdkThFbK+eI4dBt7DkgL2i8GwiIxEFQG6LvZ4POzNL8dRDTaJCSJK7dsKfH74IgWBYmn6tNtFX9pvEQVQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>
'@

$global:AURORA_SessionSalt = [Convert]::FromBase64String('LqBp2O1tpEQzPGgKyxiq3/2PB0VL+gNYqVC4s8B/j1g=')

$global:AURORA_AesSalt = [System.Text.Encoding]::UTF8.GetBytes('AU_SESSION_2026_SALT_V1')

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
        Write-Warning "RSA token verification failed: $($_.Exception.Message)"
        Write-Debug "Stack: $($_.ScriptStackTrace)"
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
        Write-Warning "Hash list decryption failed: $($_.Exception.Message)"
        Write-Debug "Stack: $($_.ScriptStackTrace)"
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
        { "Scripts\\UI\\Controls\\AURORA-UIControls.ps1", "b4e433ddf21a93a54d5859bb7b7c07c343006b804c5eb185ef04d20268ac1a93" },
        { "Scripts\\UI\\Controls\\AURORA-Animations.ps1", "391c65574e333488b4e640f9e01237cd9bca3a78e5ca22b3721a97c624702b0a" },
        { "Scripts\\UI\\Views\\View-SplashScreen.ps1", "4793743f51a10335f599c6bc3fd40f4402ad00f33b680300c1893051edffd873" },
        { "Scripts\\UI\\Views\\View-MainForm.ps1", "e153f34119f56e5fcbcb8fddd501352e3e1b09a7163c990177cbeed7aec96cac" },
        { "Scripts\\UI\\Views\\View-ProMode.ps1", "9d72c92dcacacd49d1deca3ad059ed7e45725beb76003a30a11370e62c6be64b" },
        { "Scripts\\UI\\Views\\Dialogs\\View-SessionRestoreDialog.ps1", "ceca856214ef70880de556a28f26b1d092b5032db7fd5e8acbdc8fbb87b24667" },
        { "Scripts\\UI\\Views\\Dialogs\\View-ElevationDialog.ps1", "1e0fe83daf0da0caa48acce662de3ad65816aaa3f228aae1adcfe7f41e894901" },
        { "Scripts\\UI\\Views\\Dialogs\\View-PermissionInfo.ps1", "5d4c2bef261ffdb1e1909d5d794f96d50a708c899846572f06d50f53982c9f56" },
        { "Scripts\\UI\\Views\\Dialogs\\View-AdminElevation.ps1", "05b71829e48d5a6e05b23b460984db99b7d07af1be3d0882bae6a587151048f0" },
        { "Scripts\\Engines\\AURORA-SmartEngine.ps1", "c52b05d503958a8e8c8b69996cc91b43f2c6e35bb101fb27cb59de8deed20b08" },
        { "Scripts\\Core\\AURORA-CoreEngine.ps1", "05b42dd5afef67b8395be8031f5b499c6e290244a480d0224a1356fbcb6dbc77" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO-Engine.ps1", "7f1f939da30392344007906f96042192d4eca449295795f441b21abdb5c2fe0e" },
        { "Scripts\\Session\\AURORA-ProgressManager.ps1", "6b48759b583117e1ba29c53f38e2626b6ac1d24ee27b745ce5b1a1f84b1c7a46" },
        { "Scripts\\GUI\\AURORA-GUI-Functions.ps1", "58b3aa9f2f16748352f6a2aaff5f87c1685a5171c2a1ce74a6ff92d728522590" },
        { "Scripts\\Repair\\AURORA-RepairTools.ps1", "f549aa784a7440f2050c90a222dc2b849a8c7b15f2e46222bbdf3fe0c404c411" },
        { "Scripts\\Session\\AURORA-UndoManager.ps1", "a38fc83b4f058dcb35e719956971e576b240ea4cd65702292bc023f4eb01f7c2" },
        { "Scripts\\Repair\\AURORA-RestoreManager.ps1", "5412acd0fca515dab4378c2a5699619fbca70c919a30b7d14b2795a8e0398dae" },
        { "Scripts\\Repair\\AURORA-RepairLogger.ps1", "3e9040f0930b68a9805b1bd7170ba013376bc790682e8b73274ccbd0e3658988" },
        { "Scripts\\Session\\AURORA-UndoViewer.ps1", "5dc9303605d8138269ad63730b223dd7ce4133c0ae8b299211a3eae5a08db434" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO.ps1", "df9861e4dafb945429139cdd22ba9f8c027e0383cdd6bed3fcceb024a89ea0e3" },
        { "Scripts\\Session\\AURORA-ProgressManager-Integration.ps1", "c2bd715946f595d3bad224ae14238c448a25fcdaa9314904fcd1aa9730423bd7" },
        { "Scripts\\Core\\AURORA-AnimationCoreEngine.ps1", "c997169ca297dd8d0fe078d81b97c27b3148d000b167125d5d79b57c05e35c41" },
        { "Scripts\\Core\\AURORA-LaunchGuard.ps1", "35fc9ce7ea399c6995fa0f8f22249a248522e2d7562733bf951b11118cad057f" },
        { "Scripts\\AURORA-AnalyzerLauncherGUI.ps1", "8b3a652d243cc468237bd73279c45847d7fb943a54adedba51adef2eac2750da" },
        { "Data\\AURORA-TechData.json", "908f6377ff794568d068ba8c1bd011f058c929df8c5944261d5208ca41ec3a19" }
    };

    private static string _baseDir;
    private static DateTime _lastIntegrityCheck = DateTime.MinValue;
    private static bool _lastIntegrityResult = false;
    private static readonly TimeSpan _integrityCacheDuration = TimeSpan.FromSeconds(10);
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
                    DiagLog("CheckIntegrity FAIL: Hash mismatch for " + kv.Key);
                    DiagLog("  Expected: " + kv.Value);
                    DiagLog("  Actual:   " + (actual ?? "NULL"));
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
        try
        {
            Console.Error.WriteLine(msg);
            Console.Error.Flush();
            string logPath = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "aurora_guard_diag.log");
            System.IO.File.AppendAllText(logPath, DateTime.Now.ToString("HH:mm:ss.fff") + " " + msg + Environment.NewLine);
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
                
                # 🔴 关键修复：正确计算项目根目录
                # 由于本文件被 dot-source 到 LauncherGUI.ps1，$scriptDir 可直接访问
                # 如果不可用，使用 $PSScriptRoot（本文件所在目录 = Scripts\Security）
                $baseForGuard = if ($scriptDir) {
                    # LauncherGUI 中定义的 $scriptDir = Scripts 目录
                    $scriptDir
                } elseif ($PSScriptRoot) {
                    # $PSScriptRoot = Scripts\Security，需要向上两级到项目根目录
                    $PSScriptRoot
                } else {
                    Split-Path -Parent $MyInvocation.MyCommand.Definition
                }
                
                # 如果 $baseForGuard 是 Security 子目录，先向上到 Scripts，再向上到项目根目录
                if ((Split-Path -Leaf $baseForGuard) -eq 'Security') {
                    $scriptsDir = Split-Path -Parent $baseForGuard
                    $rootDir = Split-Path -Parent $scriptsDir
                } else {
                    # $baseForGuard 就是 Scripts 目录，向上到项目根目录
                    $rootDir = Split-Path -Parent $baseForGuard
                }
                
                # 诊断：输出路径信息
                Write-Host "[安全守卫] baseForGuard: $baseForGuard" -ForegroundColor DarkGray
                Write-Host "[安全守卫] rootDir: $rootDir" -ForegroundColor DarkGray
                
                [AuroraGuard]::Initialize($rootDir)
                $AURORA_GUARD_INITIALIZED = $true
                Write-Host "[安全守卫] 初始化成功" -ForegroundColor Green
            } catch [System.Management.Automation.MethodInvocationException] {
                # 类型已存在异常，说明已经加载过，直接使用
                if ($_.Exception.InnerException -and $_.Exception.InnerException.Message -like "*already exists*") {
                    Write-Host "[安全守卫] AuroraGuard 已加载，使用现有类型" -ForegroundColor DarkGray
                    
                    # 🔴 关键修复：正确计算项目根目录（与上面一致）
                    $baseForGuard2 = if ($scriptDir) {
                        $scriptDir
                    } elseif ($PSScriptRoot) {
                        $PSScriptRoot
                    } else {
                        Split-Path -Parent $MyInvocation.MyCommand.Definition
                    }
                    if ((Split-Path -Leaf $baseForGuard2) -eq 'Security') {
                        $scriptsDir2 = Split-Path -Parent $baseForGuard2
                        $rootDir2 = Split-Path -Parent $scriptsDir2
                    } else {
                        $rootDir2 = Split-Path -Parent $baseForGuard2
                    }
                    
                    [AuroraGuard]::Initialize($rootDir2)
                    $AURORA_GUARD_INITIALIZED = $true
                    Write-Host "[安全守卫] 初始化成功" -ForegroundColor Green
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
            $script:DebuggerCheckInterval = 3  # 每 3 秒检测一次（与完整性检测保持一致）
            $script:DebuggerCheckCount = 0
    
    $script:checkDebugger = {
        if ($script:ExitCountdownStarted) { return }
        
        $script:DebuggerCheckCount++
        $detectionReason = [AuroraGuard]::GetDetectionReason()
        
        if ($detectionReason -ne "NONE") {
            # 🔴 P2 修复：增加容错机制，要求连续 2 次检测到威胁才触发警报
            # 避免因内存分配延迟或系统调用失败导致的偶发误报
            if (-not $script:LastDetectionReason) {
                # 第一次检测到威胁，记录但不触发
                $script:LastDetectionReason = $detectionReason
                $script:LastDetectionTime = Get-Date
                $script:ConsecutiveDetectionCount = 1
                
                Write-Host "`n[安全守卫] 检测到可疑活动：$detectionReason (待确认)" -ForegroundColor Yellow
            } elseif ($script:LastDetectionReason -eq $detectionReason) {
                # 同一威胁连续检测到，确认真实威胁
                $script:ConsecutiveDetectionCount++
                
                if ($script:ConsecutiveDetectionCount -ge 2) {
                    # 连续 2 次确认，触发警报
                    $reasonText = switch ($detectionReason) {
                        "DEBUGGER_API" { "调试器 API 检测" }
                        "DEBUGGER_PROCESS" { "调试工具进程检测" }
                        "DLL_INJECTION" { "DLL 注入检测" }
                        "INTEGRITY_FAILURE" { "文件完整性验证失败" }
                        default { "未知威胁" }
                    }
                    
                    if (-not $script:ExitCountdownStarted) {
                        $script:ExitCountdownStarted = $true
                        
                        Write-Host "[Security Alert] 持续性检测发现调试或注入，程序将在 15 秒后退出..." -ForegroundColor Red
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
                } else {
                    Write-Host "[安全守卫] 确认可疑活动：$detectionReason (第 $($script:ConsecutiveDetectionCount) 次)" -ForegroundColor Orange
                }
            } else {
                # 不同的威胁，重置计数
                $script:LastDetectionReason = $detectionReason
                $script:ConsecutiveDetectionCount = 1
                Write-Host "`n[安全守卫] 检测到新的可疑活动：$detectionReason (待确认)" -ForegroundColor Yellow
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
    $script:debuggerTimer = New-Object System.Timers.Timer
    $script:debuggerTimer.Interval = $script:DebuggerCheckInterval * 1000
    $script:debuggerTimer.AutoReset = $true
    $script:debuggerTimer.Enabled = $true
    
    $action = [System.Timers.ElapsedEventHandler]$script:checkDebugger
    $script:debuggerTimer.add_Elapsed($action)
    
    Write-Host "[安全守卫] 已启动持续性检测（每 $($script:DebuggerCheckInterval) 秒）" -ForegroundColor DarkGray
    
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  WMI 实时进程创建监控（零延迟）
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    $script:debuggerWmiWatcher = $null
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
    
} catch {
        $guardInitRetryCount++
        Write-Host "[守卫] 初始化失败 (第 $guardInitRetryCount 次): $($_.Exception.Message)" -ForegroundColor Yellow
        if ($_.Exception.InnerException) {
            Write-Host "[守卫] 内部错误：$($_.Exception.InnerException.Message)" -ForegroundColor Red
        }

        if ($guardInitRetryCount -ge $guardInitMaxRetry) {
            Write-Host "[守卫] 已达到最大重试次数，将以降级模式运行" -ForegroundColor Red
            Write-Host "[守卫] 堆栈跟踪：$($_.ScriptStackTrace)" -ForegroundColor DarkGray
        }
    }
}
} catch {
    Write-Host "[守卫] 加载失败，将以降级模式运行" -ForegroundColor DarkYellow
    Write-Host "[守卫] 错误详情：$($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "[守卫] 内部错误：$($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    Write-Host "[守卫] 堆栈跟踪：$($_.ScriptStackTrace)" -ForegroundColor DarkGray
    $AURORA_GUARD_INITIALIZED = $false
}

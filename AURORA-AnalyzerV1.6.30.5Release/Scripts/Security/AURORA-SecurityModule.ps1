<#
.SYNOPSIS
    AURORA 系统安全模块
.DESCRIPTION
    提供系统安全相关的功能，如会话管理、加密操作等。
.NOTES
    版本：V1.6.30.5Release | 构建时间：2026.09.02
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
<RSAKeyValue><Modulus>xOpzdCFZLON6KOT0Qd1sBPIgTDeYiVyIrJ5bx4rw+JOqYgfpx5S2f0CWmrCjTl0HBtd7/pcsd9hEKmQ7aQg8slnbPS15q2DK+lPDKkWUGQCk5DsysMc7KOInxqXz+doVC8bXaKkO5OA76PairXGgyFPnksdJ3L55iDZfx8tXoiphgJG0+oSW5fzL9ui9iobQni0dY1LZpqMFI8dGdvowDYMcAAx5a4H4KGVE9tCW0XWb6BAqHy1vMn6ZHXwfED55E/E2DLilos29kKxRDbkZnHo1zgF7eN5SOH0kgEWrJhEbv5A9y1beqLJmkz9rWhRF0saK+bv1wosG7w0sB7XIAQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>
'@

$global:AURORA_SessionSalt = [Convert]::FromBase64String('EpJjaIIP5GoGrpBHp07YrSKA3ILE/WdV4oBnS8/Vok0=')

$global:AURORA_AesSalt = [Convert]::FromBase64String('4zpbL2VvrtUzv04AalbZiB3otXgoZlSDyD/lL740gVs=')
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
        { "Scripts\\UI\\Controls\\AURORA-UIControls.ps1", "c28e288aee16b37751c41e17242fa33ab552f6249d828424ac837c6b2dcf245c" },
        { "Scripts\\UI\\Controls\\AURORA-Animations.ps1", "c9fe5bf3a3d5a931aa8630362d1d0ab11f7d2b534a796117f302403ea526089a" },
        { "Scripts\\UI\\Views\\View-SplashScreen.ps1", "851f508ff94bbab257798fdd9b0332e95ed4982514b5a47fdd5f24061d4a29ae" },
        { "Scripts\\UI\\Views\\View-MainForm.ps1", "97cfe3c9d8bea3b4e76a13dbe93750b34f59118dc7c81bb8c22fb8b97b5f7c7b" },
        { "Scripts\\UI\\Views\\View-ProMode.ps1", "3646a277542ba06d49504d344d076fc6ec1aed224b01620b7914d3386ca25d9b" },
        { "Scripts\\UI\\Views\\Dialogs\\View-SessionRestoreDialog.ps1", "f334c3a4851e19577fae42a283b311dc8dae9c0ac4a2ef85901e25e9d3f9b85b" },
        { "Scripts\\UI\\Views\\Dialogs\\View-ElevationDialog.ps1", "141c8bbf3b8a6eee38dd52e67d11ae678d155ce21e09b708afbae0df0405b730" },
        { "Scripts\\UI\\Views\\Dialogs\\View-PermissionInfo.ps1", "4f2372353b7b35f3a6d64adfbfb91c52e3f09518e58fb78d372fe036cdc9ab5a" },
        { "Scripts\\UI\\Views\\Dialogs\\View-AdminElevation.ps1", "ed77e545c58480ca78d64660b8e5759e76205114c190f00d9fcb2b9a6b7923a7" },
        { "Scripts\\Engines\\AURORA-SmartEngine.ps1", "89849fa2cd873b76973fe142ccc04a9dca8b980a6b33930c55cab9e19e7e9e41" },
        { "Scripts\\Core\\AURORA-CoreEngine.ps1", "a094cbc30e1e02eec409fb4e7fa6a9c24ae9312a862e71a68ed887c3287a08c5" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO-Engine.ps1", "8b56edd429fd5d05340a275aad0f35ecb146cc0c8532873a1dfef0d868b457bf" },
        { "Scripts\\Session\\AURORA-ProgressManager.ps1", "4e486699921aa51b17ef77b5c653e0cb448f2b9a4123cf70437e2e8660dafd38" },
        { "Scripts\\GUI\\AURORA-GUI-Functions.ps1", "16bb4640a46465d0d756e5376929c4270cd8d94d1ab811b4ff15496a06899c7c" },
        { "Scripts\\Repair\\AURORA-RepairTools.ps1", "706ed77ccd8935501773ff146dbe692df6d33f47286128ce77f1124f3d1a783b" },
        { "Scripts\\Session\\AURORA-UndoManager.ps1", "1e783793eb31542743d9c7be0c36508c43cdec85bc99ee449d8b60fa141e0dec" },
        { "Scripts\\Repair\\AURORA-RestoreManager.ps1", "e17c0232683649da532ccf45d1c733b444bfb821ebef2c4bd43b4c105f6a42d0" },
        { "Scripts\\Repair\\AURORA-RepairLogger.ps1", "152fbf60554f854c16f91458ffe0ae14c1ef708ab0847acc1d874409ea8d4a94" },
        { "Scripts\\Session\\AURORA-UndoViewer.ps1", "f738ce0b5eb8dfb2a0a5ebf7268b0f65b8acf627095099b381149da60d7a6c47" },
        { "Scripts\\PRO\\AURORA-AnalyzerPRO.ps1", "c94dcb9c788c07656e7c3c94dff5f33580cb1cfa9167ba8bf417ca11be977926" },
        { "Scripts\\Session\\AURORA-ProgressManager-Integration.ps1", "610a7718d0173add93876c92e5c3978de929e8066828def02fde3f1ac9bdc76a" },
        { "Scripts\\Core\\AURORA-AnimationCoreEngine.ps1", "179843dcc280d586efa1e1642e697d450ee2a70bcb36f3deac477c2f0f71e721" },
        { "Scripts\\Core\\AURORA-LaunchGuard.ps1", "bf43ca6d369aa3aa9f8b36a2672fe9610e39847a5a0f3a2c83c1891b62d00e5a" },
        { "Scripts\\AURORA-AnalyzerLauncherGUI.ps1", "d0853528ef64c2c04110b02fa22682aa3cb9ba9311075e6e86aaac2e2cab2cdb" },
        { "Data\\AURORA-TechData.json", "178f2a8bb421781781059fa55eea7f848595a22ff79897e50bac3c3572aa9b5d" }
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

                [AuroraGuard]::Initialize($rootDir)
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

                            [AuroraGuard]::Initialize($rootDir2)
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

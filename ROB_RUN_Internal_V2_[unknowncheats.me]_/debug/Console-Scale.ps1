# Console-Scale.ps1 - pins the injector console to an explicit small face.
# Windows scales cmd.exe fonts with the display DPI (a 16 px face at 150% lands
# around 24 physical pixels), and the scaled log wraps away from the channel
# labels. This runs inside the same console as the batch, so the change applies
# to the window the logs are printed into.
param(
    [int]$Height = 12,
    [string]$Face = 'Consolas'
)

$source = @'
using System;
using System.Runtime.InteropServices;

namespace Amphetamine {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct ConsoleFontInfo {
        public uint cbSize;
        public uint nFont;
        public short dwFontSizeX;
        public short dwFontSizeY;
        public int FontFamily;
        public int FontWeight;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
        public string FaceName;
    }

    public static class ConsoleFont {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern IntPtr CreateFile(string name, uint access, uint share, IntPtr security,
                                              uint disposition, uint flags, IntPtr template);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetCurrentConsoleFontEx(IntPtr console, bool maximum, ref ConsoleFontInfo info);
    }
}
'@

try {
    Add-Type -TypeDefinition $source -ErrorAction Stop
} catch {
    exit 0
}

$info = New-Object Amphetamine.ConsoleFontInfo
$info.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf($info)
$info.FaceName = $Face
$info.dwFontSizeY = [int16]$Height
$info.dwFontSizeX = [int16]0
$info.FontFamily = 54   # FF_MODERN | TMPF_VECTOR | TMPF_TRUETYPE
$info.FontWeight = 400

# STD_OUTPUT_HANDLE is a pipe when the caller redirects output, and a pipe has
# no font. CONOUT$ is the console itself, so the face change lands on the window
# the batch prints into.
$console = [Amphetamine.ConsoleFont]::CreateFile(
    'CONOUT$', 0x80000000 -bor 0x40000000, 0x1 -bor 0x2, [IntPtr]::Zero, 3, 0, [IntPtr]::Zero)
if ($console -eq [IntPtr]::Zero -or $console -eq [IntPtr](-1)) { exit 0 }

$null = [Amphetamine.ConsoleFont]::SetCurrentConsoleFontEx($console, $false, [ref]$info)
$null = [Amphetamine.ConsoleFont]::CloseHandle($console)

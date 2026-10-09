<#
    lib/common.ps1 - shared helpers for PowerShell wrappers.

    WHY THIS FILE EXISTS
      snowdreamtech/template's .agent/rules/shell.md mandates a three-file
      delegation pattern for cross-platform scripts:

          task.bat  ->  task.ps1  ->  task.sh
          (CMD entry)   (PS entry)    (POSIX logic, single source of truth)

      Wrappers must contain NO logic - they only forward execution. But the
      rules reference "$PSScriptRoot/lib/common.ps1" and a function called
      Invoke-ShellDelegation, neither of which shipped with that repository.
      This file provides the real forwarding primitive.

    USAGE (inside a thin .ps1 wrapper)
      . "$PSScriptRoot/../lib/common.ps1"
      Invoke-ShellDelegation (Join-Path $PSScriptRoot 'task.sh') $args

    THE TWO TRAPS THIS FILE EXISTS TO ABSORB
      1. WRONG SHELL. On Windows, a bare `Get-Command bash` frequently resolves
         to the Microsoft Store execution alias
         %LOCALAPPDATA%\Microsoft\WindowsApps\bash.exe - the WSL stub - rather
         than Git Bash. It looks like a POSIX shell and is not: it needs a
         distro, and it mounts drives at /mnt/c rather than /c. Blindly falling
         back to `bash` produces a bare exit code 127 with the message
         "No such file or directory" for a file that plainly exists.
         -> So Git for Windows' sh is located explicitly, and the shell FAMILY
            is detected so the path can be mapped correctly.

      2. WRONG PATH FORM. MSYS/Git Bash does not rewrite Windows-style
         arguments handed to it by a native process, and it treats a backslash
         as an escape character. 'D:\repo\task.sh' arrives as 'D:repotask.sh'.
         'D:/repo/task.sh' keeps its separators but the drive letter still does
         not resolve. MSYS wants /d/repo/task.sh; WSL wants /mnt/d/repo/task.sh.
         -> So the path is converted according to the detected shell family.

    NOTE ON THE ARGUMENT FORM
      The wrapper resolves and passes an ABSOLUTE path itself, rather than
      passing a bare name and letting this function guess the caller's
      directory. $PSScriptRoot inside a function defined in a dot-sourced file
      is ambiguous, so the caller supplies the path explicitly - a deliberate
      correction to the untested sketch in the template's rules.
#>

Set-StrictMode -Version Latest

function Get-ShellFamily {
    <#
    .SYNOPSIS
        Classify a shell binary by the path convention it expects.

    .OUTPUTS
        'msys'  -> /d/repo/task.sh    (Git for Windows, MSYS2, Cygwin)
        'wsl'   -> /mnt/d/repo/task.sh (WSL bash.exe)
        'posix' -> path used verbatim  (native Linux/macOS bash)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path
    )

    # The Store execution alias - a WSL launcher, not a real shell on disk.
    if ($Path -match '\\WindowsApps\\') {
        return 'wsl'
    }
    if ($Path -match '\\Git\\|\\msys|\\cygwin') {
        return 'msys'
    }
    if ($Path -match '^/') {
        return 'posix'
    }
    return 'msys'
}

function Get-PosixShell {
    <#
    .SYNOPSIS
        Locate the best available POSIX shell and report its family.

    .OUTPUTS
        A hashtable with Path and Family keys, or $null when none is found.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # 1. Git for Windows, by explicit install location. This is the strongest
    #    signal available: the repository is a git repository, so git exists,
    #    and git ships a POSIX shell that needs no extra setup. Checked FIRST
    #    so the WSL stub on PATH can never win.
    $roots = @(
        [Environment]::GetEnvironmentVariable('ProgramFiles'),
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        [Environment]::GetEnvironmentVariable('LOCALAPPDATA')
    ) | Where-Object { $_ }

    foreach ($root in $roots) {
        $suffixes = @(
            'Git\bin\sh.exe',
            'Git\usr\bin\sh.exe',
            'Programs\Git\bin\sh.exe'
        )
        foreach ($suffix in $suffixes) {
            $candidate = Join-Path $root $suffix
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return @{ Path = $candidate; Family = 'msys' }
            }
        }
    }

    # 2. Whatever is named sh on PATH.
    $sh = Get-Command -Name 'sh' -CommandType Application -ErrorAction SilentlyContinue
    if ($sh) {
        return @{ Path = $sh.Source; Family = (Get-ShellFamily -Path $sh.Source) }
    }

    # 3. bash on PATH - accepted, but classified so the path form stays correct.
    $bash = Get-Command -Name 'bash' -CommandType Application -ErrorAction SilentlyContinue
    if ($bash) {
        return @{ Path = $bash.Source; Family = (Get-ShellFamily -Path $bash.Source) }
    }

    return $null
}

function ConvertTo-PosixPath {
    <#
    .SYNOPSIS
        Convert a Windows path into the form the target shell family expects.

    .PARAMETER Path
        The path to convert.

    .PARAMETER Family
        Shell family from Get-ShellFamily: msys, wsl or posix.

    .EXAMPLE
        ConvertTo-PosixPath -Path 'D:\repo\task.sh' -Family msys
        # -> /d/repo/task.sh
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter()]
        [ValidateSet('msys', 'wsl', 'posix')]
        [string] $Family = 'msys'
    )

    $normalised = $Path -replace '\\', '/'

    if ($Family -eq 'posix') {
        return $normalised
    }

    if ($normalised -notmatch '^([A-Za-z]):/(.*)$') {
        return $normalised
    }

    $drive = $Matches[1].ToLowerInvariant()
    $rest = $Matches[2]

    switch ($Family) {
        'wsl' {
            return "/mnt/$drive/$rest"
        }
        default {
            # MSYS/Cygwin. cygpath is authoritative when present, because the
            # mount table can be customised; the /<drive>/ form is the default.
            $cygpath = Get-Command -Name 'cygpath' -CommandType Application -ErrorAction SilentlyContinue
            if ($cygpath) {
                $converted = & $cygpath.Source -u -- $Path 2>$null
                if ($LASTEXITCODE -eq 0 -and $converted) {
                    return ([string] $converted).Trim()
                }
            }
            return "/$drive/$rest"
        }
    }
}

function Invoke-ShellDelegation {
    <#
    .SYNOPSIS
        Run a POSIX shell script, forwarding arguments and the exit code.

    .DESCRIPTION
        Locates a POSIX shell, converts the script path into the form that
        shell understands, and runs it with the supplied arguments. Never
        returns - it terminates with the child's exit code so callers can chain
        it.

    .PARAMETER ScriptPath
        Absolute path to the .sh file holding the real logic.

    .PARAMETER Arguments
        Arguments forwarded verbatim. Windows paths passed as script arguments
        are NOT converted - pass POSIX paths, or convert them in the caller.

    .EXAMPLE
        Invoke-ShellDelegation (Join-Path $PSScriptRoot 'demo.sh') $args
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ScriptPath,

        [Parameter()]
        [string[]] $Arguments = @()
    )

    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        Write-Error "shell script not found: $ScriptPath"
        exit 1
    }

    $shell = Get-PosixShell
    if (-not $shell) {
        Write-Error 'no POSIX shell found. Install Git for Windows (it ships sh) or use WSL.'
        exit 127
    }

    $posixPath = ConvertTo-PosixPath -Path $ScriptPath -Family $shell.Family

    & $shell.Path $posixPath @Arguments
    exit $LASTEXITCODE
}

function Get-MgcFreePort {
    <#
    .SYNOPSIS
        Returns an OS-assigned free TCP port on the loopback interface.
    #>
    [CmdletBinding()]
    param()

    $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $tcp.Start()
    try { return [int]$tcp.LocalEndpoint.Port } finally { $tcp.Stop() }
}

function Initialize-GoProAPI {
    <#
    .SYNOPSIS
    Initializes the GoPro API connection parameters.

    .PARAMETER IP
    The IP address of the GoPro camera.

    .PARAMETER Port
    The port number for the GoPro camera API. Default is 8080.

    .EXAMPLE
    Initialize-GoProAPI -IP "192.168.1.1" -Port "8080"
    #>
    param(
        [string]$IP,
        [string]$Port = "8080"
    )

    $global:GoProUrl = "http://$IP`:$Port"
    $global:GoProPort = $Port
    $global:GoProIP = $IP
    Write-Output "GoPro API initialized with URL: $global:GoProUrl"
}

function Enable-USBMode {
    <#
    .SYNOPSIS
    Enables USB mode on the GoPro camera.
    
    .EXAMPLE
    Enable-USBMode
    
    #>


    Write-Host "Before I enable USB mode, i will check if webcam mode is enabled (not allowed to be used with USB mode)"
    $GetStatus = Invoke-RestMethod -Uri "$($global:GoProUrl)/gopro/webcam/status" -Method Get -TimeoutSec 5
    if ($GetStatus.status -eq 2) {
        Write-Host "Webcam mode is enabled, please disable it first using the Stop-Webcam command." -ForegroundColor Red
        return
    }

    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/control/wired_usb?p=1" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "USB mode enabled successfully."
        } 
        else {
            Write-Output "Failed to enable USB mode. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error enabling USB mode: $_"
    }
}

function Disable-GoProUSBMode {
    <#
    .SYNOPSIS
    Disables USB mode on the GoPro camera.

    .EXAMPLE
    Disable-GoProUSBMode
    
    #>
    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/control/wired_usb?p=0" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "USB mode disabled successfully."
        } 
        else {
            Write-Output "Failed to enable USB mode. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error enabling USB mode: $_"
    }
}

function Enable-GoProKeepAlive {
    <#

    .SYNOPSIS
    Enables the keep-alive mechanism to maintain the GoPro camera session.

    .EXAMPLE
    Enable-GoProKeepAlive
    Starts the keep-alive process to send periodic requests to the GoPro camera.
    #>

    while ($true) {
        try {
            $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/keep_alive" -Method Get -TimeoutSec 5
            if ($response.StatusCode -eq 200) {
                Write-Output "Session kept alive at $(Get-Date)."
            } 
            else {
                Write-Output "Failed to keep session alive. Status Code: $($response.StatusCode)"
            }
        } 
        catch {
            Write-Output "Error keeping session alive: $_"
        }
        Start-Sleep -Seconds 30
    }
}

function Start-GoProStream {
    
    <#
    .SYNOPSIS
    Starts the GoPro camera stream over UDP.

    .EXAMPLE
    Start-GoProStream
    Starts the UDP stream on the GoPro camera.
    #>

    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/stream/start?port=8554" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "Stream started successfully."
        } 
        else {
            Write-Output "Failed to start stream. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error starting stream: $_"
    }
}

function Stop-GoProStream {
    <#
    .SYNOPSIS
    Stops the GoPro camera stream.

    .EXAMPLE
    Stop-GoProStream
    Stops the UDP stream on the GoPro camera.

    #>

    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/stream/stop" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "Stream stopped successfully."
        } 
        else {
            Write-Output "Failed to stop stream. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error stopping stream: $_"
    }
}

function Receive-GoProUDPStream {
    <#
    .SYNOPSIS
    Receives a UDP stream from the GoPro camera and saves it to a file.
    You are required to start the stream on the GoPro first using Start-GoProStream function.
    .PARAMETER Port
    The UDP port to listen on. Default is 8554.

    .PARAMETER OutputFile
    The file path to save the received stream. Default is "gopro_stream_<timestamp>.ts".

    .EXAMPLE
    Receive-UDPStream -Port 8554 -OutputFile "gopro_stream.ts"
    Starts receiving the UDP stream on port 8554 and saves it to "gopro_stream.ts".

    #>
    param(
        [int]$Port = 8554,
        [string]$OutputFile = "gopro_stream_$(Get-Date -Format 'yyyyMMdd_HHmmss').ts"
    )
    
    try {
        Write-Output "Starting UDP client on port $Port..."
        Write-Output "Stream will be saved to: $OutputFile"
        
        $endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $Port)
        $udpClient = New-Object System.Net.Sockets.UdpClient $Port
        $udpClient.Client.ReceiveTimeout = 5000
        
        $fileStream = [System.IO.File]::OpenWrite($OutputFile)
        $receivedBytes = 0
        $startTime = Get-Date
        
        Write-Output "Listening for UDP stream data... Press Ctrl+C to stop."
        
        while ($true) {
            try {
                $data = $udpClient.Receive([ref]$endpoint)
                $fileStream.Write($data, 0, $data.Length)
                $receivedBytes += $data.Length
                
                # Progress update every 5 seconds
                $elapsed = (Get-Date) - $startTime
                if ($elapsed.TotalSeconds % 5 -lt 0.1) {
                    $mbReceived = [math]::Round($receivedBytes / 1MB, 2)
                    Write-Output "Received: $mbReceived MB | Duration: $([math]::Round($elapsed.TotalSeconds, 0))s"
                }
            }
            catch [System.Net.Sockets.SocketException] {
                # Timeout is normal, just continue
                continue
            }
        }
    }
    catch {
        Write-Output "Error receiving UDP stream: $_"
    }
    finally {
        if ($fileStream) {
            $fileStream.Close()
            $fileStream.Dispose()
        }
        if ($udpClient) {
            $udpClient.Close()
            $udpClient.Dispose()
        }
        $mbTotal = [math]::Round($receivedBytes / 1MB, 2)
        Write-Output "Stream stopped. Total received: $mbTotal MB"
    }
}

function Start-GoProWebcam {
    <#
        .SYNOPSIS
        Enables webcam mode on the GoPro camera.

        .EXAMPLE
        Start-GoProWebcam
        Enables webcam mode and starts the webcam stream.
    
    #>

    Write-Host "Checking to see if USB mode is enabled (not allowed to be used with webcam mode)..."
    Disable-GoProUSBMode

    try {
        $response = Invoke-RestMethod "$($global:GoProUrl)/gopro/webcam/start?res=12&fov=2&port=8556&protocol=RTSP" -Method Get -TimeoutSec 5
        if ($response.error -eq 0) {
            Write-Host "Webcam mode enabled successfully, you can now connect to the webcam stream via RTSP on port 554. rtsp://<GOPRO_IP_ADDRESS>:554/live"
            Write-Host "Trying to start VLC to view the stream..."
            Start-Process "vlc" "rtsp://$($global:GoProIP):554/live"
        } 
        else {
            Write-Output "Failed to start webcam mode. Status Code: $($response.StatusCode)"
            return
        }
    } 
    catch {
        Write-Output "Error enabling webcam mode: $_"
    }
}

function Stop-GoProWebcam {
    <#
        .SYNOPSIS
        Stops the webcam mode on the GoPro camera.

        .EXAMPLE
        Stop-GoProWebcam
        Stops the webcam mode on the GoPro camera.
    
    #>

    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/webcam/stop" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "Webcam mode stopped successfully."
        } 
        else {
            Write-Output "Failed to stop webcam mode. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error stopping webcam mode: $_"
    }
}

function Set-GoProModeByPresetId {
    try {
        # Step 1: Get all presets
        Write-Output "Fetching camera presets..."
        $response = Invoke-RestMethod -Uri "$($global:GoProUrl)/gopro/camera/presets/get" -Method Get -TimeoutSec 5
        
        # Step 2: Find the preset group for Photo mode (PRESET_GROUP_ID_PHOTO)
        $photoGroup = $response.presetGroupArray | Where-Object { $_.id -eq "PRESET_GROUP_ID_PHOTO" }
        
        if (-not $photoGroup) {
            Write-Output "Photo preset group not found."
            return
        }
        
        Write-Output "Found Photo preset group."
        
        # Step 3: Get the ID of FLAT_MODE_PHOTO_SINGLE preset
        $photoPreset = $photoGroup.presetArray | Where-Object { $_.mode -eq "FLAT_MODE_PHOTO_SINGLE" }
        
        if (-not $photoPreset) {
            Write-Output "FLAT_MODE_PHOTO_SINGLE preset not found."
            return
        }
        
        $presetId = $photoPreset.id
        Write-Output "Found FLAT_MODE_PHOTO_SINGLE preset with ID: $presetId"
        
        # Step 4: Load the preset
        $loadResponse = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/presets/load?id=$presetId" -Method Get -TimeoutSec 5
        
        if ($loadResponse.StatusCode -eq 200) {
            Write-Output "Photo mode loaded successfully."
        } 
        else {
            Write-Output "Failed to load photo mode. Status Code: $($loadResponse.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error loading photo mode: $_"
    }
}

function Set-GoProModeByGroupId {
    <#
        .SYNOPSIS
        Sets the camera preset group by Group ID. 

        .PARAMETER GroupId
        The ID of the preset group to load, they are hardcoded from the GoPro API and they are as follows:
        - PRESET_GROUP_ID_VIDEO = 1000
        - PRESET_GROUP_ID_PHOTO = 1001
        - PRESET_GROUP_ID_TIMELAPSE = 1002

        Reference: https://gopro.github.io/OpenGoPro/http#schema/PresetGroup
    
        .EXAMPLE
        Set-GoProModeByGroupId -GroupId 1001
        Sets the Photo preset group on the GoPro camera.
    #>

    param(
        [string]$GroupId
    )

    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/presets/set_group?id=$($GroupId)" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "Preset group $GroupId loaded successfully."
        } 
        else {
            Write-Output "Failed to load preset group $GroupId. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error loading preset group $($GroupId): $_"
    }
}

function Start-GoProShutter {
    <#
        .SYNOPSIS
        Starts the shutter to start the shutter on the current mode (photo/video/timelapse).
        If you want to set a specific mode, use the Set-GoProModeByGroupId function first.
        .EXAMPLE
        Start-GoProShutter
        Starts the shutter on the GoPro camera.
    #>
    try {
        $response = Invoke-WebRequest -Uri "$($global:GoProUrl)/gopro/camera/shutter/start" -Method Get -TimeoutSec 5
        if ($response.StatusCode -eq 200) {
            Write-Output "Shutter started successfully."
        } 
        else {
            Write-Output "Failed to start shutter. Status Code: $($response.StatusCode)"
        }
    } 
    catch {
        Write-Output "Error starting shutter: $_"
    }
}

Export-ModuleMember -Function Initialize-GoProAPI, Enable-GoProUSBMode, Disable-GoProUSBMode, Enable-GoProKeepAlive, Start-GoProStream, Stop-GoProStream, Receive-GoProUDPStream, Start-GoProWebcam, Stop-GoProWebcam, Set-GoProModeByPresetId, Set-GoProModeByGroupId, Start-GoProShutter
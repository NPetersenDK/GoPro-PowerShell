# GoPro PowerShell Module

A PowerShell module for controlling GoPro cameras via the HTTP API.

## Installation

### Option 1: Import from local directory
```powershell
Import-Module "GoPro-module.psd1"
```

### Option 2: Install to PowerShell modules directory
Copy the entire folder to one of your PowerShell module paths:
- User modules: `$env:USERPROFILE\Documents\PowerShell\Modules\GoPro-module\`
- System modules: `C:\Program Files\PowerShell\Modules\GoPro-module\`

Then import:
```powershell
Import-Module GoPro-module
```

## Usage
After importing the module, you can use the available functions to control your GoPro camera. Start by initializing the API connection:

If you have a GoPro camera connected via USB, your IP address is the following: 172.2X.1YZ.51:8080. Where X, Y and Z are the last three digits of your camera's serial number.
After you have that information, you can initialize the module with the following command:

```powershell
Initialize-GoProAPI -IP "XXX.XXX.XXX.XXX" -Port "8080"
```

### GoPro USB Mode
GoPro USB Mode allows you to control the camera while it is connected via USB. For example:
- Start/stop recording
- Change camera settings (not supported by this module)
- Enable Webcam Mode
- Record locally using a UDP stream

To enable USB mode on the camera:
```powershell
Enable-GoProUSBMode
```

To disable USB mode:
```powershell
Disable-GoProUSBMode
```

### Webcam Mode
GoPro Webcam Mode allows you to use your GoPro as a webcam via RTSP stream. You **CANNOT** use WebCam Mode in USB Mode, you will be asked to disable USB Mode first.

You can enable webcam mode with:
```powershell
Start-GoProWebcam
```

After enabling webcam mode, you can open the RTSP stream in VLC or any other compatible software using the following URL:
```
rtsp://<GoPro_IP_Address>:554/live
```

To stop webcam mode:
```powershell
Stop-GoProWebcam
```

## USB Mode Functions

### Change Camera Mode
You can change the camera mode using Group IDs
```powershell
Set-GoProModeByGroupId -GroupId <GroupId>
```

The available Group IDs are:
- PRESET_GROUP_ID_VIDEO = 1000
- PRESET_GROUP_ID_PHOTO = 1001
- PRESET_GROUP_ID_TIMELAPSE = 1002
More information available here: https://gopro.github.io/OpenGoPro/http#schema/PresetGroup

### Start GoPro Shutter
You can start the camera shutter (recording or photo capture) using:
```powershell
Start-GoProShutter
```

**Info**:
- Change the camera mode using `Set-GoProModeByGroupId` before starting the shutter, if needed.

### GoPro streaming via UDP
You can start a UDP stream from the GoPro camera to record locally on your computer.
To start the UDP stream:
```powershell
Start-GoProStream
```

After that you can receive the UDP stream and save it to a file using:
```powershell
Receive-GoProUDPStream -OutputFile "C:\Path\To\Save\gopro_stream.mp4" 
```

Stop using CTRL + C in the PowerShell window to stop receiving the stream.
To stop the UDP stream on the GoPro camera:
```powershell
Stop-GoProStream
```

## Available Functions

- `Initialize-GoProAPI` - Initialize the GoPro API connection
- `Enable-GoProUSBMode` - Enable USB mode on the camera
- `Disable-GoProUSBMode` - Disable USB mode
- `Enable-GoProKeepAlive` - Keep the camera session alive
- `Start-GoProStream` - Start UDP streaming
- `Stop-GoProStream` - Stop UDP streaming
- `Receive-GoProUDPStream` - Receive and save UDP stream
- `Start-GoProWebcam` - Enable webcam mode (RTSP)
- `Stop-GoProWebcam` - Stop webcam mode
- `Set-GoProModeByPresetId` - Set mode by preset ID
- `Set-GoProModeByGroupId` - Set mode by group ID
- `Start-GoProShutter` - Start the camera shutter

## Requirements

- PowerShell 7.0 or higher
- Network connectivity to GoPro camera
- VLC player (optional, for webcam viewing)
# ESD to ISO script for Windows 10 & 11

PowerShell script that downloads the same ESD files as the Media Creation Tool for Windows 10 and Windows 11 and converts them to fully functional ISO files.

This script is intended for downloading Windows 10 or 11 for ARM64-powered devices and using them with compatible hypervisors for devices such as Mac computers with the Apple Silicon (ARM64-based SoC), as there is no official tool from Microsoft to download such ISOs.

## Prerequisites

This PowerShell script __only works on Windows__ because it makes use of the _Deployment Image Servicing and Management (DISM)_ tool as well as the _Oscdimg_ tool, both only available on Windows.

This script also requires the latest __Windows Assessment and Deployment Kit__ _(Windows ADK)_, more specifically, the __Deployment Tools__ package to generate the ISO files by using the bundled _Oscdimg_ tool (you can download it [here](https://learn.microsoft.com/en-us/windows-hardware/get-started/adk-install)).

## Usage

First, open a PowerShell terminal as Administrator and change to the directory where the `esd2iso.ps1` file is located (you can use `pushd <path_to_directory>`, for example).

Then, execute the following sentence to change the execution policy for the current proccess to allow this PowerShell script execution (don't worry, once you close the terminal, the security policy will return to the default settings, as the scope is of the process only):

```ps
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

Then, execute the PowerShell script with the following parameters to begin with the ESD download and the ISO conversion (the provided command is an example):

```ps
.\esd2iso.ps1 -Windows 11 -LanguageCode "es-es" -Edition "Professional" -Architecture "ARM64" -WorkingPath ".\temp"
```

Where:
-   `-Windows`. It can be __10__ or __11__.

-   `-LanguageCode`. This is the Windows Language Code Identifier (__LCID__).

    A list can be found [here](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oe376/6c085406-a698-4e12-9d4d-c3b0ee3dbc4a) (but remember that not every language code is available to download).
    
    It must be lowercase.

-   `-Edition`. This is the Windows edition to download.

    For Consumer Editions _(Home, Pro and Education)_, you can use __Core__, __Professional__ or __Education__ interchangeably.
    
    For Business Editions _(Enterprise)_, you must use __Enterprise__.
    
    _"N"_ variants are also included in each edition package.
    
    Edition name must be capitalized (it's case-sensite).

-   `-Architecture`. This is the target architecture of the operating system.

    It can be __x86__ (Windows 10 only), __x64__ and __ARM64__.
    
    It's also case-sensitive.

-   `-WorkingPath`. This is an optional parameter (__.\temp__ by default) and it's the directory where the script will be downloading and extracting the ISO.

    If the directory exists, it will be deleted and recreated, so keep an eye on what you have in the directory.

As a result of the script execution, a new ISO file will be stored on the same root path as the `esd2iso.ps1` (I'll change this in the future to choose an output directory, but my time is very limited).

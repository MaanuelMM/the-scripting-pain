# Universal Windows Platform (UWP) Apps offline deployment (licenses and self-signed certificates)

Continuing with my (abandoned) adventure of preparing a customized offline Windows image for an unattended deployment with everything required to have a system ready to use, here are the scripts and licenses needed for the installation of the system utilities based on Metro Apps. Particularly, it will be the utilities used on every Lenovo device in addiction of a couple of utilities specific to my hardware, which are:

- **Intel® Graphics Command Center** _(AppUp.IntelGraphicsExperience_8j3eq9eme6ctt)_: license extracted from HP recovery media issued on 2022-03-18T23:09:22.4248996Z.

- ~~**Intel(R) Management and Security Status** _(AppUp.IntelManagementandSecurityStatus_8j3eq9eme6ctt)_: license extracted from HP recovery media issued on 2022-02-09T07:39:32.2717508Z.~~

- ~~**Intel® Optane™ Memory and Storage Management** _(AppUp.IntelOptaneMemoryandStorageManagement_8j3eq9eme6ctt)_: unable to find offline license.~~

- **Lenovo Vantage** _(E046963F.LenovoCompanion_k1h2ywk1493x8)_: license extracted from Lenovo recovery media issued on 2019-08-22T16:38:04.1540033Z.

- **Lenovo Hotkeys** _(E0469640.LenovoUtility_5grkq8ppsgwt4)_: license extracted from Lenovo recovery media issued on 2019-07-10T01:15:31.4582494Z.

- **Lenovo Nerve Center** _(E0469640.NerveCenter_5grkq8ppsgwt4)_: license extracted from Lenovo recovery media issued on 2017-09-05T01:18:05.8773296Z.

- **Microsoft HEVC Video Extensions** _(Microsoft.HEVCVideoExtensions_8wekyb3d8bbwe)_: license extracted from Microsoft's VLSC (Volume Licensing Service Center) issued on 2021-06-22T00:38:33.3092642Z.

- **NVIDIA Control Panel** _(NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj)_: license extracted from HP recovery media issued on 2022-01-17T11:35:32.7606232Z.

- **SynLenovoLBGDApp** _(SynapticsIncorporated.SynLenovoLBGDApp_807d65c4rvak2)_: bundled and self-signed APPX (script to extract CERT from APPX, add to Trusted People cert store and deploy it included).


# Mission Impossible - Appx License

Let's be brief (HA!). This folder is intened to actually deploy Appx (or AppxBundle) into a custom Windows offline image, however, an offline license is needed too.

It's possible to use the well-known Microsoft Store for Business (or for Education). In fact, I tried by using an institutional account to accomplish that purpose, but it's pretty impossible due to missing permissions (even if it's a free app).

There are two alternatives: obtain those licenses through third-parties or create a "free tier" personal Azure AD admin account and use with Microsoft Store for Business. ~~For the moment, I'm only missing one license, and it's expected to be obtained with a recovery media from another Lenovo laptop.~~ DONE!

Despite this, there is an Appx license which it's pretty impossible to obtain, and this is "SynLenovoLBGD App". It's self-signed, not signed by Microsoft (and, as a consequence, not deployed on Microsoft's servers), and that's why the Azure alternative it's unattainable. To make matters worse, because of that self-signature, it's not recognized by any root certificate (bravo, Lenovo!), and adding a certificate to an offline image isn't available.

The last alternative is by using 'Audit Mode' through 'Sysprep' and do whatever I want, but let's be honest, I'm not a huge fan of this and it makes me very lazy, and that's why this folder is pure crap.
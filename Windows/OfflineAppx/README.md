# Mission Impossible - Appx License

Let's be brief (HA!). This folder is intened to actually deploy Appx (or AppxBundle) into a custom Windows offline image, however, an offline license is needed too.

It's possible to use the well-known Microsoft Store for Business (or for Education). In fact, I tried by using an institutional account to accomplish that purpose, but it's pretty impossible due to missing permissions (even if it's a free app).

There are two alternatives: obtain those licenses through third-parties or create a "free tier" personal Azure AD admin account and use with Microsoft Store for Business. For the moment, I'm only missing one license, and it's expected to be obtained with a recovery media from another Lenovo laptop.

Despite this, there is an Appx license which it's pretty impossible to obtain, and this is "SynLenovoLBGD App". It's self-signed, not signed by Microsoft (and, as a consequence, not deployed on Microsoft's servers), and that's why the Azure alternative it's unattainable. To make matters worse, because of that self-signature, it's not recognized by any root certificate (bravo, Lenovo!), and adding an certificate to an offline image isn't available.

The last alternative is by using 'Audit Mode' through 'Sysprep' and do whatever I want, but let's be honest, I'm not a huge fan of this and it makes me very lazy, and that's why this folder is pure crap.
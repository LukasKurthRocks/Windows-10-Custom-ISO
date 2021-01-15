# Pre-Thoughts:
v2 has been fun, but that way i had to download an ISO manually and add/remove the stuff i want.
v3: Added the UUP downloading stuff.
In the end i wondered: How i can i optimize the process of creating the ISO files i want.
So this here:
- Business ISO
-> Enterprise (Updates Only)
-> Enterprise with RSAT (Admins Only) => Implementing RSAT in SCCM
-> Enterprise with all LanguagePacks we COULD need => Implementing LPs in SCCM like the ones for office16.
	EITHER only for Sticks
	OR in SCCM, so we have all LPs an every machine!

- Private ISO
-> Home, Pro, Enterprise and Education
-> Office and Windows Activation

- ALL
-> UUP Update files
-> Customization

These Script get big, so we will need to export functions and variables to own script-files.

# TODOS:
- Search version 1

# Changes:
02.08.2019 - Re-Done 1._DownloadWindowsUUP.ps1
## Script: 1._DownloadWindowsUUP.ps1
I have kinda re-worked on the first script to make it more logical than the v3 one.
Now i have a script i like for the way, i can download the UUP files.
One thing i have not put into yet is the movement of the UUP files/Fod files, but i guess it can stay there.
After the step where i will/would add the feautres like RSAT or Languages i guess we will not need them anymore.
I might add that to the next script, so we can copy them for SCCM...

Next: Second Script

## ISO Image CReator Problem ##
Had to do some investigations...
It seems that there is a problem with the update process.
I might have do this on my own. Good that i have split thos processes already.

Without Updates we have this:
	Index Name              Edition       Architecture Version    Build Level Languages
	----- ----              -------       ------------ -------    ----- ----- ---------
	1     Windows 10 Home   Core          x64          10.0.18362 1     0     de-DE (Default)
	2     Windows 10 Pro    Professional  x64          10.0.18362 1     0     de-DE (Default)
	3     Windows 10 Home N CoreN         x64          10.0.18362 1     0     de-DE (Default)
	4     Windows 10 Pro N  ProfessionalN x64          10.0.18362 1     0     de-DE (Default)

With Updates we have this:
	Index Name              Edition       Architecture Version    Build Level Languages
	----- ----              -------       ------------ -------    ----- ----- ---------
	1     Windows 10 Home   Core          x64          10.0.18362 267   0     de-DE (Default)
	2     Windows 10 Home N CoreN         x64          10.0.18362 267   0     de-DE (Default)
	3     Windows 10 Pro    ProfessionalN x64          10.0.18362 1     0     de-DE (Default)
	4     Windows 10 Pro N  Professional  x64          10.0.18362 267   0     de-DE (Default)
	5     Windows 10 Pro    ProfessionalN x64          10.0.18362 1     0     de-DE (Default)
 
Note: As you can see, the Pro versions get messed up. First thought the information could just be messed up.
Installed Index 3 as a Test and it was indeed "Windows 10 Pro N", so Description and Name are false.
In addition there are 5 index, and there should not.

So what i do now: Create the base ISO, and do my stuff.
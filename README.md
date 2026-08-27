matlab-ssh2
===========

This fork uses the operating system `ssh` and `scp` executables
instead of the obsolete Ganymed Java library.  

The legacy `ssh2_*` MATLAB interface is preserved.  Repeated commands use OpenSSH connection
multiplexing (`ControlMaster`/`ControlPersist`). On Windows the default mode
is WSL (`wsl.exe ssh` and `wsl.exe scp`), because native Win32 OpenSSH does
not support client-side ControlMaster. Windows key paths are translated to
`/mnt/<drive>/...` for WSL.

A Matlab interface for using the OpenSSH library. Renamed commands are improved for limitations of existing Matlab/SSH2 codebase (see inspired submissions) using a straightforward command list. 
If you need to access a remote machine from your Matlab session (for near-real time data transfer etc...) this set of functions allows you to send commands and obtain the return values. SFTP and SCP file transfer functions are included. Supports public key authentication and improved multiple command support.

This requires an installation of OpenSSH on your machine. On Windows, using the Linux backend (i.e. WSL) is preferred. 

See ssh2-examples.m for documentation.

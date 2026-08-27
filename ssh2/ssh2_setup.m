function ssh2_struct = ssh2_setup(ssh2_struct)
% SSH2_SETUP   Create configuration structure, SSH2_CONN,
%               for use with ssh2, scp, sftp and supporting functions. 
%               The file must be created, either directly or indirectly,
%               in order to create a ssh connection. 
%
%               SSH2_CONFIG or SSH2_SIMPLE commands will 
%               automatically create this file for you.
%
% SSH2_SETUP([SSH2_CONN])  normally, no inputs are provided.
%
% In addition to creating (or checking) a default SSH2_CONN config to use, 
% this file uses the operating system's OpenSSH client. No Java SSH library
% or MATLAB Java-path setup is required.
% 
% On Windows, WSL OpenSSH is used by default so ControlMaster connection
% multiplexing remains available.
% 
% SCP and SFTP transfers are delegated to the OpenSSH scp executable.
% -----------------------------------------------------------------------
%
%
%   OPTIONAL INPUTS:
%   -----------------------------------------------------------------------
%   SSH2_CONN  when an input is supplied, the SSH2_CONN struct will be 
%              examined to verify all necessary fields are present.
%
%
% SSH2_CONN Fields:
% ------------------------------------------------------------------------
%
%   CONNECTION VALUES
%   .hostname  - network name of the SSH2 host
%   .username  - username to login to host as
%   .password  - password associated with username on remote host
%   .port  - SSH2 remote TCP/IP port, default is 22
%
%   PUBLIC/PRIVATE KEY VALUES
%   .pem_file  - file location of the private key
%   .pem_private_key  - private key as a string
%   .pem_private_key_password  - password for the private key
%
%   REMOTE COMMAND PARAMETERS AND OPTIONS
%   .command  - command line string to issue to remote host
%   .command_session  - session object for the ssh2 command line 
%   .command_ignore_response  - set to 1 to ignore response from host
%   .command_result  - cell array containing the response from the host
%   .command_ignore_stderr - set to 0 to ignore stderr from host
%   .command_err - cell array containing the stderr messages from the host.
%
%   OPENSSH CONNECTION STATE
%   .connection  - OpenSSH control-socket path
%   .ssh2_java_library_loaded  - legacy compatibility flag; always true
%
%   CONNECTION FLAGS AND OPTIONS
%   .authenticated  - flag to determine whether we've authenticated
%   .autoreconnect  - flag to check whether or not to reconnect if disconnected
%   .close_connection  - flag to close connection at the end of ssh2.m
%
%   SCP and SFTP FLAGS
%   .scp  - set to 1 to enable an SCP transfer
%   .sftp  - set to 1 to enable an SFTP transfer
%   .sendfiles  - set to 1 to send a file to the remote host
%   .getfiles  - set to 1 to download a file from the remote host
%
%   FILE AND PATHS, LOCAL AND REMOTE
%   .remote_file  - string or cell array of remote files to up/download
%   .local_target_direcory  - string of path to local files to up/download
%   .local_file  - string or cell array of local files to up/download
%   .remote_target_direcory  - string of path to remote files to up/download
%   .remote_file_new_name  - string or cell array of new names of remote files
%   .remote_file_mode  - Integer specifying new uploaded files permissions, default is 0600
%
%   LEGACY COMPATIBILITY VALUES
%   .ganymed_java_library* - retained for compatibility; not used
%   .openssh_mode  - 'native' or 'wsl' (Windows defaults to 'wsl')
%
%   UNUSED
%   .verified_config  - Unused variable to bypass config check in ssh2.m
%
%         
%   SSH2_SETUP returns the SSH2_CONN for future use.
%
%see also ssh2_config, ssh2_config_publickey, ssh2, ssh2_simple_command
%
% (c)2013 Boston University - ECE
%    David Scott Freedman (dfreedma@bu.edu)
%    Version 4.0


%% SETUP SSH2 CONNECTION STRUCT
% The old Ganymed field names are retained solely for compatibility.

% OpenSSH is always used; no Java library is loaded.  The legacy variable
% name is retained because it is part of the historical configuration struct.
ganymed_java_library = 'openssh';

SSH2path = fileparts(mfilename('fullpath'));
ganymed_java_library_jar = [ganymed_java_library '.jar'];
ganymed_java_library_jar_path = fullfile(SSH2path, ganymed_java_library_jar);
error_message = 0;
if nargin == 0 %SETUP THE DEFAULT CONFIG
    ssh2_struct.SSH2path = SSH2path;
    ssh2_struct.ganymed_java_library = ganymed_java_library;
%     ssh2_struct.ganymed_java_library_zip = ganymed_java_library_zip;
    ssh2_struct.ganymed_java_library_jar = ganymed_java_library_jar;
    ssh2_struct.ganymed_java_library_jar_path = ganymed_java_library_jar_path;
    
    ssh2_struct.hostname = [];
    ssh2_struct.username = [];
    ssh2_struct.password = [];
    ssh2_struct.port = 22;

    ssh2_struct.connection = [];
    ssh2_struct.authenticated = 0;
    ssh2_struct.autoreconnect = 0;
    ssh2_struct.close_connection = 0;
    
    ssh2_struct.pem_file = [];
    ssh2_struct.pem_private_key = [];
    ssh2_struct.pem_private_key_password = [];
    
    ssh2_struct.command = [];
    ssh2_struct.command_session = [];
    ssh2_struct.command_ignore_response = 0;
    ssh2_struct.command_result = [];
    ssh2_struct.command_ignore_stderr = 1;
    ssh2_struct.command_err = [];
    
    
    ssh2_struct.sftp = 0;
    ssh2_struct.scp = 0;
    ssh2_struct.sendfiles = 0;
    ssh2_struct.getfiles = 0;
    
    ssh2_struct.remote_file = [];
    ssh2_struct.local_target_direcory = [];
    ssh2_struct.local_file = [];
    ssh2_struct.remote_target_direcory = [];
    ssh2_struct.remote_file_new_name = [];
    ssh2_struct.remote_file_mode = 0600; %0600 is default
    
    ssh2_struct.verified_config = 0;
    ssh2_struct.ssh2_java_library_loaded = 1; % transport is the OpenSSH executable
    ssh2_struct.openssh_control_path = [];
    if ispc
        ssh2_struct.openssh_mode = 'wsl';
    else
        ssh2_struct.openssh_mode = 'native';
    end
else
    error_message = 1;
    if (isstruct(ssh2_struct))
        if (isfield(ssh2_struct,'SSH2path') && ...
            isfield(ssh2_struct,'ganymed_java_library') && ...
...%             isfield(ssh2_struct,'ganymed_java_library_zip') && ...
            isfield(ssh2_struct,'ganymed_java_library_jar') && ...
            isfield(ssh2_struct,'ganymed_java_library_jar_path') && ...
            isfield(ssh2_struct,'hostname') && ...
            isfield(ssh2_struct,'username') && ...
            isfield(ssh2_struct,'password') && ...
            isfield(ssh2_struct,'port') && ...
            isfield(ssh2_struct,'connection') && ...
            isfield(ssh2_struct,'authenticated') && ...
            isfield(ssh2_struct,'autoreconnect') && ...
            isfield(ssh2_struct,'close_connection') && ...
            isfield(ssh2_struct,'pem_file') && ...
            isfield(ssh2_struct,'pem_private_key') && ...
            isfield(ssh2_struct,'pem_private_key_password') && ...
            isfield(ssh2_struct,'command') && ...
            isfield(ssh2_struct,'command_session') && ...
            isfield(ssh2_struct,'command_ignore_response') && ...
            isfield(ssh2_struct,'command_result') && ...
            isfield(ssh2_struct,'sftp') && ...
            isfield(ssh2_struct,'scp') && ...
            isfield(ssh2_struct,'sendfiles') && ...
            isfield(ssh2_struct,'getfiles') && ...
            isfield(ssh2_struct,'remote_file') && ...
            isfield(ssh2_struct,'local_target_direcory') && ...
            isfield(ssh2_struct,'local_file') && ...
            isfield(ssh2_struct,'remote_target_direcory') && ...
            isfield(ssh2_struct,'remote_file_new_name') && ...
            isfield(ssh2_struct,'remote_file_mode') && ...
            isfield(ssh2_struct,'verified_config') && ...
            isfield(ssh2_struct,'ssh2_java_library_loaded') )
            error_message = 0;
        end
    end
    if (error_message == 1)
        warning('SSH2_SETUP: Invalid input provided!');
        help ssh2_setup
    end        
end

%% OpenSSH is resolved from the operating-system PATH by ssh2_main.m.
% The historical Java-library fields remain in the structure for callers
% that inspect them, but no Java classpath changes are made.
if error_message ~= 0
    ssh2_struct = [];
end

function ssh2_struct = ssh2_main(ssh2_struct)
% SSH2_MAIN  OpenSSH-backed implementation of the legacy ssh2 interface.
% The public ssh2_* API is retained; transport uses the OS ssh/scp tools.

if ~isfield(ssh2_struct,'openssh_control_path') || isempty(ssh2_struct.openssh_control_path)
    if ssh2_use_multiplexing(ssh2_struct)
        ssh2_struct.openssh_control_path = ['/tmp/mslurm-ssh-' ssh2_token() '.sock'];
    else
        ssh2_struct.openssh_control_path = fullfile(tempdir, ...
            sprintf('mslurm-ssh-%s.sock',ssh2_token()));
    end
end

if ssh2_struct.close_connection
    ssh2_close_master(ssh2_struct);
    ssh2_struct.connection = [];
    ssh2_struct.authenticated = 0;
    ssh2_struct.close_connection = 0;
    return
end

if ssh2_struct.scp || ssh2_struct.sftp
    ssh2_struct = ssh2_transfer(ssh2_struct);
elseif ~isempty(ssh2_struct.command)
    [ssh2_struct.command_result,ssh2_struct.command_err,status] = ...
        ssh2_run(ssh2_struct,ssh2_struct.command);
    if status ~= 0 && ssh2_is_transport_error(ssh2_struct.command_err)
        error('SSH2:ConnectionFailed','OpenSSH connection failed: %s', ...
            strjoin(ssh2_struct.command_err,' '));
    end
end

ssh2_struct.command = [];
ssh2_struct.scp = 0;
ssh2_struct.sftp = 0;
ssh2_struct.authenticated = 1;
ssh2_struct.connection = ssh2_struct.openssh_control_path;
ssh2_struct.getfiles = 0;
ssh2_struct.sendfiles = 0;

function [out,err,status] = ssh2_run(s,remote_command)
target = sprintf('%s@%s',char(s.username),char(s.hostname));
if ssh2_use_multiplexing(s)
    ssh = sprintf('%s %s -o ControlMaster=auto -o ControlPersist=600 -o ControlPath=%s %s -- %s', ...
        ssh2_client(s,'ssh'), ...
        ssh2_ssh_options(s),ssh2_local_quote(s.openssh_control_path), ...
        ssh2_local_quote(target),ssh2_remote_quote(remote_command));
else
    % Windows OpenSSH builds do not reliably provide a Unix-domain socket
    % for ControlMaster; use a normal authenticated invocation there.
    ssh = sprintf('%s %s %s -- %s',ssh2_client(s,'ssh'),ssh2_ssh_options(s), ...
        ssh2_local_quote(target),ssh2_remote_quote(remote_command));
end
[status,text] = system(ssh);
[out,err] = ssh2_split_output(text,status);

function s = ssh2_transfer(s)
% A public scp/sftp call may be the first operation, so establish the
% multiplexed master before using its control socket.
if isempty(s.connection)
    [~,~,status] = ssh2_run(s,'true');
    if status ~= 0
        error('SSH2:ConnectionFailed','OpenSSH could not establish a connection.');
    end
end
if s.getfiles
    files = ssh2_cellstr(s.remote_file);
    for k = 1:numel(files)
        source = ssh2_remote_path(files{k},s.remote_target_direcory);
        destination = ssh2_wsl_path(s,char(s.local_target_direcory));
        if ssh2_use_multiplexing(s)
            scp = sprintf('%s %s -o ControlPath=%s %s %s', ...
                ssh2_client(s,'scp'), ...
                ssh2_scp_options(s),ssh2_local_quote(s.openssh_control_path), ...
                ssh2_local_quote(sprintf('%s:%s',sprintf('%s@%s',s.username,s.hostname),source)), ...
                ssh2_local_quote(destination));
        else
            scp = sprintf('%s %s %s %s',ssh2_client(s,'scp'),ssh2_scp_options(s), ...
                ssh2_local_quote(sprintf('%s:%s',sprintf('%s@%s',s.username,s.hostname),source)), ...
                ssh2_local_quote(destination));
        end
        [status,text] = system(scp);
        if status ~= 0
            error('SSH2:SCPFailed','OpenSSH scp download failed (status %d): %s\n%s',status,scp,text);
        end
    end
end
if s.sendfiles
    files = ssh2_cellstr(s.local_file);
    names = ssh2_cellstr(s.remote_file_new_name);
    for k = 1:numel(files)
        local = ssh2_wsl_path(s,ssh2_local_path(files{k},s.local_target_direcory));
        if isempty(names), name = ''; else, name = names{min(k,numel(names))}; end
        remote = ssh2_remote_path(name_or_basename(name,local),s.remote_target_direcory);
        if ssh2_use_multiplexing(s)
            scp = sprintf('%s %s -o ControlPath=%s %s %s', ...
                ssh2_client(s,'scp'), ...
                ssh2_scp_options(s),ssh2_local_quote(s.openssh_control_path), ...
                ssh2_local_quote(local), ...
                ssh2_local_quote(sprintf('%s@%s:%s',s.username,s.hostname,remote)));
        else
            scp = sprintf('%s %s %s %s',ssh2_client(s,'scp'),ssh2_scp_options(s), ...
                ssh2_local_quote(local), ...
                ssh2_local_quote(sprintf('%s@%s:%s',s.username,s.hostname,remote)));
        end
        [status,text] = system(scp);
        if status ~= 0
            error('SSH2:SCPFailed','OpenSSH scp upload failed (status %d): %s\n%s',status,scp,text);
        end
    end
end
s.remote_file = [];
s.local_file = [];
s.remote_file_new_name = [];

function options = ssh2_ssh_options(s)
options = sprintf('-p %d -o ConnectTimeout=30',s.port);
if ~isempty(s.pem_file)
    options = sprintf('%s -i %s',options,ssh2_local_quote(ssh2_key_path(s)));
end

function options = ssh2_scp_options(s)
options = sprintf('-P %d -o ConnectTimeout=30',s.port);
if ~isempty(s.pem_file)
    options = sprintf('%s -i %s',options,ssh2_local_quote(ssh2_key_path(s)));
end

function ssh2_close_master(s)
if ssh2_use_multiplexing(s) && isfield(s,'openssh_control_path') && ~isempty(s.openssh_control_path) && ...
        ~isempty(s.connection)
    target = sprintf('%s@%s',char(s.username),char(s.hostname));
    system(sprintf('%s %s -S %s -O exit %s',ssh2_client(s,'ssh'),ssh2_ssh_options(s), ...
        ssh2_local_quote(s.openssh_control_path),ssh2_local_quote(target)));
end

function [out,err] = ssh2_split_output(text,status)
if isempty(text)
    out = {''};
else
    out = regexp(text,'\r?\n','split');
    if ~isempty(out) && isempty(out{end}), out(end) = []; end
    if isempty(out), out = {''}; end
end
if status == 0, err = {''}; else, err = out; end

function q = ssh2_local_quote(value)
value = char(value);
if ispc
    q = ['"' strrep(value,'"','\"') '"'];
else
    quote = char(39);
    q = [quote strrep(value,quote,[quote '\' quote quote]) quote];
end

function q = ssh2_remote_quote(value)
if ispc
    q = ssh2_local_quote(value);
    return
end
quote = char(39);
q = [quote strrep(char(value),quote,[quote '\' quote quote]) quote];

function value = ssh2_remote_path(file,path)
if isempty(path), value = char(file); else, value = fullfile(char(path),char(file)); end
value = strrep(value,'\','/');

function value = ssh2_local_path(file,path)
if isempty(path), value = char(file); else, value = fullfile(char(path),char(file)); end

function value = name_or_basename(name,local)
if isempty(name), [~,value,ext] = fileparts(local); value = [value ext]; else, value = char(name); end

function values = ssh2_cellstr(value)
if isempty(value), values = {}; elseif iscell(value), values = value; else, values = {value}; end
values = cellfun(@char,values,'UniformOutput',false);

function token = ssh2_token()
token = regexprep(tempname,'[^A-Za-z0-9]','');

function tf = ssh2_use_multiplexing(s)
% Native Win32 OpenSSH lacks ControlMaster. WSL runs Unix OpenSSH.
tf = ~ispc || (isfield(s,'openssh_mode') && strcmpi(s.openssh_mode,'wsl'));

function client = ssh2_client(s,tool)
if isfield(s,'openssh_mode') && strcmpi(s.openssh_mode,'wsl')
    client = ['wsl.exe ' tool];
else
    client = tool;
end

function path = ssh2_key_path(s)
path = char(s.pem_file);
if isfield(s,'openssh_mode') && strcmpi(s.openssh_mode,'wsl')
    match = regexp(path,'^([A-Za-z]):[\\/](.*)$','tokens','once');
    if ~isempty(match)
        path = ['/mnt/' lower(match{1}) '/' strrep(match{2},'\','/')];
    end
end

function path = ssh2_wsl_path(s,path)
path = char(path);
if isfield(s,'openssh_mode') && strcmpi(s.openssh_mode,'wsl')
    match = regexp(path,'^([A-Za-z]):[\\/](.*)$','tokens','once');
    if ~isempty(match)
        path = ['/mnt/' lower(match{1}) '/' strrep(match{2},'\','/')];
    end
end

function tf = ssh2_is_transport_error(err)
if isempty(err) || isempty(err{1})
    tf = false;
    return
end
text = strjoin(err,' ');
tf = ~isempty(regexpi(text, ...
    'getsockname failed|connection refused|connection timed out|could not resolve hostname|connection closed|host key verification failed|permission denied|no route to host|could not connect|broken pipe','once'));

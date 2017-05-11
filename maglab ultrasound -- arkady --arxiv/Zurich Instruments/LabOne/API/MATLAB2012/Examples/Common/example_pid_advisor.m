function result = example_pid_advisor(device_id, varargin)
% EXAMPLE_PID_ADVISOR Setup a PID for internal PLL mode
%
% USAGE SAMPLE = EXAMPLE_PID_ADVISOR(DEVICE_ID)
%
% Setup the PID for the internal PLL mode on the device specified by
% DEVICE_ID. DEVICE_ID should be a string, e.g. 'dev2006' or 'uhf-dev2006'.
%
% NOTE This example can only be ran on MF or UHF Instruments with the PID
% option enabled.
%
% NOTE Additional configuration: Connect signal output 1 to signal input 1
% with a BNC cable.
%
% NOTE Please ensure that the ziDAQ folders 'Driver' and 'Utils' are in your
% Matlab path. To do this (temporarily) for one Matlab session please navigate
% to the ziDAQ base folder containing the 'Driver', 'Examples' and 'Utils'
% subfolders and run the Matlab function ziAddPath().
% >>> ziAddPath;
%
% Use either of the commands:
% >>> help ziDAQ
% >>> doc ziDAQ
% in the Matlab command window to obtain help on all available ziDAQ commands.
%
% Copyright 2008-2016 Zurich Instruments AG

clear ziDAQ;

if ~exist('device_id', 'var')
  error(['No value for device_id specified. The first argument to the ' ...
    'example should be the device ID on which to run the example, ' ...
    'e.g. ''dev2006'' or ''uhf-dev2006''.'])
end

% Check the ziDAQ MEX (DLL) and Utility functions can be found in Matlab's path.
if ~(exist('ziDAQ') == 3) && ~(exist('ziCreateAPISession', 'file') == 2)
  fprintf('Failed to either find the ziDAQ mex file or ziDevices() utility.\n')
  fprintf('Please configure your path using the ziDAQ function ziAddPath().\n')
  fprintf('This can be found in the API subfolder of your LabOne installation.\n');
  fprintf('On Windows this is typically:\n');
  fprintf('C:\\Program Files\\Zurich Instruments\\LabOne\\API\\MATLAB2012\\\n');
  return
end

% The API level supported by this example.
apilevel_example = 5;
% Create an API session; connect to the correct Data Server for the device.
required_err_msg = ['This example only runs with MF or UHF Instruments with ' ...
                    'the PID Option enabled.'];
[device, props] = ziCreateAPISession(device_id, apilevel_example, ...
                                     'required_devtype', 'UHFLI|(MF.*)', ...
                                     'required_options', {'PID'}, ...
                                     'required_err_msg', required_err_msg);

%% Define some sensible parameters based on the device type.
if strfind(props.devicetype, 'MF')
% The target bandwidth [Hz].
  pid_center_frequency = 450e3;
  default_target_bw = 10e3;
  pid_limits = 100e3; % [Hz]
elseif strfind(props.devicetype, 'UHF')
  pid_center_frequency = 10.0e6;
  default_target_bw = 100e3;
  pid_limits = 1e6; % [Hz]
else
  error(['Unexpected device type `' props.devicetype '`.']);
end

%% Define parameters relevant to this example. Default values specified by the
% inputParser below are overwritten if specified as name-value pairs via the
% `varargin` input argument.
p = inputParser;
isnonnegscalar = @(x) isnumeric(x) && isscalar(x) && (x > 0);
p.addParamValue('target_bw', default_target_bw, isnonnegscalar);
p.parse(varargin{:});

%% Create a base configuration: disable all outputs, demods and scopes.
ziDAQ('setInt', ['/' device '/demods/*/enable'], 0);
ziDAQ('setInt', ['/' device '/demods/*/trigger'], 0);
ziDAQ('setInt', ['/' device '/sigouts/*/enables/*'], 0);
ziDAQ('setInt', ['/' device '/scopes/*/enable'], 0);
if any(cellfun(@(x) ~isempty(x), strfind(props.options, 'IA')))
  ziDAQ('setInt', ['/' device '/imps/*/enable'], 0);
end
ziDAQ('sync');

%% Setup of PID
% Select phase as PID input for the internal PLL mode
ziDAQ('setInt', ['/' device '/pids/0/input'], 3)
ziDAQ('setInt', ['/' device '/pids/0/inputchannel'], 3)
% Set the phase setpoint to 0deg for the internal PLL mode
ziDAQ('setDouble', ['/' device '/pids/0/setpoint'], 0)
% Enable phase unwrap mode for internal PLL mode
ziDAQ('setInt', ['/' device '/pids/0/phaseunwrap'], 1)
% Select oscillator as output of the PID for the internal PLL mode
ziDAQ('setInt', ['/' device '/pids/0/output'], 2)
ziDAQ('setInt', ['/' device '/pids/0/outputchannel'], 0)
% Set the center frequency and limits
ziDAQ('setDouble', ['/' device '/pids/0/center'],  pid_center_frequency)
ziDAQ('setDouble', ['/' device '/pids/0/limitlower'], -pid_limits)
ziDAQ('setDouble', ['/' device '/pids/0/limitupper'],  pid_limits)

% Start of the PID advisor module
advisor = ziDAQ('pidAdvisor');

%% Setup of PID advisor
% Turn off auto-calc on param change. Enabled
% auto calculation can be used to automatically
% update response data based on user input.
ziDAQ('set', advisor, 'pidAdvisor/auto', 0);
ziDAQ('set', advisor, 'pidAdvisor/device', device)
ziDAQ('set', advisor, 'pidAdvisor/pid/targetbw', p.Results.target_bw)
% PID advising mode (bit coded)
% bit 0: optimize/tune P
% bit 1: optimize/tune I
% bit 2: optimize/tune D
% Example: mode = 3: Only optimize/tune PI
ziDAQ('set', advisor, 'pidAdvisor/pid/mode', 7)
% PID index to use (first PID of device: 0)
ziDAQ('set', advisor, 'pidAdvisor/index', 0);
% DUT model
% source = 1: Lowpass first order
% source = 2: Lowpass second order
% source = 3: Resonator frequency
% source = 4: Internal PLL
% source = 5: VCO
% source = 6: Resonator amplitude
ziDAQ('set', advisor, 'pidAdvisor/dut/source', 4)
% IO Delay of the feedback system describing the earliest response
% for a step change. This parameter does not affect the shape of
% the DUT transfer function
ziDAQ('set', advisor, 'pidAdvisor/dut/delay', 0.0)
% Start values for the PID optimization. Zero
% values will initate a guess. Other values can be
% used as hints for the optimization process.
% Following parameters are not required for the internal PLL model
% ziDAQ('set', advisor, 'pidAdvisor/dut/gain', 1)
% ziDAQ('set', advisor, 'pidAdvisor/dut/bw', 1000)
% ziDAQ('set', advisor, 'pidAdvisor/dut/fcenter', 15e6)
% ziDAQ('set', advisor, 'pidAdvisor/dut/damping', 0.1)
% ziDAQ('set', advisor, 'pidAdvisor/dut/q', 10e3)
ziDAQ('set', advisor, 'pidAdvisor/pid/p', 0);
ziDAQ('set', advisor, 'pidAdvisor/pid/i', 0);
ziDAQ('set', advisor, 'pidAdvisor/pid/d', 0);
ziDAQ('set', advisor, 'pidAdvisor/calculate', 0)

% Start the module thread
ziDAQ('execute', advisor);

%% Advise
fprintf('Starting advising. Optimization process may run up to a minute...\n');
ziDAQ('set', advisor, 'pidAdvisor/calculate', 1)

timeout = 60; % [s]
reply.calculate = 1;
tic;
while reply.calculate ~= 0
  reply = ziDAQ('get', advisor, 'pidAdvisor/calculate');
  pause(0.5)
  if toc > timeout
    ziDAQ('finish', advisor);
    error('PID advising failed due to timeout.')
  end
end
ziDAQ('set', advisor, 'pidAdvisor/calculate', 1);
fprintf('Advice took %0.1fs\n', toc);

%% Get all calculated parameters
result = ziDAQ('get', advisor, 'pidAdvisor/*');

if ~isempty(result)
  %% Transfer PID coefficients to the PID
  % Now copy the values from the PID advisor to the PID
  ziDAQ('setDouble', ['/' device '/pids/0/p'], result.pid.p)
  ziDAQ('setDouble', ['/' device '/pids/0/i'], result.pid.i)
  ziDAQ('setDouble', ['/' device '/pids/0/d'], result.pid.d)
  ziDAQ('setDouble', ['/' device '/pids/0/dlimittimeconstant'], result.pid.dlimittimeconstant)
  ziDAQ('setDouble', ['/' device '/pids/0/rate'],  result.pid.rate)

  %% Plot calculated PID response
  complexData = result.bode.x + 1i * result.bode.y;
  subplot(3, 1, 1)
  h = semilogx(result.bode.grid, 20 * log10(abs(complexData)));
  set(h, 'Color', 'black')
  set(h, 'LineWidth', 1.5)
  box on
  grid on
  xlabel('Frequency [Hz]')
  ylabel('Bode Gain [dB]')
  title(sprintf('Calculated model response for internal PLL with P = %0.0f, I = %0.0f, D = %0.5f and bandwidth %0.0fkHz\n', result.pid.p, result.pid.i, result.pid.d, result.bw * 1e-3))
  subplot(3, 1, 2)
  h = semilogx(result.bode.grid, angle(complexData) / pi * 180);
  set(h, 'Color', 'black')
  set(h, 'LineWidth', 1.5)
  box on
  grid on
  xlabel('Frequency [Hz]')
  ylabel('Bode Phase [deg]')
  subplot(3, 1, 3)
  h = plot(result.step.grid * 1e6, result.step.x);
  set(h, 'Color', 'black')
  set(h, 'LineWidth', 1.5)
  box on
  grid on
  xlabel('Time [us]')
  ylabel('Step Response')
end

end

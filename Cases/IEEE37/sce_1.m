% Source Vertex
sVer = 1;

% Feeder vertices
fVer = 1;

% Microgrid infomation
numMG = 0;
mVer = [];

% Limits
voltage_limit = 4.8*[0.95, 1.05]; % lower and upper limits of load voltages
feeder_power_limit = Inf; % upper limits of feeder powers
thermal_limit = [ % thermal limits of lines
    1856570
    512635
    792506
    1856570
    512635
    792506
    512635
    792506
    512635
    512635
    512635
    512635
    512635
    792506
    512635
    792506
    792506
    512635
    512635
    792506
    512635
    792506
    512635
    512635
    792506
    792506
    792506
    792506
    792506
    512635
    792506
    792506
    512635
    512635
    ]; 
microgrid_limit = []; % upper limits of active and reactive powers of microgrid
%% ***************************************
% Authors: Prof. Yin Xu
% Ref [1]: J. Li, X. Y. Ma, C. C. Liu, and K. P. Schneider, “Distribution system restoration with microgrids using spanning tree search,” IEEE Transactions on Power Systems, vol. 29, no. 6, pp. 3021–3029, Nov. 2014.
% Created Date: 2014
% Updated Date: 2014-4-15
% Emails: xuyin@bjtu.edu.cn
%  ***************************************

clc
clear all
close all

format short g

addpath ('Classes')

%% Cases Information

% % Case 1: 4 feeder, 1069 node system, without microgrid

% % Case 2: 4 feeder, 1069 node system, with microgrid

% Case 3: IEEE 37 Node Test Feeder
caseName = 'IEEE37';
fileName = 'IEEE_37node';
scenarioName = 'sce_1';
fsec = [1,1];

% % Case 4: Pullman-WSU Distribution System

%% get sectionalizing switch list
% read case information
a = Restoration(caseName,fileName,scenarioName,fsec);
% get the list of sectionalizing switches, as candinate fault loacations
sec_list = a.sec_swi;

% %% Set number of matlab workers (parallel processes)
% myCluster = parcluster('local');
% myCluster.NumWorkers = 8;
% saveProfile(myCluster);
% % Open Matlabpool for parallel computing
% matlabpool open

%% Restoration
for sec_idx = 1:size(sec_list,1)
% parfor sec_idx = 1:size(sec_list,1)
    % set fault section
    fsec = sec_list(sec_idx,:);
    % renew fault location
    a.renewFaultLocation(fsec);
    % restoration using spanning tree
    IdxSW = a.spanningTreeSearch();
    % save result to file
    a.printResult(IdxSW);
end

% %% Close Matlabpool
% matlabpool close

%% Remove Temporary Files
all_dir_file = dir(['.\Cases\',caseName,'\results\']);
all_dir_name = {all_dir_file([all_dir_file.isdir]).name};
rm_dir_name = all_dir_name(3:end);
for idx = 1:size(rm_dir_name,2)
    rmdir(['.\Cases\',caseName,'\results\',rm_dir_name{idx}],'s');
end

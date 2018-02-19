clear all
clc

%% get all file names
fileNames = dir('results\*.txt');
num_scenarios = size(fileNames,1);

%% read file one by one
all_result = cell(num_scenarios,4);
%% open file
for idx = 1:num_scenarios
    filename = ['results\', fileNames(idx).name];
    file = fopen(filename,'r');
    %% read data
    % Line 1, case information
    fgets(file);
    % Line 2, get fault location
    line = fgets(file);
    ptr1 = strfind(line,',');
    tempPtr = strfind(line,'(');
    ptr2 = tempPtr(2);
    fault_loc = line(ptr1+1:ptr2-1);
    fault_loc = fault_loc(~isspace(fault_loc));
    % get restoration infomation: full/partial/no restoration
    % res_state = 1: full restoration, 2: partical restoration, 3: no resotration
    swi_to_open = [];
    swi_to_close = [];
    line = fgets(file); % Line 3
    if strfind(line,'Full restoration is successful.')
        res_state = 1;
        fgets(file);% Line 4
        counter = 0;
        while ~feof(file)
            line = fgets(file); % Line 5, 6, ...
            counter = counter + 1;
            ptr1 = strfind(line,',');
            tempPtr = strfind(line,'(');
            ptr2 = tempPtr(2);
            curSwi = line(ptr1+1:ptr2-1);
            curSwi = curSwi(~isspace(curSwi));
            if strfind(line,'Open')
                if counter == 1
                    continue;
                end
                if isempty(swi_to_open)
                    swi_to_open = curSwi;
                else
                    swi_to_open = [swi_to_open, ',', curSwi];
                end
            else
                if isempty(swi_to_close)
                    swi_to_close = curSwi;
                else
                    swi_to_close = [swi_to_close, ',', curSwi];
                end
            end
        end
    elseif strfind(line,'Partial restoration is performed.')
        res_state = 2;
        fgets(file);% Line 4
        fgets(file);% Line 5
        counter = 0;
        while ~feof(file)
            line = fgets(file); % Line 6, 7, ...
            counter = counter + 1;
            ptr1 = strfind(line,',');
            tempPtr = strfind(line,'(');
            ptr2 = tempPtr(2);
            curSwi = line(ptr1+1:ptr2-1);
            curSwi = curSwi(~isspace(curSwi));
            if strfind(line,'Open')
                if counter == 1
                    continue;
                end
                if isempty(swi_to_open)
                    swi_to_open = curSwi;
                else
                    swi_to_open = [swi_to_open, ',', curSwi];
                end
            else
                if isempty(swi_to_close)
                    swi_to_close = curSwi;
                else
                    swi_to_close = [swi_to_close, ',', curSwi];
                end
            end
        end
    else
        res_state = 3;
    end
    fclose(file);
    all_result(idx,:) = {fault_loc,res_state,swi_to_open,swi_to_close};
end

cell2csv('results.txt',all_result,'     ');
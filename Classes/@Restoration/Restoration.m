classdef Restoration < handle
    %RESTORATION is a class used to realize distribution power system
    %restoration based on the spanning tree algorithm
    
    properties
        % Case information
        caseName; % Must be the same as the folder name for the case
        fileName; % Name of .glm file, without the suffix.
        scenarioName; % Name of .m file, without the suffix. Data for the 
                      % scenario simulated is in this file
        glmFile; % A string used to store the content of the orinal glm file.
        % Microgrid Information
        numMG; % The number of microgrids
        MGIdx; % Index of vertices connected to microgrids
        MGIdx_1;
        MGIdx_2;
        % Nodes
        node_name; % A vector that records the names of all nodes (buses)
        node_nickName; % some nodes may have parents (correspond to meters)
        % Load
        node_load_info;
        node_load_info_1;
        % Topologies
        top_ori; % Original topology of the power system,represented by a tree.
        top_sim_1; % The topology after 1st simplification, all non-switch
                   % edges are deleted.
        top_sim_2; % The topology after 2nd simplification, vertices whose degree
                   % equals to 1 or 2 are deleted.
        top_res; % The topology after restoration, represented by a tree.
        top_tmp;
        % the feeder vertices
        feederVertices; % The ID of the start vertices of feeders in the graph 
                        % after the 2nd simplification
        feederVertices_1;            
        feederVertices_2;
        % Switches
        tie_swi; % A set of tie switches (normally open), n*2 matrix.
        tie_swi_1; % Tie switches after the 1st simplification, n*2 matrix.
        tie_swi_2; % Tie switches after the 2st simplification, n*2 matrix.
        sec_swi_name;
        sec_swi; % A set of sectionalizing switches (normally closed), n*2 matrix.
        sec_swi_1; % sectionalizing switches after the 1st simplification, n*2 matrix.
        sec_swi_2; % sectionalizing switches after the 1st simplification, n*2 matrix.
        sec_swi_map;
        sec_swi_map_1;
        tie_swi_name;
        tie_swi_loc; % The location of tie switches status in origal glm file.
        sec_swi_loc; % The location of sectionalizing switches status in origal glm file.
        % Special nodes and edges
        f_sec; % faulted section, 1*2 vector.
        f_sec_1; % Faulted section after 1st simplification
        f_sec_2; % Faulted section after 1st simplification
        s_ver; % The source vertex.
        s_ver_1; % The source vertex after 1st simplification
        s_ver_2; % The source vertex after 1st simplification
        % Mappings
        ver_map_1; % A map between the vertices of the original tree and those
                   % of the 1st simplified tree, 1*n vector. Here n is the number
                   % of the vertices of the original tree.
        ver_map_2; % A map between the vertices of the 1st simplified tree and those
                   % of the 2nd simplified tree, 1*n vector. Here n is the number
                   % of the vertices of the 1st simplified tree.
        % Limits for power flow
        voltage_limit; % The lower limit of load voltages (V)
        feeder_power_limit; % The upper limit of feeder power (VA)
        thermal_limit; % thermal limits of lines
        microgrid_limit; % The upper limits of active and reactive power of microgrids
        % Results
        candidateSwOpe % Candidate switching operations
                       % Each line corresponds to a cyclic interchange operation
                       % It has 7 columns: column 1-2 represent the switch
                       % need to be opened; column 3-4 represent the switch
                       % need to be closed; column 5 refers to the previous
                       % cyclic interchange operation; column 6 is the
                       % amount of loads can not be restored; column 7 is
                       % the feeder overloaded.
        candidateSwOpe_1; % Candidate switching operations on top_sim_1
        candidateSwOpe_2; % Candidate switching operations on top_sim_2
        % swi_seq; % The switching sequence for restoration.
    end 
    
    methods
        % Constructor
        function resObj = Restoration(caseName, fileName, scenarioName, fsec)
            % Case Info
            resObj.caseName = caseName;
            resObj.fileName = fileName;
            resObj.scenarioName = scenarioName;
            
            % case inforamtion
%             resObj.readGlmFile(caseName, fileName);
            resObj.readGlmFile_2(caseName, fileName);
            
            % Scenario information
            scenarioFile = ['.\cases\',caseName,'\',scenarioName,'.m'];
            run(scenarioFile);
            
            % Information for microgrids
            resObj.numMG = numMG;
            resObj.MGIdx = mVer;
            
            % Set Constraints
            resObj.voltage_limit = voltage_limit; 
            resObj.feeder_power_limit = feeder_power_limit;
            resObj.thermal_limit = thermal_limit;
            resObj.microgrid_limit = microgrid_limit;
           
            % set source vertex (slack bus)
            resObj.setSVer(sVer);
           
            % Set fault section
            resObj.setFEdge(fsec);
            
            %************************************************
            % Pullman-WSU system, 2014-3-30
            if strcmp(caseName,'Pullman_WSU')==1
                % delete chords to open loops
                resObj.top_ori.deleteEdge(158,714);
                resObj.top_ori.deleteEdge(160,714);
                resObj.top_ori.deleteEdge(659,1107);
                resObj.top_ori.deleteEdge(659,1108);
                resObj.top_ori.deleteEdge(754,1645);
                resObj.top_ori.deleteEdge(757,1648);
                % remove tie switches in substation
                resObj.tie_swi = resObj.tie_swi([7,9:end],:);
                resObj.tie_swi_name = resObj.tie_swi_name([7,9:end],:);
                resObj.tie_swi_loc = resObj.tie_swi_loc([7,9:end],:);
                % remove sectionalizing switches in the upstream of transformers
                resObj.sec_swi = resObj.sec_swi(5:end,:);
                resObj.sec_swi_name = resObj.sec_swi_name(5:end,:);
                resObj.sec_swi_loc = resObj.sec_swi_loc(5:end,:);
            end
            %************************************************
            
            % topology simplification
            resObj.feederVertices = fVer;
            resObj.simplifyTop_1();% 1st simplification
            resObj.feederVertices_1 = resObj.ver_map_1(resObj.feederVertices);
            resObj.loadInfo();% load in the 1st simplified topology
            
            % 2nd simplification
            resObj.simplifyTop_2();
            
            % Feeder vertices
            resObj.setFeederVertices_2();
            
            % Microgrid vertices
            resObj.setMicrogridVertices();
            
            % modify lists of sectionalizing switches
            resObj.modifySecSwiList();
            %************************************************
            % Pullman-WSU system, 2014-3-30
            if strcmp(caseName,'Pullman_WSU')==1
                resObj.sec_swi = resObj.sec_swi(3:end,:);
                resObj.sec_swi_name = resObj.sec_swi_name(3:end,:);
                resObj.sec_swi_loc = resObj.sec_swi_loc(3:end,:);
            end
            %************************************************
            resObj.formSecSwiMap();
                        
            % Graph after restoration
            resObj.top_res = LinkedUndigraph();
            %
            resObj.top_tmp = LinkedUndigraph();
            resObj.top_tmp.copy(resObj.top_sim_1);
        end
        
        %
        function renewFaultLocation(resObj, faultSection)
            % Set fault section
            resObj.setFEdge(faultSection);
            % Faulted section
            resObj.f_sec_1(1) = resObj.ver_map_1(resObj.f_sec(1));
            resObj.f_sec_1(2) = resObj.ver_map_1(resObj.f_sec(2));
            
            % 2nd simplification
            resObj.simplifyTop_2();
            
            % Feeder vertices
            resObj.setFeederVertices_2();
            
            % Microgrid vertices
            resObj.setMicrogridVertices();
            
            % modify lists of sectionalizing switches
            resObj.modifySecSwiList();
            resObj.formSecSwiMap();
            
            % Graph after restoration
            resObj.top_res = LinkedUndigraph();
            %
            resObj.top_tmp = LinkedUndigraph();
            resObj.top_tmp.copy(resObj.top_sim_1);
        end
        
        %% Read GridLAB-D Model and Generate the Original Topology
        
        % Read data from .glm file
        % Inputs: caseName, must be the same as the folder name for the case
        % fileName, without the suffix.
        function readGlmFile(resObj, caseName, fileName)
            % Get node information
            resObj.readNodes(caseName, fileName);
            % Get edge information
            resObj.readEdges(caseName, fileName);
            % Get switch information
            resObj.readSwitches(caseName, fileName);
            % Get load information
            resObj.readLoad(caseName, fileName);
        end
        
        % Read node(bus) information
        function readNodes(resObj, caseName, fileName)
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName,'.glm']);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            % Count the number of nodes and record the names of nodes
            tline = fgetl(inFile); % Read a line
            num_of_nodes = 0; % number of nodes
            while ischar(tline)
                if strfind(tline,'object node')
                    num_of_nodes = num_of_nodes + 1;
                    name = [];
                    nickName = [];
                    tline = fgetl(inFile);
                    while isempty(strfind(tline,'}'))
                        if strfind(tline,'name')
                            [~, remain] = strtok(tline); % delete 'name'
                            name = strtok(remain,' ;'); % delete ';' and spaces
                            resObj.node_name = [resObj.node_name; cellstr(name)];
                        elseif strfind(tline,'parent')
                            [~, remain] = strtok(tline); % delete 'parent'
                            nickName = strtok(remain,' ;'); % delete ';' and spaces
                            resObj.node_nickName = [resObj.node_nickName; cellstr(nickName)];
                        end
                        tline = fgetl(inFile);
                    end
                    if ~isempty(name) && isempty(nickName)
                        resObj.node_nickName = [resObj.node_nickName; cellstr('_NULL_')];
                    end
                end
                tline = fgetl(inFile);
            end
            % Close file
            fclose(inFile);
            % Great a graph object for the original network
            resObj.top_ori = LinkedUndigraph(num_of_nodes);
        end
        
        % Read edge(power component) information
        function readEdges(resObj, caseName, fileName)
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName,'.glm']);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            % Add edges into the original graph
            tline = fgetl(inFile); % Read a line
            while ischar(tline)
                if strfind(tline,'object')
                    edgeInfo = [];
                    while ischar(tline)
                        edgeInfo = [edgeInfo, ' ', tline];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(inFile);
                    end
                    [fromIdx, toIdx] = resObj.readAnEdge(edgeInfo);
                    if ~isempty(fromIdx) && ~isempty(toIdx)
                        resObj.top_ori.addEdge(fromIdx, toIdx);
                    end
                end
                tline = fgetl(inFile);
            end
            % Close file
            fclose(inFile);
        end
        
        % Read switch information
        function readSwitches(resObj, caseName, fileName)
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName,'.glm']);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            % Initialization
            resObj.sec_swi = [];
            resObj.tie_swi = [];
            % Read information for 'recloser' and 'switch'
            tline = fgetl(inFile); % Read a line
            while ischar(tline)
                if ~isempty(strfind(tline,'object')) && ...
                        ( ~isempty(strfind(tline,'recloser')) || ~isempty(strfind(tline,'switch')) )
                    edgeInfo = [];
                    while ischar(tline)
                        edgeInfo = [edgeInfo, ' ', tline];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(inFile);
                    end
                    [fromIdx, toIdx, type] = resObj.readAnEdge(edgeInfo);
                    if strcmp(type, 'recloser') % Suppose reclosers are all closed
                        if ~isempty(fromIdx) && ~isempty(toIdx)
                            resObj.sec_swi = [resObj.sec_swi; [fromIdx, toIdx]];
                        end
                    elseif strcmp(type, 'switch')
                        idx = strfind(edgeInfo,' status ');
                        [~, remain] = strtok(edgeInfo(idx:end));
                        status = strtok(remain,' ;'); % delete ';' and spaces
                        if strcmp(status, 'CLOSED')
                            resObj.sec_swi = [resObj.sec_swi; [fromIdx, toIdx]];
                        elseif strcmp(status, 'OPEN')
                            resObj.tie_swi = [resObj.tie_swi; [fromIdx, toIdx]];
                            % delete tie switches from the original graph
                            resObj.top_ori.deleteEdge(fromIdx, toIdx);
                        end
                    end
                end
                tline = fgetl(inFile);
            end
            % Close file
            fclose(inFile);
        end
        
        % Read load information
        function readLoad(resObj, caseName, fileName)
            % Initialization
            load_matrix = [];
            tran_matrix = [];
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName,'.glm']);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            %
            tline = fgetl(inFile); % Read a line
            while ischar(tline)
                if strfind(tline,'object load')
                    % Get information of 1 load
                    loadInfo = [];
                    while ischar(tline)
                        loadInfo = [loadInfo, ' ', tline];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(inFile);
                    end
                    % Extract the information we need
                    parent = strfind(loadInfo,' parent ');
                    constant_power_A = strfind(loadInfo,' constant_power_A ');
                    constant_power_B = strfind(loadInfo,' constant_power_B ');
                    constant_power_C = strfind(loadInfo,' constant_power_C ');
                    % meter
                    if ~isempty(parent)
                        subString = loadInfo(parent:end);
                        [~, remain] = strtok(subString); % delete 'parent'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        curLoad(1,1) = {token};
                    end
                    % power  - phase A
                    if ~isempty(constant_power_A)
                        subString = loadInfo(constant_power_A:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_A'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2num(token);
                        curLoad(1,2) = {real(PQ)};
                        curLoad(1,3) = {imag(PQ)};
                    else
                        curLoad(1,2) = {0};
                        curLoad(1,3) = {0};
                    end
                    % power  - phase B
                    if ~isempty(constant_power_B)
                        subString = loadInfo(constant_power_B:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_B'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2num(token);
                        curLoad(1,4) = {real(PQ)};
                        curLoad(1,5) = {imag(PQ)};
                    else
                        curLoad(1,4) = {0};
                        curLoad(1,5) = {0};
                    end
                    % power  - phase C
                    if ~isempty(constant_power_C)
                        subString = loadInfo(constant_power_C:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_C'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2num(token);
                        curLoad(1,6) = {real(PQ)};
                        curLoad(1,7) = {imag(PQ)};
                    else
                        curLoad(1,6) = {0};
                        curLoad(1,7) = {0};
                    end
                    %
                    load_matrix = [load_matrix; curLoad];
                elseif strfind(tline,'object transformer')
                    curTran = cell(1,2);
                    % Get defination of 1 transformer
                    tranInfo = [];
                    while ischar(tline)
                        tranInfo = [tranInfo, ' ', tline];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(inFile);
                    end
                    % Extract the information we need
                    from = strfind(tranInfo,' from ');
                    to = strfind(tranInfo,' to ');
                    if ~isempty(from)
                        subString = tranInfo(from:end);
                        [~, remain] = strtok(subString); % delete 'from'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        curTran(1,1) = {token};
                    end
                    if ~isempty(to)
                        subString = tranInfo(to:end);
                        [~, remain] = strtok(subString); % delete 'to'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        curTran(1,2) = {token};
                    end
                    %
                    tran_matrix = [tran_matrix; curTran];
                end
                tline = fgetl(inFile);
            end
            % Close file
            fclose(inFile);
            %
            tran_matrix = reshape(tran_matrix(~cellfun('isempty',tran_matrix)),[],2);
            %
            resObj.node_load_info = zeros(size(load_matrix,1),3);
            for idx = 1:size(resObj.node_load_info,1)
                nName = load_matrix(idx,1);
                nIdx = find(ismember(resObj.node_name,nName),1);
                if isempty(nIdx)
                    row = find(ismember(tran_matrix(:,2),load_matrix(idx,1)),1);
                    nName = tran_matrix(row,1);
                    nIdx = find(ismember(resObj.node_name,nName),1);
                end
                resObj.node_load_info(idx,1) = nIdx;
                P = cell2mat(load_matrix(idx,2)) + cell2mat(load_matrix(idx,4)) ...
                    + cell2mat(load_matrix(idx,6));
                Q = cell2mat(load_matrix(idx,3)) + cell2mat(load_matrix(idx,5)) ...
                    + cell2mat(load_matrix(idx,7));
                resObj.node_load_info(idx,2) = P;
                resObj.node_load_info(idx,3) = Q;
            end           
        end
        
        % get from node, to node and type of an edge
        function [fromIdx, toIdx, type] = readAnEdge(resObj, edgeInfo)
            % get type
            [~, remain] = strtok(edgeInfo); % delete 'object'
            type = strtok(remain,' :'); % delete ':' and spaces
            % get from node and to node
            fromIdx = [];
            toIdx = [];
            from = strfind(edgeInfo,' from ');
            to = strfind(edgeInfo,' to ');
            if ~isempty(from)
                subString = edgeInfo(from:end);
                [~, remain] = strtok(subString); % delete 'from'
                token = strtok(remain,' ;'); % delete ';' and spaces
                fromIdx = find(strcmp(resObj.node_name,token));
                if isempty(fromIdx)
                    fromIdx = find(strcmp(resObj.node_nickName,token));
                end
            end
            if ~isempty(to)
                subString = edgeInfo(to:end);
                [~, remain] = strtok(subString); % delete 'to'
                token = strtok(remain,' ;'); % delete ';' and spaces
                toIdx = find(strcmp(resObj.node_name,token));
                if isempty(toIdx)
                    toIdx = find(strcmp(resObj.node_nickName,token));
                end
            end
        end
        
        %
        function readGlmFile_2(resObj, caseName, fileName)
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName,'.glm']);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            
            % read file
            resObj.glmFile = [];
            tline = fgetl(inFile); % Read a line
            while ischar(tline)
                % Including files
                incFile = strfind(tline, '#include');
                if ~isempty(incFile)
                    loc = strfind(tline, '"');
                    incFileName = tline(loc(1)+1:loc(2)-1);
                    str_incFile = resObj.readIncFile(caseName, incFileName);
                    resObj.glmFile = [resObj.glmFile,str_incFile];
                    tline = fgetl(inFile);
                    continue;
                end
                % Settings
                isSetting = strfind(tline,'#');
                if ~isempty(isSetting) && isSetting(1)==1
                    resObj.glmFile = [resObj.glmFile,tline,'\n']; % Settings remain unchanged
                    tline = fgetl(inFile);
                    continue;
                end
                % Comments
                isComment = strfind(tline,'//');
                if ~isempty(isComment)
                    tline = tline(1:isComment(1)-1); % delete comments
                end
                % Normal contents
                if isempty(tline)
                    tline = fgetl(inFile); % jump over empty lines
                else
                    tline = strtrim(tline);
                    resObj.glmFile = [resObj.glmFile,' ',tline,'\n']; % a blank is added before each line
                    tline = fgetl(inFile);
                end
            end
            
            % Close file
            fclose(inFile);
            
            %
            resObj.readNodes_2();
            resObj.readEdges_2();
            resObj.readSwitches_2();
            resObj.readLoad_2();
        end
        
        %
        function str_incFile = readIncFile(resObj, caseName, fileName)
            % Open file
            inFile = fopen(['.\cases\',caseName,'\',fileName]);
            if inFile == -1
                error('Error: Can not open file !!!');
            end
            
            % read file
            str_incFile = [];
            tline = fgetl(inFile); % Read a line
            while ischar(tline)
                % Settings
                isSetting = strfind(tline,'#');
                if ~isempty(isSetting) && isSetting(1)==1
                    str_incFile = [str_incFile,tline,'\n']; % Settings remain unchanged
                    tline = fgetl(inFile);
                    continue;
                end
                % Comments
                isComment = strfind(tline,'//');
                if ~isempty(isComment)
                    tline = tline(1:isComment(1)-1); % delete comments
                end
                % Normal contents
                if isempty(tline)
                    tline = fgetl(inFile); % jump over empty lines
                else
                    tline = strtrim(tline);
                    str_incFile = [str_incFile,' ',tline,'\n']; % a blank is added before each line
                    tline = fgetl(inFile);
                end
            end
            
            % Close file
            fclose(inFile);
        end
        
        %
        function readNodes_2(resObj)
            % Nodes
            nodePtr = strfind(resObj.glmFile,'object node');
            num_of_nodes = size(nodePtr,2);
            resObj.node_name = cell(num_of_nodes,1);
            resObj.node_nickName = cell(num_of_nodes,1);
            for idx = 1:num_of_nodes
                % get node info
                tline = resObj.glmFile(nodePtr(idx):end);
                endPtr = strfind(tline,'}');
                tline = tline(1:endPtr(1));
                % node names
                namePtr = strfind(tline,'name');
                [~, remain] = strtok(tline(namePtr:end)); % delete 'name'
                name = strtok(remain,' ;'); % delete ';' and spaces
                resObj.node_name(idx) = cellstr(name);
                % some nodes are parented to meters
                parentPtr = strfind(tline,'parent');
                if ~isempty(parentPtr)
                    [~, remain] = strtok(tline(parentPtr:end)); % delete 'parent'
                    nickName = strtok(remain,' ;'); % delete ';' and spaces
                    resObj.node_nickName(idx) = cellstr(nickName);
                else
                    resObj.node_nickName{idx} = '_NULL_';
                end
            end
            
            % Meters            
            meterPtr = strfind(resObj.glmFile,'object meter');
            num_of_meters = size(meterPtr,2);
            for idx = 1:num_of_meters
                % get meter info
                tline = resObj.glmFile(meterPtr(idx):end);
                endPtr = strfind(tline,'}');
                meterInfo = tline(1:endPtr(1));
                % meter name
                namePtr = strfind(meterInfo,'name');
                [~, remain] = strtok(meterInfo(namePtr:end)); % delete 'name'
                meterName = strtok(remain,' ;'); % delete ';' and spaces
                % parent
                parentPtr = strfind(meterInfo,'parent');
                [~, remain] = strtok(meterInfo(parentPtr:end)); % delete 'parent'
                meterParent = strtok(remain,' ;'); % delete ';' and spaces
                % check the meter is independant or a parent of a node
                if ~isempty(meterParent) && ~isempty(find(ismember(resObj.node_name,{meterParent}),1))
                    nodeIdx = find(ismember(resObj.node_name,{meterParent}),1);
                    resObj.node_nickName{nodeIdx} = meterName;
                    continue;
                end              
                isPar = find(ismember(resObj.node_nickName,{meterName}),1);
                if isempty(isPar) % if it is independant, it will be considered as a new node
                    num_of_nodes = num_of_nodes + 1;
                    resObj.node_name = [resObj.node_name; {meterName}];
                    resObj.node_nickName = [resObj.node_nickName; {'_NULL_'}];
                end
            end
            
            % Great a graph object for the original network
            resObj.top_ori = LinkedUndigraph(num_of_nodes);
        end
        
        %
        function readEdges_2(resObj)
            edgePtr = strfind(resObj.glmFile,'object');
            num_of_edges = size(edgePtr,2);
            
            for idx = 1:num_of_edges
                %
                edgeInfo = resObj.glmFile(edgePtr(idx):end);
                endPtr = strfind(edgeInfo,'}');
                edgeInfo = edgeInfo(1:endPtr(1));
                %
                [fromIdx, toIdx] = resObj.readAnEdge(edgeInfo);
                if ~isempty(fromIdx) && ~isempty(toIdx)
                    resObj.top_ori.addEdge(fromIdx, toIdx);
                end
            end
        end
        
        %
        function readSwitches_2(resObj)
            % all switch and recloser locations
            switchPtr = strfind(resObj.glmFile,'object switch');
            recloserPtr = strfind(resObj.glmFile,'object recloser');
            fusePtr = strfind(resObj.glmFile, 'object fuse');
            num_of_swi = size(switchPtr,2);
            num_of_rec = size(recloserPtr,2);
            num_of_fus = size(fusePtr,2);
            % Initialization
            resObj.sec_swi_name = [];
            resObj.tie_swi_name = [];
            resObj.sec_swi = [];
            resObj.tie_swi = [];
            resObj.sec_swi_loc = [];
            resObj.tie_swi_loc = [];
            % Get info for switches
            for idx = 1:num_of_swi
                % info of a switch
                swiInfo = resObj.glmFile(switchPtr(idx):end);
                endPtr = strfind(swiInfo,'}');
                swiInfo = swiInfo(1:endPtr(1));
                [fromIdx, toIdx] = resObj.readAnEdge(swiInfo);
                % Phase info
                phasePtr = strfind(swiInfo,'phases');
                [~, remain] = strtok(swiInfo(phasePtr:end)); % delete 'phases'
                phaseInfo = strtok(remain,' ;');
                % switch name
                namePtr = strfind(swiInfo,'name');
                [~, remain] = strtok(swiInfo(namePtr:end)); % delete 'name'
                swiName = strtok(remain,' ;'); % delete ';' and spaces
                % switch state
                osloc = strfind(swiInfo,'OPEN');
                csloc = strfind(swiInfo,'CLOSED');
                swiState = [];
                if ~isempty(csloc)
                    swiState = 1; % closed
                elseif ~isempty(osloc)
                    swiState = 0; % open
                end
                % **********************************************
                % 2014-4-10, single phase tie switches are ignored.
                if ~( strcmp(phaseInfo,'ABCN')==1 || strcmp(phaseInfo,'ABC')==1 ) && swiState == 0
                    resObj.top_ori.deleteEdge(fromIdx, toIdx);
                    continue;
                end
                % **********************************************
                % record switch info
                if swiState == 1
                    resObj.sec_swi_name = [resObj.sec_swi_name;{swiName}];
                    resObj.sec_swi = [resObj.sec_swi; [fromIdx, toIdx]];
                    resObj.sec_swi_loc = [resObj.sec_swi_loc; [switchPtr(idx)+csloc-1,0,0,0]];
                elseif swiState == 0
                    resObj.tie_swi_name = [resObj.tie_swi_name;{swiName}];
                    resObj.tie_swi = [resObj.tie_swi; [fromIdx, toIdx]];
                    resObj.tie_swi_loc = [resObj.tie_swi_loc; [switchPtr(idx)+osloc-1,0,0,0]];
                    resObj.top_ori.deleteEdge(fromIdx, toIdx); % remove tie switches from the original graph
                end
            end
            % Get info for reclosers
            for idx = 1:num_of_rec
                % info of a recloser
                recInfo = resObj.glmFile(recloserPtr(idx):end);
                endPtr = strfind(recInfo,'}');
                recInfo = recInfo(1:endPtr(1));
                [fromIdx, toIdx] = resObj.readAnEdge(recInfo);
                % Phase info
                phasePtr = strfind(recInfo,'phases');
                [~, remain] = strtok(recInfo(phasePtr:end)); % delete 'phases'
                phaseInfo = strtok(remain,' ;');
                % switch name
                namePtr = strfind(recInfo,'name');
                [~, remain] = strtok(recInfo(namePtr:end)); % delete 'name'
                swiName = strtok(remain,' ;'); % delete ';' and spaces
                % state of recloser: assume all recloser is closed
                csloc = strfind(recInfo,'CLOSED');
                resObj.sec_swi_loc = [resObj.sec_swi_loc; recloserPtr(idx)+csloc-1];
                % add to sectionalizing switch list
                if ~isempty(fromIdx) && ~isempty(toIdx)
                    resObj.sec_swi_name = [resObj.sec_swi_name;{swiName}];
                    resObj.sec_swi = [resObj.sec_swi; [fromIdx, toIdx]];
                end
            end
            % Get info for fuses
            for idx = 1:num_of_fus
                % info of a fuse
                fusInfo = resObj.glmFile(fusePtr(idx):end);
                endPtr = strfind(fusInfo,'}');
                fusInfo = fusInfo(1:endPtr(1));
                [fromIdx, toIdx] = resObj.readAnEdge(fusInfo);
                
                % *****************************************
                % for Pullman-WSU system, 2014-4-10, remove two fuses which can cause loop
                if strcmp(resObj.caseName,'Pullman_WSU')==1
                    if fromIdx==1645 && toIdx==754 ... % CombinedPullman-411-908053-0_fuse
                            || fromIdx==1648 && toIdx==757 % CombinedPullman-411-1068072-0_fuse
                        continue;
                    end
                end
                % *****************************************
                
                % *****************************************
                % 2014-4-10 Closed fuses are considered as sectionalizing switches
                % fuse name
                namePtr = strfind(fusInfo,'name');
                [~, remain] = strtok(fusInfo(namePtr:end)); % delete 'name'
                fuseName = strtok(remain,' ;'); % delete ';' and spaces
                % switch state
                osloc = strfind(fusInfo,'OPEN');
                csloc = strfind(fusInfo,'CLOSED');
                fuseState = [];
                if ~isempty(csloc)
                    fuseState = 1; % closed
                elseif ~isempty(osloc)
                    fuseState = 0; % open
                end
                if fuseState == 1 % Closed fuses are considered as sectionalizing switches
%                     resObj.sec_swi_name = [resObj.sec_swi_name;{fuseName}];
%                     resObj.sec_swi = [resObj.sec_swi; [fromIdx, toIdx]];
%                     resObj.sec_swi_loc = [resObj.sec_swi_loc; [fusePtr(idx)+csloc-1,0,0,0]];
                elseif fuseState == 0
                    resObj.top_ori.deleteEdge(fromIdx, toIdx); % remove open fuses switches from the original graph
                end
                % *****************************************
            end
        end
        
        %
        function readLoad_2(resObj)
            % Load
            loadPtr = strfind(resObj.glmFile,'object load');
            num_of_load = size(loadPtr,2);
            load_matrix = cell(num_of_load,7);
            %
            for idx = 1:num_of_load
                %
                loadInfo = resObj.glmFile(loadPtr(idx):end);
                endPtr = strfind(loadInfo,'}');
                loadInfo = loadInfo(1:endPtr(1));
                %
                % Extract the information we need
                % location of loads
                parent = strfind(loadInfo,' parent ');
                if ~isempty(parent)
                    subString = loadInfo(parent:end);
                    [~, remain] = strtok(subString); % delete 'parent'
                    token = strtok(remain,' ;'); % delete ';' and spaces
                    load_matrix(idx,1) = {token};
                end
                if strcmp(token,'node741')==1
                    myTest = 1;
                end
                % For loads with constant power
                constant_power_A = strfind(loadInfo,' constant_power_A ');
                constant_power_B = strfind(loadInfo,' constant_power_B ');
                constant_power_C = strfind(loadInfo,' constant_power_C ');
                constant_current_A = strfind(loadInfo,' constant_current_A ');
                constant_current_B = strfind(loadInfo,' constant_current_B ');
                constant_current_C = strfind(loadInfo,' constant_current_C ');
                constant_impedance_A = strfind(loadInfo,' constant_impedance_A ');
                constant_impedance_B = strfind(loadInfo,' constant_impedance_B ');
                constant_impedance_C = strfind(loadInfo,' constant_impedance_C ');
                if ~isempty(constant_power_A) || ~isempty(constant_power_B) || ~isempty(constant_power_C)
                    load_type = 1; % constant power
                elseif ~isempty(constant_current_A) || ~isempty(constant_current_B) || ~isempty(constant_current_C)
                    load_type = 2; % costant current
                else
                    load_type = 3; % costant impendance
                end
                
                if load_type == 1
                    % power  - phase A or AB
                    if ~isempty(constant_power_A)
                        subString = loadInfo(constant_power_A:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_A'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2double(token);
                        load_matrix(idx,2) = {real(PQ)};
                        load_matrix(idx,3) = {imag(PQ)};
                    else
                        load_matrix(idx,2) = {0};
                        load_matrix(idx,3) = {0};
                    end
                    % power  - phase B or BC
                    if ~isempty(constant_power_B)
                        subString = loadInfo(constant_power_B:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_B'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2double(token);
                        load_matrix(idx,4) = {real(PQ)};
                        load_matrix(idx,5) = {imag(PQ)};
                    else
                        load_matrix(idx,4) = {0};
                        load_matrix(idx,5) = {0};
                    end
                    % power  - phase C or CA
                    if ~isempty(constant_power_C)
                        subString = loadInfo(constant_power_C:end);
                        [~, remain] = strtok(subString); % delete 'constant_power_C'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        PQ = str2double(token);
                        load_matrix(idx,6) = {real(PQ)};
                        load_matrix(idx,7) = {imag(PQ)};
                    else
                        load_matrix(idx,6) = {0};
                        load_matrix(idx,7) = {0};
                    end
                elseif load_type == 2
                    % For loads with constant current
                    % nominal_voltage
                    nominal_voltage = strfind(loadInfo,' nominal_voltage ');
                    if ~isempty(nominal_voltage)
                        subString = loadInfo(nominal_voltage:end);
                        [~, remain] = strtok(subString); % delete 'nominal_voltage'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Vnom = str2double(token);
                    end
                    % power  - phase A or AB
                    if ~isempty(constant_current_A)
                        subString = loadInfo(constant_current_A:end);
                        [~, remain] = strtok(subString); % delete 'constant_current_A'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Current = str2double(token);
                        load_matrix(idx,2) = {real(Vnom*conj(Current))};
                        load_matrix(idx,3) = {imag(Vnom*conj(Current))};
                    else
                        load_matrix(idx,2) = {0};
                        load_matrix(idx,3) = {0};
                    end
                    % power  - phase B or BC
                    if ~isempty(constant_current_B)
                        subString = loadInfo(constant_current_B:end);
                        [~, remain] = strtok(subString); % delete 'constant_current_B'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Current = str2double(token);
                        load_matrix(idx,4) = {real(Vnom*(cos(-2*pi/3)+1i*sin(-2*pi/3))*conj(Current))};
                        load_matrix(idx,5) = {imag(Vnom*(cos(-2*pi/3)+1i*sin(-2*pi/3))*conj(Current))};
                    else
                        load_matrix(idx,4) = {0};
                        load_matrix(idx,5) = {0};
                    end
                    % power  - phase C or CA
                    if ~isempty(constant_current_C)
                        subString = loadInfo(constant_current_C:end);
                        [~, remain] = strtok(subString); % delete 'constant_current_C'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Current = str2double(token);
                        load_matrix(idx,6) = {real(Vnom*(cos(2*pi/3)+1i*sin(2*pi/3))*conj(Current))};
                        load_matrix(idx,7) = {imag(Vnom*(cos(2*pi/3)+1i*sin(2*pi/3))*conj(Current))};
                    else
                        load_matrix(idx,6) = {0};
                        load_matrix(idx,7) = {0};
                    end
                else
                    % For loads with constant impendance
                    % nominal_voltage
                    nominal_voltage = strfind(loadInfo,' nominal_voltage ');
                    if ~isempty(nominal_voltage)
                        subString = loadInfo(nominal_voltage:end);
                        [~, remain] = strtok(subString); % delete 'nominal_voltage'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Vnom = str2double(token);
                    end
                    % power  - phase A or AB
                    if ~isempty(constant_impedance_A)
                        subString = loadInfo(constant_impedance_A:end);
                        [~, remain] = strtok(subString); % delete 'constant_impedance_A'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Impendance = str2double(token);
                        load_matrix(idx,2) = {real(Vnom^2/conj(Impendance))};
                        load_matrix(idx,3) = {imag(Vnom^2/conj(Impendance))};
                    else
                        load_matrix(idx,2) = {0};
                        load_matrix(idx,3) = {0};
                    end
                    % power  - phase B or BC
                    if ~isempty(constant_impedance_B)
                        subString = loadInfo(constant_impedance_B:end);
                        [~, remain] = strtok(subString); % delete 'constant_impedance_B'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Impendance = str2double(token);
                        load_matrix(idx,4) = {real(Vnom^2/conj(Impendance))};
                        load_matrix(idx,5) = {imag(Vnom^2/conj(Impendance))};
                    else
                        load_matrix(idx,4) = {0};
                        load_matrix(idx,5) = {0};
                    end
                    % power  - phase C or CA
                    if ~isempty(constant_impedance_C)
                        subString = loadInfo(constant_impedance_C:end);
                        [~, remain] = strtok(subString); % delete 'constant_impedance_C'
                        token = strtok(remain,' ;'); % delete ';' and spaces
                        Impendance = str2double(token);
                        load_matrix(idx,6) = {real(Vnom^2/conj(Impendance))};
                        load_matrix(idx,7) = {imag(Vnom^2/conj(Impendance))};
                    else
                        load_matrix(idx,6) = {0};
                        load_matrix(idx,7) = {0};
                    end
                end
            end
            % Transformer
            tranPtr = strfind(resObj.glmFile,'object transformer');
            num_of_tran = size(tranPtr,2);
            tran_matrix = cell(num_of_tran,2);
            %
            for idx = 1:num_of_tran
                %
                tranInfo = resObj.glmFile(tranPtr(idx):end);
                endPtr = strfind(tranInfo,'}');
                tranInfo = tranInfo(1:endPtr(1));
                %
                from = strfind(tranInfo,' from ');
                to = strfind(tranInfo,' to ');
                if ~isempty(from)
                    subString = tranInfo(from:end);
                    [~, remain] = strtok(subString); % delete 'from'
                    token = strtok(remain,' ;'); % delete ';' and spaces
                    tran_matrix(idx,1) = {token};
                end
                if ~isempty(to)
                    subString = tranInfo(to:end);
                    [~, remain] = strtok(subString); % delete 'to'
                    token = strtok(remain,' ;'); % delete ';' and spaces
                    tran_matrix(idx,2) = {token};
                end
            end
            %
            tran_matrix = reshape(tran_matrix(~cellfun('isempty',tran_matrix)),[],2);
            %
            resObj.node_load_info = zeros(size(load_matrix,1),3);
            for idx = 1:size(resObj.node_load_info,1)
                nName = load_matrix(idx,1);
                nIdx = find(ismember(resObj.node_name,nName),1);
                if isempty(nIdx)
                    row = find(ismember(tran_matrix(:,2),load_matrix(idx,1)),1);
                    nName = tran_matrix(row,1);
                    nIdx = find(ismember(resObj.node_name,nName),1);
                end
                resObj.node_load_info(idx,1) = nIdx;
                P = cell2mat(load_matrix(idx,2)) + cell2mat(load_matrix(idx,4)) ...
                    + cell2mat(load_matrix(idx,6));
                Q = cell2mat(load_matrix(idx,3)) + cell2mat(load_matrix(idx,5)) ...
                    + cell2mat(load_matrix(idx,7));
                resObj.node_load_info(idx,2) = P;
                resObj.node_load_info(idx,3) = Q;
            end 
        end
           
        %% Simplify the Original Topology for Restoration
        
        % The 1st simplification, all non-switch edges are deleted.
        % The faulted edge must not be deleted.
        function simplifyTop_1(resObj)
            % Initialize the map for the 1st simplification
            resObj.ver_map_1 = 1:resObj.top_ori.getVerNum;
            
            % Initialize top_sim_1
            resObj.top_sim_1 = LinkedUndigraph();
            resObj.top_sim_1.copy(resObj.top_ori);
            
%             % the line connecting to feeder points should remain.
%             resObj.top_ori.BFS(resObj.s_ver);
%             feederLines = zeros(size(resObj.feederVertices,2),2);
%             feederLines(:,2) = (resObj.feederVertices)';
%             for idx = 1:size(resObj.feederVertices,2)
%                 feederLines(idx,1) = resObj.top_ori.parent(feederLines(idx,2));
%             end
            
            % Merge the two ends (vertices) of non-switch devices
            % Initialize the iterator
            resObj.top_ori.initializePos();
            % Form the map of vertices
            for idx = 1:resObj.top_ori.getVerNum
                v = resObj.top_ori.beginVertex(idx);
                while ~isempty(v)
                    if v>idx && ~resObj.isSwitch(idx,v) ...
                            && (v~=resObj.f_sec(1) || idx~=resObj.f_sec(2)) ...
                            && (v~=resObj.f_sec(2) || idx~=resObj.f_sec(1))
%                         % feeder lines should remain
%                         isFeederLine = 0;
%                         for k = 1:size(resObj.feederVertices,2)
%                             if (v~=feederLines(k,1) || idx~=feederLines(k,2)) ...
%                                     && (v~=feederLines(k,2) || idx~=feederLines(k,1))
%                                 isFeederLine = 1;
%                                 break;
%                             end
%                         end
%                         if isFeederLine == 1
%                             v = resObj.top_ori.nextVertex(idx);
%                             continue;
%                         end
                        %
                        iIndex = min(resObj.ver_map_1(idx),resObj.ver_map_1(v));
                        jIndex = max(resObj.ver_map_1(idx),resObj.ver_map_1(v));
%                         resObj.top_sim_1.mergeVer(iIndex, jIndex);
                        for s = 1:resObj.top_ori.getVerNum
                            if resObj.ver_map_1(s) == jIndex
                                resObj.ver_map_1(s) = iIndex;
                            elseif resObj.ver_map_1(s) > jIndex
                                resObj.ver_map_1(s) = resObj.ver_map_1(s) - 1;
                            end
                        end
                    end
                    v = resObj.top_ori.nextVertex(idx);
                end
            end
            % Deactivate the iterator
            resObj.top_ori.deactivePos();
            % Merge vertices
            resObj.top_sim_1.mergeVer_2(resObj.ver_map_1);
            
            % Update the index of switches, faulted section and source
            % vertex
            % Sectionalizing switches
            for idx = 1:size(resObj.sec_swi,1)
                resObj.sec_swi_1(idx,1) = resObj.ver_map_1(resObj.sec_swi(idx,1));
                resObj.sec_swi_1(idx,2) = resObj.ver_map_1(resObj.sec_swi(idx,2));
            end
            % Tie switches
            for idx = 1:size(resObj.tie_swi,1)
                resObj.tie_swi_1(idx,1) = resObj.ver_map_1(resObj.tie_swi(idx,1));
                resObj.tie_swi_1(idx,2) = resObj.ver_map_1(resObj.tie_swi(idx,2));
            end
            % Faulted section
            resObj.f_sec_1(1) = resObj.ver_map_1(resObj.f_sec(1));
            resObj.f_sec_1(2) = resObj.ver_map_1(resObj.f_sec(2));
            % Source Vertex
            resObj.s_ver_1 = resObj.ver_map_1(resObj.s_ver);
        end
        
        % The 2nd Simplification, all vertices whose degree equal to 1 or 2
        % are deleted. The source node, vertices with tie switches or the
        % faulted section should not be deleted.
        function simplifyTop_2(resObj)
            % Initialize top_sim_2
            resObj.top_sim_2 = LinkedUndigraph();
            resObj.top_sim_2.copy(resObj.top_sim_1);
            
            % Simplify top_sim_2
            resObj.ver_map_2 = resObj.top_sim_2.simplify(resObj.tie_swi_1,...
                resObj.f_sec_1,resObj.s_ver_1,resObj.feederVertices_1);
            
            % Update the index of switches, faulted section and source vertex
            % Tie switches
            for idx = 1:size(resObj.tie_swi_1,1)
                resObj.tie_swi_2(idx,1) = resObj.ver_map_2(resObj.tie_swi_1(idx,1));
                resObj.tie_swi_2(idx,2) = resObj.ver_map_2(resObj.tie_swi_1(idx,2));
            end
            % Faulted section
            resObj.f_sec_2(1) = resObj.ver_map_2(resObj.f_sec_1(1));
            resObj.f_sec_2(2) = resObj.ver_map_2(resObj.f_sec_1(2));
            % Source Vertex
            resObj.s_ver_2 = resObj.ver_map_2(resObj.s_ver_1);
            % Sectionalizing switches
            resObj.sec_swi_2 = zeros(resObj.top_sim_2.getEdgNum()-1,2);
            counter = 0;
            for uIdx = 1:resObj.top_sim_2.getVerNum()
                v = resObj.top_sim_2.adjList(uIdx).first;
                while ~isempty(v) 
                    vIdx = v.data;
                    if vIdx > uIdx ...
                            && ~ ( uIdx==resObj.f_sec_2(1) && vIdx==resObj.f_sec_2(2) ...
                                   || uIdx==resObj.f_sec_2(2) && vIdx==resObj.f_sec_2(1) )
                        counter = counter + 1;
                        resObj.sec_swi_2(counter,:) = [uIdx, vIdx];
                    end
                    v = v.link;
                end
            end
        end
        
        % Check an edge (i, j) in orginal graph is a switch or not
        % If yes, flag = 1; else, flag = 0
        function flag = isSwitch(resObj, iIndex, jIndex)
            flag = 0;
            for idx = 1:size(resObj.sec_swi,1)
                if iIndex==resObj.sec_swi(idx,1) && jIndex==resObj.sec_swi(idx,2) ...
                        || jIndex==resObj.sec_swi(idx,1) && iIndex==resObj.sec_swi(idx,2)
                    flag = 1;
                    break;
                end
            end
        end
        
        % Set faulted edge
        function setFEdge(resObj, f_sec)
            resObj.f_sec = f_sec;
        end
        
        % Set Source Vertex
        function setSVer(resObj, idx)
            resObj.s_ver = idx;
        end
        
         % Set feeder vertices
        function setFeederVertices_2(resObj)
            resObj.feederVertices_2 = zeros(1,size(resObj.feederVertices,2));
            for idx = 1:size(resObj.feederVertices,2)
                nodeSet = resObj.feederVertices_1(idx);
                while ~isempty(nodeSet)
                    curNode = nodeSet(1);
                    nodeSet = nodeSet(2:end);
                    if resObj.ver_map_2(curNode)~=0
                        resObj.feederVertices_2(idx) = resObj.ver_map_2(curNode);
                        break;
                    else
                        tNode = resObj.top_sim_1.adjList(curNode).first;
                        while ~isempty(tNode)
                            if tNode.data ~= resObj.s_ver_1
                                nodeSet = [nodeSet tNode.data];
                            end
                            tNode = tNode.link;
                        end
                    end
                end
            end
        end
        
        % Set microgrid vertices
        function setMicrogridVertices(resObj)
            resObj.MGIdx_1 = resObj.ver_map_1(resObj.MGIdx);
            resObj.MGIdx_2 = resObj.ver_map_2(resObj.MGIdx_1);
        end
        
        % The line between source vertex and feeder vertices are modeled as
        % sectionalizing switches in gridlab-d model. But actually they are
        % not. This function remove these line from the list of
        % sectionalizing swithces
        function modifySecSwiList(resObj)
            % sec_swi
            dRows = mod(find(resObj.sec_swi==resObj.s_ver),size(resObj.sec_swi,1));
            resObj.sec_swi = resObj.sec_swi(setdiff(1:size(resObj.sec_swi,1),dRows),:);
            resObj.sec_swi_loc = resObj.sec_swi_loc(setdiff(1:size(resObj.sec_swi_loc,1),dRows),:);
            resObj.sec_swi_name = resObj.sec_swi_name(setdiff(1:size(resObj.sec_swi_name,1),dRows),:);
            % sec_swi_1
            dRows_1 = mod(find(resObj.sec_swi_1==resObj.s_ver_1),size(resObj.sec_swi_1,1));
            resObj.sec_swi_1 = resObj.sec_swi_1(setdiff(1:size(resObj.sec_swi_1,1),dRows_1),:);
            % sec_swi_2
            dRows_2 = mod(find(resObj.sec_swi_2==resObj.s_ver_2),size(resObj.sec_swi_2,1));
            resObj.sec_swi_2 = resObj.sec_swi_2(setdiff(1:size(resObj.sec_swi_2,1),dRows_2),:);
            
            %%%%%% 2014-2-20 %%%%%%%%%%%%%%%
            num_sec_swi_2 = size(resObj.sec_swi_2,1);
            num_feeder = size(resObj.feederVertices_2,2);
            mRows = zeros(1,num_feeder);
            for k = 1:num_feeder
                if ~isempty(find(resObj.sec_swi_2==resObj.feederVertices_2(k),1))
                    mRows(k) = find(resObj.sec_swi_2==resObj.feederVertices_2(k));
                end
            end
            resObj.sec_swi_2 = resObj.sec_swi_2(setdiff(1:num_sec_swi_2,mRows),:);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        end
        
        %
        function loadInfo(resObj)
            ver_load_tmp = zeros(resObj.top_ori.numVertices,3);            
            for idx = 1:resObj.top_ori.numVertices
                ver_load_tmp(idx,1) = resObj.ver_map_1(idx);
                row = find(resObj.node_load_info(:,1)==idx,1);
                if ~isempty(row)
                    ver_load_tmp(idx,2:3) = resObj.node_load_info(row,2:3);
                else
                    ver_load_tmp(idx,2:3) = [0,0];
                end
            end
            
            P = accumarray(ver_load_tmp(:,1),ver_load_tmp(:,2));
            Q = accumarray(ver_load_tmp(:,1),ver_load_tmp(:,3));
            
            resObj.node_load_info_1 = [];
            for idx = 1:size(P,1)
                if P(idx) ~= 0 || Q(idx) ~= 0
                    resObj.node_load_info_1 = [resObj.node_load_info_1;...
                        idx, P(idx), Q(idx), sqrt(P(idx)^2+Q(idx)^2)];
                end
            end
        end
        
        %% Functions: Validation Restoration Results Using GridLAB-D
        
        % Modified gridlab-d model after a cyclic interchange operation
        function modifyGlmFile(resObj, oriFileName, newFileName, switchPair)
            % switchPair(1,:) is the sectionalizing switch that will open;
            % switchPair(2,:) is the tie switch that will close;
            
            % Open original file
            oriFile = fopen(['.\cases\',resObj.caseName,'\',oriFileName,'.glm']);
            if oriFile == -1
                error('Error: Can not open file !!!');
            end
            
            % Open new file
            newFile = fopen(['.\cases\',resObj.caseName,'\',newFileName,'.glm'],...
                'w', 'n', 'UTF-8');
            if newFile == -1
                error('Error: Can not open file !!!');
            end
            
            % Create new model
            tline = fgetl(oriFile); % Read a line from original model
            while ischar(tline)
                % If it is a switch or recloser
                if ~isempty(strfind(tline,'object')) && ...
                        ( ~isempty(strfind(tline,'recloser')) || ~isempty(strfind(tline,'switch')) )
                    % save the information about switch
                    switchInfo = [];
                    while ischar(tline)
                        switchInfo = [switchInfo,tline,'\n'];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(oriFile);
                    end
                    % Get information about from node and to node
                    [fromIdx, toIdx] = resObj.readAnEdge(switchInfo);
                    % Check if it is the switch needs to be opened/closed.
                    if fromIdx==switchPair(1,1) && toIdx==switchPair(1,2) ...
                            || fromIdx==switchPair(1,2) && toIdx==switchPair(1,1)
                        % Replace 'CLOSED' by 'OPEN'
                        newSwitchInfo = strrep(switchInfo,'CLOSED','OPEN');
                        % write the switch infomation into new file
                        fprintf(newFile,newSwitchInfo);
                    elseif fromIdx==switchPair(2,1) && toIdx==switchPair(2,2) ...
                            || fromIdx==switchPair(2,2) && toIdx==switchPair(2,1)
                        % Replace 'OPEN' by 'CLOSED'
                        newSwitchInfo = strrep(switchInfo,'OPEN','CLOSED');
                        % write the switch infomation into new file
                        fprintf(newFile,newSwitchInfo);
                    else
                        % write the switch infomation into new file
                        fprintf(newFile,switchInfo);
                    end
                    % read the next line from original model
                    tline = fgetl(oriFile);
                    continue;
                end
                % if it is not a switch or recloser, just write it into new file.
                fprintf(newFile,tline);
                fprintf(newFile,'\n');
                % read the next line from original model
                tline = fgetl(oriFile);
            end
            fclose(oriFile);
            fclose(newFile);
        end
        
        % Modified gridlab-d model according to switching operations
        % Based on the original file
        function modifyGlmFile_2(resObj, counter, newFileName)
            % Switching operations
            swi_to_open = resObj.candidateSwOpe(counter,1:2);
            swi_to_close = resObj.candidateSwOpe(counter,3:4);
            preCounter = resObj.candidateSwOpe(counter,5);
            while preCounter ~= 0
                swi_to_open = [swi_to_open; resObj.candidateSwOpe(preCounter,1:2)];
                swi_to_close = [swi_to_close; resObj.candidateSwOpe(preCounter,3:4)];
                preCounter = resObj.candidateSwOpe(preCounter,5);
            end
            
            % Open original file
            oriFile = fopen(['.\cases\',resObj.caseName,'\',resObj.fileName,'.glm']);
            if oriFile == -1
                error('Error: Can not open file !!!');
            end
            
            % Open new file
            newFile = fopen(['.\cases\',resObj.caseName,'\',newFileName,'.glm'],...
                'w', 'n', 'UTF-8');
            if newFile == -1
                error('Error: Can not open file !!!');
            end
            
            % Create new model
            newModel = [];
            tline = fgetl(oriFile); % Read a line from original model
            while ischar(tline)
                % If it is a switch or recloser
                if ~isempty(strfind(tline,'object')) && ...
                        ( ~isempty(strfind(tline,'recloser')) || ~isempty(strfind(tline,'switch')) )
                    % save the information about switch
                    switchInfo = [];
                    while ischar(tline)
                        switchInfo = [switchInfo,tline,'\n'];
                        if strfind(tline,'}')
                            break;
                        end
                        tline = fgetl(oriFile);
                    end
                    % Get information about from node and to node
                    [fromIdx, toIdx] = resObj.readAnEdge(switchInfo);
                    % Check if it is the switch needs to be opened/closed.
                    openOrNot = 0;
                    for k = 1:size(swi_to_open,1)
                        if fromIdx==swi_to_open(k,1) && toIdx==swi_to_open(k,2) ...
                            || fromIdx==swi_to_open(k,2) && toIdx==swi_to_open(k,1)
                            openOrNot = 1;
                            break;
                        end
                    end
                    closeOrNot = 0;
                    for k = 1:size(swi_to_open,1)
                        if fromIdx==swi_to_close(k,1) && toIdx==swi_to_close(k,2) ...
                            || fromIdx==swi_to_close(k,2) && toIdx==swi_to_close(k,1)
                            closeOrNot = 1;
                            break;
                        end
                    end
                    % Perform switching operations
                    if openOrNot == 1
                        % Replace 'CLOSED' by 'OPEN'
                        newSwitchInfo = strrep(switchInfo,'CLOSED','OPEN');
                        % write the switch infomation into new file
                        newModel = [newModel, newSwitchInfo];
%                         fprintf(newFile,newSwitchInfo);
                    elseif closeOrNot == 1
                        % Replace 'OPEN' by 'CLOSED'
                        newSwitchInfo = strrep(switchInfo,'OPEN','CLOSED');
                        % write the switch infomation into new file
%                         fprintf(newFile,newSwitchInfo);
                        newModel = [newModel, newSwitchInfo];
                    else
                        % write the switch infomation into new file
%                         fprintf(newFile,switchInfo);
                        newModel = [newModel, switchInfo];
                    end
                    % read the next line from original model
                    tline = fgetl(oriFile);
                    continue;
                end
                % if it is not a switch or recloser, just write it into new file.
                newModel = [newModel, tline, '\n'];
%                 fprintf(newFile,tline);
%                 fprintf(newFile,'\n');
                % read the next line from original model
                tline = fgetl(oriFile);
            end
            fprintf(newFile,newModel);
            fclose(oriFile);
            fclose(newFile);
        end
        
        %
        function modifyGlmFile_3(resObj, counter, newFileName)
            % Switching operations
            swi_to_open = resObj.candidateSwOpe(counter,1:2);
            swi_to_close = resObj.candidateSwOpe(counter,3:4);
            preCounter = resObj.candidateSwOpe(counter,5);
            while preCounter ~= 0
                swi_to_open = [swi_to_open; resObj.candidateSwOpe(preCounter,1:2)];
                swi_to_close = [swi_to_close; resObj.candidateSwOpe(preCounter,3:4)];
                preCounter = resObj.candidateSwOpe(preCounter,5);
            end
            
            %
            loc_sec = zeros(size(swi_to_open,1),4);
            for idx = 1:size(swi_to_open,1)
                for k = 1:size(resObj.sec_swi)
                    if swi_to_open(idx,1)==resObj.sec_swi(k,1) && swi_to_open(idx,2)==resObj.sec_swi(k,2) ...
                            || swi_to_open(idx,1)==resObj.sec_swi(k,2) && swi_to_open(idx,2)==resObj.sec_swi(k,1)
                        loc_sec(idx,:) = resObj.sec_swi_loc(k,:);
                    end
                end
            end
            loc_tie = zeros(size(swi_to_close,1),4);
            for idx = 1:size(swi_to_close,1)
                for k = 1:size(resObj.tie_swi)
                    if swi_to_close(idx,1)==resObj.tie_swi(k,1) && swi_to_close(idx,2)==resObj.tie_swi(k,2) ...
                            || swi_to_close(idx,1)==resObj.tie_swi(k,2) && swi_to_close(idx,2)==resObj.tie_swi(k,1)
                        loc_tie(idx,:) = resObj.tie_swi_loc(k,:);
                    end
                end
            end
            locations = [loc_sec; loc_tie];
            locations = unique(locations);
            if locations(1) == 0
                locations = locations(2:end);
            end
            
            % Modify glm file
            glmFile_new = [];
            p1 = 1;
            for idx = 1:size(locations,1)
                p2 = locations(idx);
                glmFile_new = [glmFile_new, resObj.glmFile(p1:p2-1)];
                if resObj.glmFile(p2) == 'C' % CLOSED
                    glmFile_new = [glmFile_new, 'OPEN'];
                    p1 = p2 + 6;
                else % OPEN
                    glmFile_new = [glmFile_new, 'CLOSED'];
                    p1 = p2 + 4;
                end
            end
            glmFile_new = [glmFile_new, resObj.glmFile(p1:end)];
            glmFile_new = strrep(glmFile_new,'%','%%');
            
            % Generate new glm file
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            if exist(dirName,'dir') == 0
                mkdir(['.\cases\',resObj.caseName,'\results'],...
                    ['result_',num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))]);
            end
            dirName = ['.\cases\',resObj.caseName,'\results\result_', ...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2)),'\',newFileName,'.glm'];
            newFile = fopen(dirName, 'w', 'n', 'UTF-8');
            if newFile == -1
                error('Error: Can not open file !!!');
            end
            fprintf(newFile,glmFile_new);
            fclose(newFile);
        end
        
        % Call GridLAB-D to run power flow
        function runPF(resObj, fileName)
            % Create .bat file
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            if exist(dirName,'dir') == 0
                mkdir(['.\cases\',resObj.caseName,'\results'],...
                    ['result_',num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))]);
            end
            
            % Open file
            dirName = ['.\cases\',resObj.caseName,'\results\result_', ...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2)),'\',fileName,'.bat'];
            batFile = fopen(dirName, 'w', 'n', 'UTF-8');
            if batFile == -1
                error('Error: Can not open file !!!');
            end
            % Write commands to file
            % *****************************************************************************
            % Need to use new version of gridlab-d for Pullman-WSU system
%             if strcmp(resObj.caseName,'Pullman_WSU')==1
%                 dir = ['cases\\',resObj.caseName,'\\results\\result_',...
%                     num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
%                 fprintf(batFile, ['cd ',dir,'\n']);
%                 fprintf(batFile, ['..\\..\\gridlabd\\gridlabd -w ',fileName,'.glm','\n']);
%             else
                dir = ['cases\\',resObj.caseName,'\\results\\result_',...
                    num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
                fprintf(batFile, ['cd ',dir,'\n']);
                fprintf(batFile, ['gridlabd -w ',fileName,'.glm','\n']);
%             end
            % *****************************************************************************
            % Close file
            fclose(batFile);
            
            % Run power flow
            dos(dirName);
        end
        
        % Check if the power flow is feasible
        % If yes, flag = 1; otherwise, flag = 0.
        % If flag = 0, the ID of overloaded feeder and the amount of load
        % can not be restored are recorded.
        % If more than one feeders are overloaded, feederID = -1; if no
        % feeder is overloaded, feederID = 0.
        function [flag, overLoad, feederID, mFlag] = checkPF(resObj)
            mFlag = resObj.checkMG();
            if resObj.calMaxFPower() <= resObj.feeder_power_limit(1) ...
                    && resObj.calMinVol() >= resObj.voltage_limit(1) ...
                    && mFlag == 1
                flag = 1;
                overLoad = 0;
                feederID = 0;
            else
                flag = 0;
                % Calculate the load need to be shed
                overLoad = 0;
                feederID = 0;
                counter = 1;
                dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
                dataFileName = [dirName,'\feeder',num2str(counter)];
                PQ = resObj.readFeedPower(dataFileName);
                while ~isempty(PQ)
                    S = sqrt(PQ(1)^2+PQ(2)^2);
                    if S > resObj.feeder_power_limit
                        overLoad = overLoad + S - resObj.feeder_power_limit;
                        if feederID == 0
                            feederID = counter;
                        else
                            feederID = -1;
                        end
                    end
                    counter = counter + 1;
                    dataFileName = [dirName,'\feeder',num2str(counter)];
                    PQ = resObj.readFeedPower(dataFileName);
                end
                % check microgrid %%%%%%%%%%%%%% need to improve
                if mFlag == 0
                    overLoad = inf;
                end
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
        end
        
        %
        function [flag, overLoad, feederID] = checkPF2(resObj)
            vFlag = resObj.checkLoadVoltage();
            [fFlag, overLoad1, feederID] = resObj.checkFeederPower();
            [mFlag, overLoad2, microgridID] = resObj.checkMG();
            [lFlag, overLoad3] = resObj.checkLinePower();
            
            if vFlag==1 && fFlag==1 && mFlag==1 && lFlag==1
                flag = 1;
            else
                flag = 0;
            end
            
            overLoad = overLoad1 + overLoad2 + overLoad3;
            if vFlag == 0
                overLoad = Inf;
            end
            
            if (feederID ~= 0 && microgridID ~= 0) || ...
                    feederID == -1 || microgridID == -1
                feederID = -1;
            elseif microgridID ~= 0
                feederID = microgridID + 100;
            end         
        end
        
        % Read Voltage Info
        function V = readVoltage(resObj, fileName)
            % Open file
            volFile = fopen([fileName,'.csv']);
            if volFile == -1
                V = []; % If can not open file
            else
                % Find the final line, and save it in tline_1
                tline_1 = fgetl(volFile); % Read a line
                tline_2 = fgetl(volFile); % Read a line
                while ischar(tline_2)
                    tline_1 = tline_2; % Read a line
                    tline_2 = fgetl(volFile); % Read a line
                end
                
                % Get voltage data
                voltage_temp = zeros(1,6);
                [~, remain] = strtok(tline_1,','); %@TODO (JX): (1) replace the "strtok with loop" by "strsplit"; (2) voltage_temp(idx)=NaN & str2double
                for idx = 1:6
                    [vol_str, remain] = strtok(remain,',');
                    voltage_temp(idx) = str2double(vol_str);
                end
                
                % Calculate magnitude of voltages
                V(1) = sqrt(voltage_temp(1)^2+voltage_temp(2)^2);
                V(2) = sqrt(voltage_temp(3)^2+voltage_temp(4)^2);
                V(3) = sqrt(voltage_temp(5)^2+voltage_temp(6)^2);
            end
            if volFile ~= -1
                fclose(volFile);
            end
        end
        
        % Calculate minimum voltage
        function Vmin = calMinVol(resObj)
            % Set initial value as 1.1 time voltage lower limit
            Vmin = resObj.voltage_limit*1.1;
            
            % Find the minimum voltage
            counter = 1;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\voltage',num2str(counter)];
            V = resObj.readVoltage(dataFileName);
            while ~isempty(V)
                for idx = 1:3
                    if V(idx)~=0 && V(idx)<Vmin
                        Vmin = V(idx);
                    end
                end
                counter = counter + 1;
                dataFileName = [dirName,'\voltage',num2str(counter)];
                V = resObj.readVoltage(dataFileName);
            end
        end
        
        % Check load voltages
        function vFlag = checkLoadVoltage(resObj)
            vFlag = 1;
            counter = 1;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\voltage',num2str(counter)];
            V = resObj.readVoltage(dataFileName);
            while ~isempty(V)
                for idx = 1:3
                    if V(idx)~=0 && ...
                            (V(idx) < resObj.voltage_limit(1) || ...
                            V(idx) > resObj.voltage_limit(2))
                        vFlag = 0;
                    end
                end
                counter = counter + 1;
                dataFileName = [dirName,'\voltage',num2str(counter)];
                V = resObj.readVoltage(dataFileName);
            end
        end
        
        % Read Feeder power data
        function PQ = readFeedPower(resObj, fileName)
            % Open file
            powerFile = fopen([fileName,'.csv']);
            if powerFile == -1
                PQ = []; % If can not open file
            else
                % File the final line, and save it in tline_1
                tline_1 = fgetl(powerFile); % Read a line
                tline_2 = fgetl(powerFile); % Read a line
                while ischar(tline_2)
                    tline_1 = tline_2; % Read a line
                    tline_2 = fgetl(powerFile); % Read a line
                end
                
                % Get power data
                remain = tline_1;
                for idx = 1:7
                    [~, remain] = strtok(remain,',');
                end
                for idx = 1:2
                    [PQ_str, remain] = strtok(remain,',');
                    PQ(idx) = str2double(PQ_str);
                end
            end
            if powerFile ~= -1
                fclose(powerFile);
            end
        end
        
        % Calculate Maximum Feeder Power
        function Smax = calMaxFPower(resObj)
            % Set initial value as 0.9 time the thermal limit
            Smax = resObj.feeder_power_limit*0.9;
            
            %Fine the maximun power
            counter = 1;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\feeder',num2str(counter)];
            PQ = resObj.readFeedPower(dataFileName);
            while ~isempty(PQ)
                S = sqrt(PQ(1)^2+PQ(2)^2);
                if S > Smax
                    Smax = S;
                end
                counter = counter + 1;
                dataFileName = [dirName,'\feeder',num2str(counter)];
                PQ = resObj.readFeedPower(dataFileName);
            end
        end
        
        % Check feeder power
        function [fFlag, overLoad, feederID] = checkFeederPower(resObj)
            % Initialization
            fFlag = 1;
            overLoad = 0;
            feederID = 0;
            %
            counter = 1;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\feeder',num2str(counter)];
            PQ = resObj.readFeedPower(dataFileName);
            while ~isempty(PQ)
                S = sqrt(PQ(1)^2+PQ(2)^2);
                if S > resObj.feeder_power_limit(counter)
                    fFlag = 0;
                    if feederID == 0
                        feederID = counter;
                        overLoad = S - resObj.feeder_power_limit(counter);
                    else
                        feederID = -1;
                        overLoad = overLoad + S - resObj.feeder_power_limit(counter);
                    end
                end
                counter = counter + 1;
                dataFileName = [dirName,'\feeder',num2str(counter)];
                PQ = resObj.readFeedPower(dataFileName);
            end
        end
        
        % Read line power data
        function PQ = readLinePower(resObj, fileName)
            % Open file
            powerFile = fopen([fileName,'.csv']);
            if powerFile == -1
                PQ = []; % If can not open file
            else
                % File the final line, and save it in tline_1
                tline_1 = fgetl(powerFile); % Read a line
                tline_2 = fgetl(powerFile); % Read a line
                while ischar(tline_2)
                    tline_1 = tline_2; % Read a line
                    tline_2 = fgetl(powerFile); % Read a line
                end
                
                % Get power data
                [~, remain] = strtok(tline_1,',');
                for idx = 1:6
                    [PQ_str, remain] = strtok(remain,',');
                    PQ(idx) = str2double(PQ_str);
                end
            end
            if powerFile ~= -1
                fclose(powerFile);
            end
        end
        
        function [lFlag, overLoad, lineID] = checkLinePower(resObj)
            lFlag = 1;
            overLoad = 0;
            lineID = 0;
            counter = 1;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\line',num2str(counter)];
            PQ = resObj.readLinePower(dataFileName);
            while ~isempty(PQ)
                for k = 1:3
                    S = sqrt(PQ(2*k-1)^2+PQ(2*k)^2);
                    if S > resObj.thermal_limit(counter)
                        lFlag = 0;
                        if lineID == 0
                            lineID = counter;
                            overLoad = S - resObj.thermal_limit(counter);
                        else
                            lineID = -1;
                            overLoad = overLoad + S - resObj.thermal_limit(counter);
                        end
                    end
                end
                counter = counter + 1;
                dataFileName = [dirName,'\feeder',num2str(counter)];
                PQ = resObj.readFeedPower(dataFileName);
            end
        end
        
        % Read microgrid output
        function PQ = readMGPower(resObj, fileName)
            % Open file
            powerFile = fopen([fileName,'.csv']);
            if powerFile == -1
                PQ = []; % If can not open file
            else
                % File the final line, and save it in tline_1
                tline_1 = fgetl(powerFile); % Read a line
                tline_2 = fgetl(powerFile); % Read a line
                while ischar(tline_2)
                    tline_1 = tline_2; % Read a line
                    tline_2 = fgetl(powerFile); % Read a line
                end
                
                % Get power data
                remain = tline_1;
                for idx = 1:7
                    [~, remain] = strtok(remain,',');
                end
                for idx = 1:2
                    [PQ_str, remain] = strtok(remain,',');
                    PQ(idx) = str2double(PQ_str);
                end
            end
            if powerFile ~= -1
                fclose(powerFile);
            end
        end
        
        % Check if microgrid power exceed the limits
        function [mFlag, overLoad, microgridID] = checkMG(resObj)
            % Initialization
            mFlag = 1;
            overLoad = 0;
            microgridID = 0;
            %
            counter = 0;
            dirName = ['.\cases\',resObj.caseName,'\results\result_',...
                num2str(resObj.f_sec(1)),'-',num2str(resObj.f_sec(2))];
            dataFileName = [dirName,'\microgrid',num2str(resObj.numMG+1)];
            PQ = resObj.readMGPower(dataFileName);
            while ~isempty(PQ)
                counter = counter + 1;
                if PQ(1) > resObj.microgrid_limit(resObj.numMG, 1) ...
                        || PQ(2) > resObj.microgrid_limit(resObj.numMG, 2)
                    mFlag = 0;
                    % Record the ID of overload Microgrid
                    if microgridID == 0
                        microgridID = counter;
                    else
                        microgridID = -1;
                    end
                    % Calculate the amount of overload
                    if PQ(1) > resObj.microgrid_limit(resObj.numMG, 1)
                        over_P = PQ(1) - resObj.microgrid_limit(resObj.numMG, 1);
                    else
                        over_P = 0;
                    end
                    if PQ(2) > resObj.microgrid_limit(resObj.numMG, 2)
                        over_Q = PQ(2) - resObj.microgrid_limit(resObj.numMG, 2);
                    else
                        over_Q = 0;
                    end
                    overLoad = overLoad + sqrt(over_P^2+over_Q^2);
                end
                dataFileName = [dirName,'\microgrid',num2str(resObj.numMG+1)];
                PQ = resObj.readMGPower(dataFileName);
            end
        end
        
        % Check result without power flow
        function [flag, overLoad, feederID] = checkWithoutPF(resObj,counter)
            disp('Check Feasibility without Power Flow!!!');
            
            % The topology of distribution system after restoration is performed
            resObj.top_tmp.deleteEdge(resObj.candidateSwOpe_1(counter,1),resObj.candidateSwOpe_1(counter,2));
            resObj.top_tmp.addEdge(resObj.candidateSwOpe_1(counter,3),resObj.candidateSwOpe_1(counter,4));
            preCounter = resObj.candidateSwOpe_1(counter,5);
            while preCounter ~= 0
                resObj.top_tmp.deleteEdge(resObj.candidateSwOpe_1(preCounter,1),resObj.candidateSwOpe_1(preCounter,2));
                resObj.top_tmp.addEdge(resObj.candidateSwOpe_1(preCounter,3),resObj.candidateSwOpe_1(preCounter,4));
                preCounter = resObj.candidateSwOpe_1(preCounter,5);
            end
            
            % BFS
            resObj.top_tmp.BFS(resObj.s_ver_1);   
            
            % Calculate load in each feeder/microgrid
            feeder_load = zeros(size(resObj.feederVertices_1,2),3);
            if ~isempty(resObj.MGIdx_1)
                microgrid_load = zeros(size(resObj.MGIdx_1,2),3); 
            end
            for idx = 1:size(resObj.node_load_info_1,1)
                curNode = resObj.node_load_info_1(idx,1);
                while curNode ~= -1
                    fIdx = find(resObj.feederVertices_1==curNode,1);
                    if ~isempty(fIdx)
                        feeder_load(fIdx,1:2) = feeder_load(fIdx,1:2) + resObj.node_load_info_1(idx,2:3);
                        break;
                    end
                    mIdx = find(resObj.MGIdx_1==curNode,1);
                    if ~isempty(mIdx)
                        if resObj.top_tmp.parent(curNode) == resObj.s_ver_1
                            microgrid_load(mIdx,1:2) = microgrid_load(mIdx,1:2) + resObj.node_load_info_1(idx,2:3);
                            break;
                        end
                    end
                    curNode = resObj.top_tmp.parent(curNode);
                end
            end
            
            % Return to initial state
            resObj.top_tmp.addEdge(resObj.candidateSwOpe_1(counter,1),resObj.candidateSwOpe_1(counter,2));
            resObj.top_tmp.deleteEdge(resObj.candidateSwOpe_1(counter,3),resObj.candidateSwOpe_1(counter,4));
            preCounter = resObj.candidateSwOpe_1(counter,5);
            while preCounter ~= 0
                resObj.top_tmp.addEdge(resObj.candidateSwOpe_1(preCounter,1),resObj.candidateSwOpe_1(preCounter,2));
                resObj.top_tmp.deleteEdge(resObj.candidateSwOpe_1(preCounter,3),resObj.candidateSwOpe_1(preCounter,4));
                preCounter = resObj.candidateSwOpe_1(preCounter,5);
            end
            
            feeder_load(:,3) = sqrt(feeder_load(:,1).^2+feeder_load(:,2).^2);
            if ~isempty(resObj.MGIdx_1)
                microgrid_load(:,3) = sqrt(microgrid_load(:,1).^2+microgrid_load(:,2).^2);
            end
            
            % Check feasiblity
            % Feeder load
            fFlag = 1;
            overLoad_F = 0;
            feederID = 0;
            diff = feeder_load(:,3) - resObj.feeder_power_limit;
            feasible = (diff > 0);
            if sum(feasible) == 1
                fFlag = 0;
                feederID = find(feasible==1);
                overLoad_F = diff(feederID);
            elseif sum(feasible) > 1
                fFlag = 0;
                feederID = -1;
                overLoad_F = sum(diff(find(feasible==1)));
            end
            % Microgrid load
            mFlag = 1;
            overLoad_M = 0;
            microgridID = 0;
            if ~isempty(resObj.MGIdx_1)
                diff_2 = microgrid_load(:,1:2) - resObj.microgrid_limit;
                feasible_2t = (diff_2 > 0);
                feasible_2 = zeros(resObj.numMG,1);
                for k = 1:resObj.numMG
                    feasible_2(k) = feasible_2t(k,1) || feasible_2t(k,2);
                end
                if sum(feasible_2) == 1
                    mFlag = 0;
                    microgridID = find(feasible_2==1);
                    if feasible_2t(microgridID,1) == 1 && feasible_2t(microgridID,2) == 1
                        overLoad_M = sqrt(diff_2(microgridID,1)^2+diff_2(microgridID,2)^2);
                    elseif feasible_2t(microgridID,1) == 1
                        overLoad_M = diff_2(microgridID,1);
                    elseif feasible_2t(microgridID,2) == 1
                        overLoad_M = diff_2(microgridID,2);
                    end
                elseif sum(feasible_2) > 1
                    mFlag = 0;
                    microgridID = -1;
                    overLoad_M = 0;
                    for k = 1:resObj.numMG
                        if feasible_2t(k,1) == 1 && feasible_2t(k,2) == 1
                            overLoad_M = overLoad_M + sqrt(diff_2(k,1)^2+diff_2(k,2)^2);
                        elseif feasible_2t(k,1) == 1
                            overLoad_M = overLoad_M + diff_2(k,1);
                        elseif feasible_2t(k,2) == 1
                            overLoad_M = overLoad_M + diff_2(k,2);
                        end
                    end
                end
            end
            % 
            if mFlag==1 && fFlag==1
                flag = 1;
            else
                flag = 0;
            end
            
            overLoad = overLoad_F + overLoad_M;
            
            if (feederID ~= 0 && microgridID ~= 0) || ...
                    feederID == -1 || microgridID == -1
                feederID = -1;
            elseif microgridID ~= 0
                feederID = microgridID + 100;
            end
        end
        
        %% Functions for restoration
        
        % Full Restoration by spanning tree search
        % Perform full restoration to the system for given fault
        % If outage loads can be full restored, return the index for the,
        % last switch operation, and save switching sequence in swi_seq; 
        % otherwise, return 0.a.
        function IdxSW = spanningTreeSearch(resObj)
            % set initial value of idxSW
            IdxSW = 0;
            
            % Find the fundamental cut set of the fault section
            resObj.top_sim_2.BFS(resObj.s_ver_2);
            FCutSet_2 = resObj.top_sim_2.findFunCutSet(resObj.tie_swi_2,resObj.f_sec_2);
            for idx = 1:size(FCutSet_2,1)
                [FCutSet(idx,:), FCutSet_1(idx,:)] = resObj.mapTieSwi(FCutSet_2(idx,:));
            end
            
            % Save all candidate solutions
            resObj.candidateSwOpe = [];
            resObj.candidateSwOpe_1 = [];
            resObj.candidateSwOpe_2 = [];
            for idx = 1:size(FCutSet_2,1)
                resObj.candidateSwOpe_2 = [resObj.candidateSwOpe_2; ...
                    resObj.f_sec_2, FCutSet_2(idx,:), zeros(1,3)];
                resObj.candidateSwOpe_1 = [resObj.candidateSwOpe_1; ...
                    resObj.f_sec_1, FCutSet_1(idx,:), zeros(1,3)];
                resObj.candidateSwOpe = [resObj.candidateSwOpe; ...
                    resObj.f_sec, FCutSet(idx,:), zeros(1,3)];
            end

            
            % Search for spanning trees without duplication
            counter = 1;
            while counter <= size(resObj.candidateSwOpe,1)
                if resObj.candidateSwOpe(counter,5) == 0
                    [feasible, overLoad, feederID] = resObj.checkWithoutPF(counter);
                    if feasible == 1                        
%                         % Perform the cyclic interchange operation
%                         switchPair = [resObj.candidateSwOpe(counter,1:2);...
%                             resObj.candidateSwOpe(counter,3:4)];
                        newFileName = [resObj.fileName,'_',num2str(counter)];
%                         resObj.modifyGlmFile(resObj.fileName, newFileName, switchPair);
%                         resObj.modifyGlmFile_2(counter,newFileName);
                        resObj.modifyGlmFile_3(counter,newFileName);
                        % Run power flow and Check results
                        resObj.runPF(newFileName);
%                         [feasible, overLoad, feederID, mFlag] = resObj.checkPF();
						[feasible, overLoad, feederID] = resObj.checkPF2();
                    end
                    
                    % If feasible restoration scheme is found
                    if feasible == 1 
                        IdxSW = counter;
                        return;
                    end
                    
                    % If feasible restoration scheme is not found
                    % Save the mount of load need shedding for partial restoration
                    resObj.candidateSwOpe_2(counter,6) = overLoad;
                    resObj.candidateSwOpe_1(counter,6) = overLoad;
                    resObj.candidateSwOpe(counter,6) = overLoad;
                    resObj.candidateSwOpe_2(counter,7) = feederID;
                    resObj.candidateSwOpe_1(counter,7) = feederID;
                    resObj.candidateSwOpe(counter,7) = feederID;
                    
                    % Form the graph after restoration
                    resObj.top_res.copy(resObj.top_sim_2);
                    resObj.top_res.deleteEdge(resObj.candidateSwOpe_2(counter,1),resObj.candidateSwOpe_2(counter,2));
                    resObj.top_res.addEdge(resObj.candidateSwOpe_2(counter,3),resObj.candidateSwOpe_2(counter,4));
                    resObj.top_res.BFS(resObj.s_ver_2);
                    % Form the tie switch list for new graph
                    new_tie_swi = resObj.tie_swi_2;
                    for idx = 1:size(new_tie_swi,1)
                        if new_tie_swi(idx,1)==resObj.candidateSwOpe_2(counter,3) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(counter,4) ...
                            || new_tie_swi(idx,1)==resObj.candidateSwOpe_2(counter,4) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(counter,3)
                            new_tie_swi(idx,1) = resObj.candidateSwOpe_2(counter,1);
                            new_tie_swi(idx,2) = resObj.candidateSwOpe_2(counter,2);
                        end
                    end
                    %
                    for idx = 1:size(resObj.sec_swi_2,1)
                        % Open the sectionalizing switch
                        SW_to_Open_2 = resObj.sec_swi_2(idx,:);
%                         [SW_to_Open, SW_to_Open_1] = resObj.mapSecSwi(SW_to_Open_2);
                        SW_to_Open = resObj.sec_swi_map(idx,:);
                        SW_to_Open_1 = resObj.sec_swi_map_1(idx,:);
                        
                        % If the switch to open is not in the overloaded
                        % feeder, move on to the next candidate switch.
                        feeder_overloaded = resObj.candidateSwOpe_2(counter,7);
                        if feeder_overloaded ~= 0 && resObj.isSwiInFeeder(SW_to_Open_2,feeder_overloaded) == 0
                            continue;
                        end
                        
                        % Fundamental cut set of the sectionalizing switch
                        FCutSet_2_1 = resObj.top_sim_2.findFunCutSet(resObj.tie_swi_2,resObj.sec_swi_2(idx,:));
                        FCutSet_2_2 = resObj.top_res.findFunCutSet(new_tie_swi,resObj.sec_swi_2(idx,:));
                        FCutSet_2 = intersect(FCutSet_2_1, FCutSet_2_2, 'rows');
                        for k = 1:size(FCutSet_2,1)
                            [FCutSet(k,:), FCutSet_1(k,:)] = resObj.mapTieSwi(FCutSet_2(k,:));
                        end
                        % Save all candidate solutions
                        for k = 1:size(FCutSet_2,1)
                            resObj.candidateSwOpe_2 = [resObj.candidateSwOpe_2; ...
                                SW_to_Open_2, FCutSet_2(k,:), counter, 0, 0];
                            resObj.candidateSwOpe_1 = [resObj.candidateSwOpe_1; ...
                                SW_to_Open_1, FCutSet_1(k,:), counter, 0, 0];
                            resObj.candidateSwOpe = [resObj.candidateSwOpe; ...
                                SW_to_Open, FCutSet(k,:), counter, 0, 0];
                        end
                    end                   
                else
                    [feasible, overLoad, feederID] = resObj.checkWithoutPF(counter);
                    if feasible == 1
%                         % Perform the cyclic interchange operation
%                         switchPair = [resObj.candidateSwOpe(counter,1:2);...
%                             resObj.candidateSwOpe(counter,3:4)];
%                         oriFileName = [resObj.fileName,'_',num2str(resObj.candidateSwOpe(counter,5))];
                        newFileName = [resObj.fileName,'_',num2str(counter)];
%                         resObj.modifyGlmFile(oriFileName, newFileName, switchPair);
%                         resObj.modifyGlmFile_2(counter,newFileName);
                        resObj.modifyGlmFile_3(counter,newFileName);
                        % Run power flow and Check results
                        resObj.runPF(newFileName);
%                         [feasible, overLoad, feederID, mFlag] = resObj.checkPF();
						[feasible, overLoad, feederID] = resObj.checkPF2();
                    end
                    
                    % If feasible restoration scheme is found
                    if feasible == 1 
                        IdxSW = counter;
                        return;
                    end
                    
                    % If feasible restoration scheme is not found
                    resObj.candidateSwOpe_2(counter,6) = overLoad;
                    resObj.candidateSwOpe_1(counter,6) = overLoad;
                    resObj.candidateSwOpe(counter,6) = overLoad;
                    resObj.candidateSwOpe_2(counter,7) = feederID;
                    resObj.candidateSwOpe_1(counter,7) = feederID;
                    resObj.candidateSwOpe(counter,7) = feederID;
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%%% If counter > 300, we can assume full restoration
                    %%%% is failed.
                    if counter == 300
                        resObj.candidateSwOpe = resObj.candidateSwOpe(1:300,:);
                        resObj.candidateSwOpe_1 = resObj.candidateSwOpe_1(1:300,:);
                        resObj.candidateSwOpe_2 = resObj.candidateSwOpe_2(1:300,:);
                        return;
                    end
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    
                    % If more than one feeder are overloaded OR
                    % one or more microgrids are overloaded OR
                    % move on to the next candidate switching operation
                    if feederID == -1
                        counter = counter + 1;
                        continue;
                    end
                    
                    % Form new graph
                    resObj.top_res.copy(resObj.top_sim_2);
                    resObj.top_res.deleteEdge(resObj.candidateSwOpe_2(counter,1),resObj.candidateSwOpe_2(counter,2));
                    resObj.top_res.addEdge(resObj.candidateSwOpe_2(counter,3),resObj.candidateSwOpe_2(counter,4));
                    preCounter = resObj.candidateSwOpe_2(counter,5);
                    while preCounter ~= 0
                        resObj.top_res.deleteEdge(resObj.candidateSwOpe_2(preCounter,1),resObj.candidateSwOpe_2(preCounter,2));
                        resObj.top_res.addEdge(resObj.candidateSwOpe_2(preCounter,3),resObj.candidateSwOpe_2(preCounter,4));  
                        preCounter = resObj.candidateSwOpe_2(preCounter,5);
                    end
                    resObj.top_res.BFS(resObj.s_ver_2);
                    % Form the tie switch list for new graph
                    new_tie_swi = resObj.tie_swi_2;
                    for idx = 1:size(new_tie_swi,1)
                        if new_tie_swi(idx,1)==resObj.candidateSwOpe_2(counter,3) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(counter,4) ...
                            || new_tie_swi(idx,1)==resObj.candidateSwOpe_2(counter,4) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(counter,3)
                            new_tie_swi(idx,1) = resObj.candidateSwOpe_2(counter,1);
                            new_tie_swi(idx,2) = resObj.candidateSwOpe_2(counter,2);
                        end
                    end
                    preCounter = resObj.candidateSwOpe_2(counter,5);
                    while preCounter ~= 0
                        for idx = 1:size(new_tie_swi,1)
                            if new_tie_swi(idx,1)==resObj.candidateSwOpe_2(preCounter,3) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(preCounter,4) ...
                                    || new_tie_swi(idx,1)==resObj.candidateSwOpe_2(preCounter,4) && new_tie_swi(idx,2)==resObj.candidateSwOpe_2(preCounter,3)
                                new_tie_swi(idx,1) = resObj.candidateSwOpe_2(preCounter,1);
                                new_tie_swi(idx,2) = resObj.candidateSwOpe_2(preCounter,2);
                            end
                        end
                        preCounter = resObj.candidateSwOpe_2(preCounter,5);
                    end
                    %
                    for idx = 1:size(resObj.sec_swi_2,1)
                        if resObj.sec_swi_2(idx,1)==resObj.candidateSwOpe_2(counter,1) && resObj.sec_swi_2(idx,2)==resObj.candidateSwOpe_2(counter,2) ...
                            || resObj.sec_swi_2(idx,1)==resObj.candidateSwOpe_2(counter,2) && resObj.sec_swi_2(idx,2)==resObj.candidateSwOpe_2(counter,1)
                            startIdx = idx + 1;
                            break;
                        end
                    end
                    %
                    for idx = startIdx:size(resObj.sec_swi_2,1)
                        % Open the sectionalizing switch
                        SW_to_Open_2 = resObj.sec_swi_2(idx,:);
                        SW_to_Open = resObj.sec_swi_map(idx,:);
                        SW_to_Open_1 = resObj.sec_swi_map_1(idx,:);
%                         [SW_to_Open, SW_to_Open_1] = resObj.mapSecSwi(SW_to_Open_2);

                        % If the switch to open is not in the overloaded
                        % feeder, move on to the next candidate switch.
                        feeder_overloaded = resObj.candidateSwOpe_2(counter,7);
                        if feeder_overloaded ~= 0 && resObj.isSwiInFeeder(SW_to_Open_2,feeder_overloaded) == 0
                            continue;
                        end
                        
                        % Fundamental cut set of the sectionalizing switch
                        FCutSet_2_1 = resObj.top_sim_2.findFunCutSet(resObj.tie_swi_2,resObj.sec_swi_2(idx,:));
                        FCutSet_2_2 = resObj.top_res.findFunCutSet(new_tie_swi,resObj.sec_swi_2(idx,:));
                        FCutSet_2 = intersect(FCutSet_2_1, FCutSet_2_2, 'rows');
                        for k = 1:size(FCutSet_2,1)
                            [FCutSet(k,:), FCutSet_1(k,:)] = resObj.mapTieSwi(FCutSet_2(k,:));
                        end
                        
                        % Save all candidate solutions
                        for k = 1:size(FCutSet_2,1)
                            resObj.candidateSwOpe_2 = [resObj.candidateSwOpe_2; ...
                                SW_to_Open_2, FCutSet_2(k,:), counter, 0, 0];
                            resObj.candidateSwOpe_1 = [resObj.candidateSwOpe_1; ...
                                SW_to_Open_1, FCutSet_1(k,:), counter, 0, 0];
                            resObj.candidateSwOpe = [resObj.candidateSwOpe; ...
                                SW_to_Open, FCutSet(k,:), counter, 0, 0];
                        end
                    end
                end
                counter = counter + 1;
            end
        end
        
        % 
        function [tSW, tSW_1] = mapTieSwi(resObj, tSW_2)
            idx = 1;
            while 1
                if resObj.tie_swi_2(idx,1)==tSW_2(1) && resObj.tie_swi_2(idx,2)==tSW_2(2)
                    tSW(1) = resObj.tie_swi(idx,1);
                    tSW(2) = resObj.tie_swi(idx,2);
                    tSW_1(1) = resObj.tie_swi_1(idx,1);
                    tSW_1(2) = resObj.tie_swi_1(idx,2);
                    break;
                end
                if resObj.tie_swi_2(idx,2)==tSW_2(1) && resObj.tie_swi_2(idx,1)==tSW_2(2)
                    tSW(1) = resObj.tie_swi(idx,2);
                    tSW(2) = resObj.tie_swi(idx,1);
                    tSW_1(1) = resObj.tie_swi_1(idx,2);
                    tSW_1(2) = resObj.tie_swi_1(idx,1);
                    break;
                end
                idx = idx + 1;
            end
        end
        
        %
        function [sSW, sSW_1] = mapSecSwi(resObj, sSW_2)
            % sSW_1
            % An edge in top_sim_2 may present more than 1 edge in top_sim_1
            % BFS for top_sim_1
            resObj.top_sim_1.BFS(resObj.s_ver_1);
            % 
            uIdx = find(resObj.ver_map_2==sSW_2(1));
            vIdx = find(resObj.ver_map_2==sSW_2(2));
            if resObj.top_sim_1.dist(uIdx) > resObj.top_sim_1.dist(vIdx)
                temp = uIdx;
                uIdx = vIdx;
                vIdx = temp;
            end
            %
            detDist = resObj.top_sim_1.dist(vIdx) - resObj.top_sim_1.dist(uIdx);
            for idx = 1 : floor(detDist/2)
                vIdx = resObj.top_sim_1.parent(vIdx);
            end
            sSW_1(2) = vIdx;
            sSW_1(1) = resObj.top_sim_1.parent(vIdx);
            
            % sSW
            idx = 1;
            while 1
                if resObj.sec_swi_1(idx,1)==sSW_1(1) && resObj.sec_swi_1(idx,2)==sSW_1(2)
                    sSW(1) = resObj.sec_swi(idx,1);
                    sSW(2) = resObj.sec_swi(idx,2);
                    break;
                end
                if resObj.sec_swi_1(idx,1)==sSW_1(2) && resObj.sec_swi_1(idx,2)==sSW_1(1)
                    sSW(1) = resObj.sec_swi(idx,2);
                    sSW(2) = resObj.sec_swi(idx,1);
                    break;
                end
                idx = idx + 1;
            end
        end
       
        %
        function formSecSwiMap(resObj)
            resObj.sec_swi_map = zeros(size(resObj.sec_swi_2));
            resObj.sec_swi_map_1 = zeros(size(resObj.sec_swi_2));
            for idx = 1:size(resObj.sec_swi_2,1)
                [sSW, sSW_1] = resObj.mapSecSwi(resObj.sec_swi_2(idx,:));
                resObj.sec_swi_map(idx,:) = sSW;
                resObj.sec_swi_map_1(idx,:) = sSW_1;
            end
        end
        
        % Check if a sectionalizing switch is in a given feeder,
        % Assume BFS is already performed for top_res
        function flag = isSwiInFeeder(resObj, swi_2, feederID_overload)
            curNode = swi_2(1);      
            if feederID_overload < 100 % If a feeder overloaded
                feederID_current = find(resObj.feederVertices_2==curNode);
                while isempty(feederID_current)
                    if ~isempty(find(resObj.MGIdx_2==curNode,1)) ...
                            && resObj.top_res.parent(curNode) == resObj.s_ver_2
                        flag = 0;
                        return;
                    end
                    curNode = resObj.top_res.parent(curNode);
                    feederID_current = find(resObj.feederVertices_2==curNode);
                end
                if feederID_current == feederID_overload
                    flag = 1;
                else
                    flag = 0;
                end
            else % If a microgrid overloaded
                microgridID_current = find(resObj.MGIdx_2==curNode);
                while isempty(microgridID_current)
                    curNode = resObj.top_res.parent(curNode);
                    if curNode == -1
                        flag = 0;
                        return;
                    end
                    microgridID_current = find(resObj.MGIdx_2==curNode);
                end
                if microgridID_current == feederID_overload - 100
                    flag = 1;
                else
                    flag = 0;
                end
            end
        end
        
        % Print Result
        function printResult(resObj, IdxSW)
            % Open file
            dirName = ['.\cases\',resObj.caseName,'\results'];
            resFile = fopen([dirName,'\Result_',resObj.fileName, ...
                '_', num2str(resObj.f_sec(1)), '-', num2str(resObj.f_sec(2)), '.txt'],...
                'w', 'n', 'UTF-8');
            if resFile == -1
                error('Error: Can not open file !!!');
            end
            
            % Case infomation
            fprintf(resFile, ['Case name: ', resObj.caseName, '/', resObj.fileName, '.\n']);
            fprintf(resFile, 'Fault section: %d - %d (in original topology), %d - %d (in simplified topology)\n', ...
                resObj.f_sec(1), resObj.f_sec(2), resObj.f_sec_1(1), resObj.f_sec_1(2));
            
            % Restoration results
            if IdxSW ~= 0 % Full restoration is successful
                fprintf(resFile, 'Full restoration is successful.\n');
                fprintf(resFile, 'The optimal switching sequence is as follows. \n');
                resObj.printSOs(resFile, IdxSW);
            elseif ~isempty(resObj.candidateSwOpe) % Partial restoration                
                [loadShedding, IdxSW] = min(resObj.candidateSwOpe(:,6));
                fprintf(resFile, 'Full restoration is failed. Partial restoration is performed.\n');
                fprintf(resFile, '%f kVA load should be shed.\n', loadShedding/1000);
                fprintf(resFile, 'The optimal switching sequence is as follows. \n');
                resObj.printSOs(resFile, IdxSW);
            else
                % Fail to restore all outage load
                fprintf(resFile, 'Outage load cannot be restored!!!\n');
            end
            fclose(resFile);
        end
        
        % Print a cyclic interchange operation
        function printCIO(resObj, resFile, IdxSW)
            fprintf(resFile, 'Open: %d - %d (in original topology), %d - %d (in simplified topology)\n', ...
                resObj.candidateSwOpe(IdxSW,1), resObj.candidateSwOpe(IdxSW,2), ...
                resObj.candidateSwOpe_1(IdxSW,1), resObj.candidateSwOpe_1(IdxSW,2) );
            if resObj.candidateSwOpe(IdxSW,3)~=resObj.s_ver && resObj.candidateSwOpe(IdxSW,4)~=resObj.s_ver
                fprintf(resFile, 'Close: %d - %d (in original topology), %d - %d (in simplified topology)\n', ...
                    resObj.candidateSwOpe(IdxSW,3), resObj.candidateSwOpe(IdxSW,4), ...
                    resObj.candidateSwOpe_1(IdxSW,3), resObj.candidateSwOpe_1(IdxSW,4) );
            else
                if resObj.candidateSwOpe(IdxSW,3)==resObj.s_ver
                    idx_microgrid = find(resObj.MGIdx==resObj.candidateSwOpe(IdxSW,4));
                    fprintf(resFile, 'Close: %d - Microgrid%d (in original topology), %d - Microgrid%d (in simplified topology)\n', ...
                        resObj.candidateSwOpe(IdxSW,4), idx_microgrid, ...
                        resObj.candidateSwOpe_1(IdxSW,4), idx_microgrid );
                end
            end
        end
        
        % Print switching operations recursively
        function printSOs(resObj, resFile, IdxSW)
            if resObj.candidateSwOpe(IdxSW, 5) ~= 0
                resObj.printSOs(resFile, resObj.candidateSwOpe(IdxSW, 5));
            end
            resObj.printCIO(resFile, IdxSW);
        end
        
    end
end
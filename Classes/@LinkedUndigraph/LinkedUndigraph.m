classdef LinkedUndigraph < LinkedDigraph
    % LINKEDUNDIGRAPH is the class for undirected graphs,
    % which are present by adjacency lists.
    
    methods
        % Constructor
        function uGraph = LinkedUndigraph(nVer)
            if nargin == 0 % allow for the no argument case
                nVer = 0;
            end
            uGraph = uGraph@LinkedDigraph(nVer);
        end
        
        % Add a new edge into the graph
        function addEdge(uGraph, iIndex, jIndex)
            if iIndex < 1 || jIndex < 1 || iIndex > uGraph.numVertices ...
                    || jIndex > uGraph.numVertices
                error('Error: The node Number(s) is(are) out of boundary!');
            end
            if iIndex == jIndex
                error('Error: Two nodes of an edge can not be the same!');
            end
            if uGraph.isEdgeExisting(iIndex, jIndex) == 1
                % error('Error: Can not add an edge that is already existing!');
                wInfo = ['Warning (addEdge): Edge (',num2str(iIndex),',',num2str(jIndex),') is  existing!'];
                disp(wInfo);
                return;
            end
            uGraph.adjList(iIndex).addNode(0, jIndex);
            uGraph.adjList(jIndex).addNode(0, iIndex);
            uGraph.numEdges = uGraph.numEdges + 1;
        end
        
        % Delete an edge from the graph
        function deleteEdge(uGraph, iIndex, jIndex)
            uGraph.deleteEdge@LinkedDigraph(iIndex, jIndex);
            uGraph.numEdges = uGraph.numEdges + 1; % compensation
            uGraph.deleteEdge@LinkedDigraph(jIndex, iIndex);
        end
        
        % Return the in degree of the given vertex
        function inDeg = getInDeg(uGraph, index)
            inDeg = uGraph.getInDeg@LinkedDigraph(index);
        end
        
        % Return the out degree of the given vertex
        function outDeg = getOutDeg(uGraph, index)
            outDeg = uGraph.getOutDeg@LinkedDigraph(index);
        end
        
        % Return the degree of the given vertex
        function deg = getDeg(uGraph, index)
            deg = uGraph.getOutDeg(index);
        end
        
                    
        %% Methods supporting restoration
        
        % Find fundmental cut set
        function cutSet = findFunCutSet(uTree, chordSet, tBranch)
            % uTree is the give undirected tree, assume DFS or BFS is already performed.
            % chordSet is a n*2 matrix, each row (i, j) corresponds to a chord.
            % tBranch is a 1*2 vector (i, j), denoting a tree edge of uTree
            % cutSet is the fundmental cut set
            cutSet = [];
            
            % Cut the given tree edge
            iIndex = tBranch(1);
            jIndex = tBranch(2);
            if uTree.parent(iIndex) == jIndex
                uTree.parent(iIndex) = -1;
                % backup for resuming
                child_back = iIndex;
                parent_back = jIndex;
            else
                uTree.parent(jIndex) = -1;
                % backup for resuming
                child_back = jIndex; 
                parent_back = iIndex;
            end
            
            % Fine fundmental cut set
            for idx = 1 : size(chordSet, 1)
                % Set the status of all vertices to '0'
                for k = 1 : uTree.numVertices
                    uTree.status(k) = 0;
                end
                iIndex = chordSet(idx, 1);
                jIndex = chordSet(idx, 2);
                % Mark the ancestors of vectex i as 1
                curIndex = iIndex;
                while curIndex ~= -1
                    uTree.status(curIndex) = 1;
                    curIndex = uTree.parent(curIndex);
                end
                % Check the status of vectex j's ancestors
                isCutSetEle = 1;
                curIndex = jIndex;
                while curIndex ~= -1
                    if uTree.status(curIndex) == 1 
                        isCutSetEle = 0; % (i,j) is not a element of the fundmental cut set
                        break;
                    end
                    curIndex = uTree.parent(curIndex);
                end
                % if (i,j) is a element of the fundmental cut set, add it to cutSet
                if isCutSetEle == 1
                    cutSet = [cutSet; chordSet(idx,:)];
                end
            end
            
            % Resume uTree
            uTree.parent(child_back) = parent_back;
        end
        
        % Graph simplify
        % Delete vertices whose degree is less than 3
        % Vertices connected with chords (tie switches) should be retained
        % Vertices connected with the edge corresponding to fault should be retained
        % The vertex denoting source should be retained
        % Feeder vertices should not be deleted.
        function vMap = simplify(uTree, chordSet, fBranch, source, fVer)
            % uTree is the orignal tree, assume BFS is already performed.
            % chordSet is a n*2 matrix, each row (i, j) corresponds to a chord
            % fBranch is a 1*2 vector (i, j), denoting the edge corresponding to fault
            % source is the vertex denoting source
            
            % Form a set for vertices that can not be deleted (important vertices)
            iVer = unique([chordSet(:)',fBranch,source,fVer]);
            
            % simplify
            while uTree.isolateDeg12Ver(iVer) ~= 0
                continue;
            end
            vMap = uTree.deleteIsoVer();
        end
        
        % a step for simulifying the original graph
        % Isolate vertices whose degree is 1 or 2
        function iNum = isolateDeg12Ver(uGraph, iVer)
            % uGraph is the original graph, which will be directly modified
            % iVer is a set of vertices which can not be isolated (important vertices)
            % iVer is a 1*n vector
            % iNum is the number of vertices that has been isolated
            
            % Mark important vertices
            iMark = zeros(1, uGraph.numVertices);
            for idx = 1 : size(iVer, 2)
                iMark(iVer(idx)) = 1;
            end
            
            % Isolation       
            iNum = 0;
            for u = 1 : uGraph.numVertices
                if iMark(u) == 0 % not an important vertex
                    if uGraph.getDeg(u) == 1 %  Isolate vertices whose degree is 1
                        % find the vertex connected to u
                        v = uGraph.adjList(u).first.data;
                        % delete edge (u, v)
                        uGraph.deleteEdge(u, v);
                        iNum = iNum + 1;
                        continue;
                    end
                    if uGraph.getDeg(u) == 2 %  Isolate vertices whose degree is 2
                        % find the vertices connected to u
                        v1 = uGraph.adjList(u).first.data;
                        v2 = uGraph.adjList(u).first.link.data;
                        % delete edge (u, v1) and (u, v2)
                        uGraph.deleteEdge(u, v1);
                        uGraph.deleteEdge(u, v2);
                        % add edge (v1, v2)
                        uGraph.addEdge(v1, v2);
                        iNum = iNum + 1;
                        continue;
                    end
                end
            end
        end
        
        % Delete all isolated vertices (degree = 0)
        function vMap = deleteIsoVer(uGraph)
            % vMap is a map between old number and new number of vertices
            % 'vMap(i) = j' means that vertex i in the original graph is
            % mapped to vertex j in the new graph
            % If vertex i in the original graph is deleted, vMap(i) = 0
            
            % Initial vMap
            vMap = 1 : uGraph.numVertices;
            
            % Form vMap
            numIsoVer = 0; % Number of isolated vertices
            isoVerArray = []; % A set of isolated vertices
            for idx = 1 : uGraph.numVertices
                if uGraph.getDeg(idx) == 0
                    vMap(idx) = 0;
                    vMap(idx+1:end) = vMap(idx+1:end) - 1;
                    numIsoVer = numIsoVer + 1;
                    isoVerArray = [isoVerArray,idx];
                end
            end
            
            % Modify index of vertices
            for idx = 1 : uGraph.numVertices
                v = uGraph.adjList(idx).first;
                while ~isempty(v)
                    v.data = vMap(v.data);
                    v = v.link;
                end
            end
            
            % Delete isolated vertices
            % Free memory
            for idx = 1 : numIsoVer
                uGraph.adjList(isoVerArray(idx)).delete(); 
            end
            % Delete from adjacency list
            for idx = 1 : uGraph.numVertices
                if vMap(idx) ~= 0
                    uGraph.adjList(vMap(idx)) = uGraph.adjList(idx);
                end
            end
            uGraph.adjList = uGraph.adjList(1:uGraph.numVertices-numIsoVer);
            
            % modify the number of vertices
            uGraph.numVertices = uGraph.numVertices - numIsoVer;
            
            % modify the length of other properties
            uGraph.status = zeros(1,uGraph.numVertices);
            uGraph.parent = -1*ones(1,uGraph.numVertices);
            uGraph.dist = Inf*ones(1,uGraph.numVertices);
            uGraph.dTime = zeros(1,uGraph.numVertices);
            uGraph.fTime = zeros(1,uGraph.numVertices);
        end
        
        % Merge two neighbering vertices
        % This function only works for trees
        % i and j must be connected
        function mergeVer(uGraph, iIndex, jIndex)
            % If i > j, change the value of i and j
            if iIndex > jIndex
                temp = iIndex;
                iIndex = jIndex;
                jIndex = temp;
            end
            
            % Delete edge (i, j)
            uGraph.deleteEdge(iIndex, jIndex);
            
            % Connect all neighbering vertices of j to i, and isolate j
            % Search process
            v = uGraph.adjList(jIndex).first; % find the first neighbor of j
            while ~isempty(v)
                uGraph.addEdge(iIndex, v.data); % connect i and v
                uGraph.deleteEdge(jIndex, v.data); % delete (j, v)
                v = uGraph.adjList(jIndex).first; % find the next neighbor of j
            end
            
            % Modify index of vertices
            for idx = 1 : uGraph.numVertices
                v = uGraph.adjList(idx).first;
                while ~isempty(v)
                    if v.data > jIndex
                        v.data = v.data-1;
                    end
                    v = v.link;
                end
            end
            
            % Delete j:
            % Free memory
            uGraph.adjList(jIndex).delete(); 
            % Delete j from adjacency list
            for idx = jIndex : uGraph.numVertices-1
                uGraph.adjList(idx) = uGraph.adjList(idx+1);
            end
            uGraph.adjList = uGraph.adjList(1:uGraph.numVertices-1);
            % modify the number of vertices
            uGraph.numVertices = uGraph.numVertices - 1;
            % modify the length of other properties
            uGraph.status = zeros(1,uGraph.numVertices);
            uGraph.parent = -1*ones(1,uGraph.numVertices);
            uGraph.dist = Inf*ones(1,uGraph.numVertices);
            uGraph.dTime = zeros(1,uGraph.numVertices);
            uGraph.fTime = zeros(1,uGraph.numVertices);
        end
        
        % Merge vertices according to the map of vertices
        function mergeVer_2(uGraph, vMap)
            V_new = unique(vMap);
            n_V_new = size(V_new,2);
            isoVerArray = [];
            resVerArray = [];
            numIsoVer = 0;
            % Merge vertices
            for idx = 1:n_V_new
                merge_V = find(vMap==V_new(idx));
                %
                resVerArray = [resVerArray,merge_V(1)];
                isoVerArray = [isoVerArray,merge_V(2:end)];
                numIsoVer = numIsoVer+size(merge_V,2)-1;
                %
                cur_ver = uGraph.adjList(merge_V(1)).first;
                while ~isempty(cur_ver)
                    next_ver = cur_ver.link;
                    if ~isempty(find(merge_V==cur_ver.data,1))
                        uGraph.deleteEdge(merge_V(1),cur_ver.data);
                    end
                    cur_ver = next_ver;
                end
                %
                for k = 2:size(merge_V,2)
                    cur_ver = uGraph.adjList(merge_V(k)).first;
                    while ~isempty(cur_ver)
                        next_ver = cur_ver.link;
                        if ~isempty(find(merge_V==cur_ver.data,1))
                            uGraph.deleteEdge(merge_V(k),cur_ver.data);
                        else
                            uGraph.addEdge(merge_V(1),cur_ver.data);
                            uGraph.deleteEdge(merge_V(k),cur_ver.data);
                        end
                        cur_ver = next_ver;
                    end
                end
            end
            % Modify indexes of vertices
            for idx = 1:uGraph.numVertices
                cur_ver = uGraph.adjList(idx).first;
                while ~isempty(cur_ver)
                    cur_ver.data = vMap(cur_ver.data);
                    cur_ver = cur_ver.link;
                end
            end
            % Delete isolated vertices
            % Free memory
            for idx = 1 : numIsoVer
                uGraph.adjList(isoVerArray(idx)).delete(); 
            end
            % Delete from adjacency list
            resVerArray = unique(resVerArray);
            for idx = 1 : size(resVerArray,2)
                uGraph.adjList(idx) = uGraph.adjList(resVerArray(idx));
            end
            uGraph.adjList = uGraph.adjList(1:uGraph.numVertices-numIsoVer);
            
            % modify the number of vertices
            uGraph.numVertices = uGraph.numVertices - numIsoVer;
            
            % modify the length of other properties
            uGraph.status = zeros(1,uGraph.numVertices);
            uGraph.parent = -1*ones(1,uGraph.numVertices);
            uGraph.dist = Inf*ones(1,uGraph.numVertices);
            uGraph.dTime = zeros(1,uGraph.numVertices);
            uGraph.fTime = zeros(1,uGraph.numVertices);
        end
        
    end
    
end


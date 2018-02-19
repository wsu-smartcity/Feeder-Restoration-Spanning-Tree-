classdef LinkedBase < handle
    %LINKEDBASE is the basic class for all kinds of graphs
    
    properties
        % Basic properties for a Graph
        numVertices; % Number of vertices
        numEdges; % Number of edges
        adjList; % Adjacency list
        % Properties for the graph iterator
        iterPos; % An array of pointers (to linked-list iterators)
        % Properties for graph traveral
        source; % The source vertex
        status; % 0:not discovered; 1: discovered but not finished; 2: finished
        parent; % The parents of all vertices. -1: no parent
        dist; % The distance for the source to each vertex, for BFS
        time; % Use for timestamping in DFS
        dTime; % Timestamp array I for DFS, records when each vertex is first discovered 
        fTime; % Timestamp array II for DFS, records when the search finishes examing the
               % adjacency list of each vertex
    end
    
    methods
        % Constructor
        % Input: the number of vertices
        function bGraph = LinkedBase(nVer)
            if nargin == 0 % allow for the no argument case
                bGraph.numVertices = 0;
                bGraph.numEdges = 0;
                bGraph.adjList = [];
                bGraph.iterPos = [];
                bGraph.source = 0;
                bGraph.status = [];
                bGraph.parent = [];
                bGraph.dist = [];
                bGraph.time = 0;
                bGraph.dTime = [];
                bGraph.fTime = [];
            else
                bGraph.numVertices = nVer;
                bGraph.numEdges = 0;
                bGraph.adjList = [];
                for index = 1 : bGraph.numVertices
                    bGraph.adjList = [bGraph.adjList Chain()];
                end
                bGraph.iterPos = [];
                bGraph.source = 0;
                bGraph.status = zeros(1,bGraph.numVertices);
                bGraph.parent = -1*ones(1,bGraph.numVertices);
                bGraph.dist = Inf*ones(1,bGraph.numVertices);
                bGraph.time = 0;
                bGraph.dTime = zeros(1,bGraph.numVertices);
                bGraph.fTime = zeros(1,bGraph.numVertices);
            end
        end
        
        % Destructor
        function delete(bGraph)
            % delete all elements in the adjacency list
            bGraph.detAllVer();
        end
        
        % Delete all elements in the adjacency list
        function detAllVer(bGraph)
            if bGraph.numVertices ~= 0
                for index = 1 : bGraph.numVertices
                    delete(bGraph.adjList(index));
                end
                bGraph.numVertices = 0;
                bGraph.numEdges = 0;
                bGraph.adjList = [];
                bGraph.iterPos = [];
                bGraph.source = 0;
                bGraph.status = [];
                bGraph.parent = [];
                bGraph.dist = [];
                bGraph.time = 0;
                bGraph.dTime = [];
                bGraph.fTime = [];
            end
        end
        
        % Return the number of vertices
        function num = getVerNum(bGraph)
            num = bGraph.numVertices;
        end
        
        % Return the number of edges
        function num = getEdgNum(bGraph)
            num = bGraph.numEdges;
        end
        
        % Return the out degree of the given vertex
        function outDeg = getOutDeg(bGraph, index)
            if index < 1 || index > bGraph.numVertices
                error('Error: The vertex Number is out of boundary!');
            end
            outDeg = getLength(bGraph.adjList(index));
        end
        
        % Initialize 'iterPos'
        function initializePos(bGraph)
            bGraph.iterPos = [];
            for index = 1 : bGraph.numVertices
                bGraph.iterPos = [bGraph.iterPos, ChainIterator()];
            end
        end
        
        % delete 'iterPos'
        function deactivePos(bGraph)
            for index = 1 : bGraph.numVertices
                delete(bGraph.iterPos(index));
            end
            bGraph.iterPos = [];
        end
        
        % Return the first vertex that is connected to the given vertex
        function fVertex = beginVertex(bGraph, index)
            if index < 1 || index > bGraph.numVertices
                error('Error: The vertex Number is out of boundary!');
            end
            fVertex = bGraph.iterPos(index).initialize(bGraph.adjList(index));
        end
        
        % Retrun the next vertex that is connected to the given vertex
        function nVertex = nextVertex(bGraph, index)
            if index < 1 || index > bGraph.numVertices
                error('Error: The vertex Number is out of boundary!');
            end
            nVertex = bGraph.iterPos(index).next();
        end
        
        % Breath-first search
        function BFS(bGraph, s) % s: the source vertex
            % Intialization
            for index = 1:bGraph.numVertices
                bGraph.status(index) = 0;
                bGraph.parent(index) = -1;
                bGraph.dist(index) = Inf;
            end
            bGraph.source = s;
            bGraph.status(s) = 1;
            bGraph.dist(s) = 0;
            % Use the queue to manager vertices whose status is '1'
            Q = LinkedQueue();
            Q.enQueue(s);
            % Initialize the iterator
            bGraph.initializePos();
            % Search process
            while ~isempty(Q)
                u = Q.deQueue();
                v = bGraph.beginVertex(u);
                while ~isempty(v)
                    if bGraph.status(v) == 0 % v has not been discovered yet
                        bGraph.status(v) = 1;
                        bGraph.dist(v) = bGraph.dist(u) + 1;
                        bGraph.parent(v) = u;
                        Q.enQueue(v);
                    end
                    v = bGraph.nextVertex(u);
                end
                bGraph.status(u) = 2;
            end
            % Deactive the iterator
            bGraph.deactivePos();
        end
        
        % Depth-first search I: create a depth-first forest
        function DFS1(bGraph)
            % Initialization
            for index = 1:bGraph.numVertices
                bGraph.status(index) = 0;
                bGraph.parent(index) = -1;
            end
            bGraph.time = 0;
            % Initialize the iterator
            bGraph.initializePos();
            % Search from each vertex that is not discovered
            for u = 1:bGraph.numVertices
                if bGraph.status(u) == 0
                    bGraph.DFSVisit(u);
                end
            end
            % Deactive the iterator
            bGraph.deactivePos();
        end
        
        % Depth-first search II: create a depth-first tree with a specified root.
        % Only for a connected graph.
        function DFS2(bGraph,s)
            % Initialization
            for index = 1:bGraph.numVertices
                bGraph.status(index) = 0;
                bGraph.parent(index) = -1;
            end
            bGraph.time = 0;
            % Initialize the iterator
            bGraph.initializePos();
            % Search from the source
            bGraph.source = s;
            bGraph.DFSVisit(s);
            % Deactive the iterator
            bGraph.deactivePos();
        end
        
        function DFSVisit(bGraph, u) % u is a vertex
            bGraph.status(u) = 1; % While vertex 'u' has just been discovered.
            bGraph.time = bGraph.time + 1;
            bGraph.dTime(u) = bGraph.time;
            v = bGraph.beginVertex(u);
            while ~isempty(v) % Explore eage (u, v)
                if bGraph.status(v) == 0
                    bGraph.parent(v) = u;
                    bGraph.DFSVisit(v);
                end
                v = bGraph.nextVertex(u);
            end
            bGraph.status(u) = 2; % Finished
            bGraph.time = bGraph.time + 1;
            bGraph.fTime(u) = bGraph.time;
        end
        
        % Print the path between the source and a given vertex
        % Need to run graph traveral (BFS or DFS) first
        function printPath(bGraph, vIndex)
            bGraph.printPathRec(vIndex);
            fprintf('\n');
        end
        
        function printPathRec(bGraph, vIndex)
            if vIndex == bGraph.source
                fprintf('%d ', bGraph.source);
            else
                if bGraph.parent(vIndex) == -1
                    fprintf(['No path from ',num2str(bGraph.source),...
                        ' to ',num2str(vIndex),' exists!']);
                else
                    bGraph.printPathRec(bGraph.parent(vIndex));
                    fprintf('%d ', vIndex);
                end
            end
        end
        
        % Copy graph: make graph2 a copy of graph1 
        % Only the number of vertices and edges, and adjacency list are copied
        % Properties for the graph iterator and graph traveral will not be copied
        function copy(graph2, graph1)
            graph2.detAllVer();
            % add vertices without edges
            graph2.addAIsoVer(graph1.numVertices)
            graph2.numEdges = graph1.numEdges;
            % copy adjacency list
            for idx = 1 : graph2.numVertices
                graph2.adjList(idx).copy(graph1.adjList(idx));
            end
        end
        
        % add n isolated vertice into a graph
        function addAIsoVer(bGraph, n)
            bGraph.numVertices = bGraph.numVertices + n;
            for idx = 1 : n
                bGraph.adjList = [bGraph.adjList Chain()];
            end
            bGraph.iterPos = [];
            bGraph.source = 0;
            bGraph.status = zeros(1,bGraph.numVertices);
            bGraph.parent = -1*ones(1,bGraph.numVertices);
            bGraph.dist = Inf*ones(1,bGraph.numVertices);
            bGraph.time = 0;
            bGraph.dTime = zeros(1,bGraph.numVertices);
            bGraph.fTime = zeros(1,bGraph.numVertices);
        end
        
    end
    
end


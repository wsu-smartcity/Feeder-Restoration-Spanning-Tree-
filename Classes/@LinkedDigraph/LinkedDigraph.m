classdef LinkedDigraph < LinkedBase
    % LINKEDDIGRAPH is the class for directed graphs,
    % which are present by adjacency lists.
    
    methods
        % Constructor
        function diGraph = LinkedDigraph(nVer)
            if nargin == 0 % allow for the no argument case
                nVer = 0;
            end
            diGraph = diGraph@LinkedBase(nVer);
        end

        % Decide whether the edge <i, j> exists in the graph
        % If it exists, return 1; otherwise, return 0.
        function flag = isEdgeExisting(diGraph, iIndex, jIndex)
            if iIndex < 1 || jIndex < 1 || iIndex > diGraph.numVertices ...
                    || jIndex > diGraph.numVertices
                error('Error: The vertex Number(s) is(are) out of boundary!');
            else
                if diGraph.adjList(iIndex).search(jIndex) == 0
                    flag = 0;
                else
                    flag = 1;
                end
            end
        end
        
        % Add a new edge into the graph
        function addEdge(diGraph, iIndex, jIndex)
            if iIndex < 1 || jIndex < 1 || iIndex > diGraph.numVertices ...
                    || jIndex > diGraph.numVertices
                error('Error: The vertex Number(s) is(are) out of boundary!');
            end
            if iIndex == jIndex
                error('Error: Two vertexs of an edge can not be the same!');
            end
            if diGraph.isEdgeExisting(iIndex, jIndex) == 1
                error('Error: Can not add an edge that is already existing!');
            end
            diGraph.adjList(iIndex).addNode(0, jIndex);
            diGraph.numEdges = diGraph.numEdges + 1;
        end
        
        % Delete an edge from the graph
        function deleteEdge(diGraph, iIndex, jIndex)
            if iIndex < 1 || jIndex < 1 || iIndex > diGraph.numVertices ...
                    || jIndex > diGraph.numVertices
                error('Error: The vertex Number(s) is(are) out of boundary!');
            end
            diGraph.adjList(iIndex).deleteNode(jIndex);
            diGraph.numEdges = diGraph.numEdges - 1;
        end
        
        % Return the in degree of the given vertex
        function inDeg = getInDeg(diGraph, index)
            if index < 1 || index > diGraph.numVertices
                error('Error: The vertex Number is out of boundary!');
            end
            inDeg = 0;
            for curIndex = 1 : diGraph.numVertices
                if diGraph.adjList(curIndex).search(index) ~= 0
                    inDeg = inDeg + 1;
                end
            end
        end
        
        % Return the out degree of a given vertex
        function outDeg = getOutDeg(diGraph, index)
            outDeg = diGraph.getOutDeg@LinkedBase(index);
        end
        
    end
    
end


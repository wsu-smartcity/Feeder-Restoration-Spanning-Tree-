classdef Chain < handle
    %CHAIN is a linked list
    
    properties
        first; % the first node of the linked list
        last; % the last node of the linked list
    end
    
    methods
        % Constructor
        function linkedlist = Chain()
            linkedlist.first = [];
            linkedlist.last = [];
        end
        
        % Distructor
        function delete(llist)
            % delete all nodes
            llist.detAllNodes();
        end
        
        % delete all nodes of a linked list
        function detAllNodes(llist)
            while ~isempty(llist.first)
               next = llist.first.link;
               delete(llist.first);
               llist.first = next;
            end
            llist.first = [];
            llist.last = [];
        end
        
        % If the linked list is empty, return 1; else, return 0
        function flag = isempty(llist)
            if isempty(llist.first)
                flag = 1;
            else
                flag = 0;
            end
        end
        
        % Return the length of the linked list
        function length = getLength(llist)
            length = 0;
            currentNode = llist.first;
            while ~isempty(currentNode)
                length = length + 1;
                currentNode = currentNode.link;
            end
        end
         
        % Seach the linked list for a given data
        % If it is found, return the index of the first fould node
        % If it can not be found, return 0
        function index = search(llist, sData)
            index = 1;
            currentNode = llist.first;
            while ~isempty(currentNode) && currentNode.data ~= sData
                currentNode = currentNode.link;
                index = index + 1;
            end
            if isempty(currentNode)
                % disp('Warning: The given data is not found in the linked list!!');
                index = 0;
            end
        end
        
        % Modify a node data
        % Only the fisrt found data is modified
        % if oldData is found, modify it and return 1
        % if oldData is not found, do nothing and return 0;
        function flag = modify(llist, oldData, newData)
            currentNode = llist.first;
            while ~isempty(currentNode) && currentNode.data ~= oldData
                currentNode = currentNode.link;
            end
            % if oldData is found
            if ~isempty(currentNode) && currentNode.data == oldData
                currentNode.data = newData;
                flag = 1;
            end
            % if oldData is not found
            if isempty(currentNode)
                % disp('Warning: The old data is not found in the linked list!!');
                flag = 0;
            end
        end
        
        % Add a new node after the kth node in the linked list
        % If k is out of boundary, do nothing
        % If k == 0, at the new node as the first nodes
        function addNode(llist, kIndex, newData)
            % Out of bourndary
            if kIndex < 0
                error('Error: The index is out of boundary!');
            end
            % Fine the kth node
            currentIndex = 1;
            currentNode = llist.first;
            while currentIndex < kIndex && ~isempty(currentNode)
                currentIndex = currentIndex + 1;
                currentNode = currentNode.link;
            end
            % Out of bourndary
            if kIndex > 0 && isempty(currentNode)
                error('Error: The index is out of boundary!');
            end
            % Insert new node
            newNode = ChainNode();
            newNode.data = newData;
            if kIndex > 0
                newNode.link = currentNode.link;
                currentNode.link = newNode;
            else
                newNode.link = llist.first;
                llist.first = newNode;
            end
            if isempty(newNode.link)
                llist.last = newNode;
            end
        end
        
        % Given a data, delete the first found node with the data
        % in the linked list.
        % If the data does not exist,do nothing.
        function deleteNode(llist, dData)
            currentNode = llist.first;
            trail = []; % the node before currentNode
            while ~isempty(currentNode) && currentNode.data ~= dData
                trail = currentNode;
                currentNode = currentNode.link;
            end
            if isempty(currentNode) % nothing has been found
                error('Error: The data can not be found!')
            end
            % If a node with the given data is found, delete it.
            if ~isempty(trail)
                trail.link = currentNode.link;
            else
                llist.first = currentNode.link;
            end
            if isempty(currentNode.link)
                llist.last = trail;
            end
            delete(currentNode);
        end
        
        % Print all the data of the node in the linked list in sequence
        function printData(llist)
            if isempty(llist)
                disp('It is an empty linked list!!');
                return;
            end
            allNodes = [];
            currentNode = llist.first;
            while ~isempty(currentNode)
                allNodes = [allNodes currentNode.data];
                currentNode = currentNode.link;
            end
            disp(allNodes);
        end
        
        % Make llist2 a copy of llist1
        function copy(llist2, llist1)
            % delete all nodes in llist2
            if ~isempty(llist2.first)
                llist2.detAllNodes();
            end
            % copy nodes
            curNode = llist1.first();
            while ~isempty(curNode)
                llist2.append(curNode.data);
                curNode = curNode.link;
            end
        end
        
        % Add a new node at the end of the llist
        function append(llist,newData)
            newNode = ChainNode();
            newNode.data = newData;
            if ~isempty(llist.first)
                llist.last.link = newNode;
                llist.last = newNode;
            else
                llist.first = newNode;
                llist.last = newNode;
            end
        end
        
    end
    
end


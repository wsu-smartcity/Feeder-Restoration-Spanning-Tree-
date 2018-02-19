classdef ChainIterator < handle
    %CHAINITERATOR is used to traverse a linked list
    
    properties
        location; % A pointer to a node of a linked list
    end
    
    methods
        % Initialize the iterator
        function nData = initialize(cIter, lList)
            cIter.location = lList.first;
            if ~isempty(cIter.location)
                nData = cIter.location.data;
            else
                nData = [];
            end
        end
        
        % Move the pointer to the next node
        function nData = next(cIter)
            if isempty(cIter.location)
                nData = [];
                return;
            end
            cIter.location = cIter.location.link;
            if ~isempty(cIter.location)
                nData = cIter.location.data;
            else
                nData = [];
            end
        end
    end
    
end


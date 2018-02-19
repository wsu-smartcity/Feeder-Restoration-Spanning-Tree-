classdef LinkedQueue < Chain
    %LINKEDQUEUE is a queue, which is represented by a linked list
    
    methods
        % Add a new node at the end of the queue
        function enQueue(lQueue,newData)
            newNode = ChainNode();
            newNode.data = newData;
            if ~isempty(lQueue.first)
                lQueue.last.link = newNode;
                lQueue.last = newNode;
            else
                lQueue.first = newNode;
                lQueue.last = newNode;
            end
        end
        
        % Delete the first node of the queue and return its data
        function fData = deQueue(lQueue)
            if lQueue.isempty() == 1
                error('Error: The queue is emtpy!');
            end
            fData = lQueue.first.data;
            tempNode = lQueue.first;
            lQueue.first = lQueue.first.link;
            delete(tempNode);
        end
        
    end
    
end


classdef dataLoader
    methods (Static)
        function data = loadCSV(filename)
            % read the csv file
            data = readtable(filename);
            % Basic validation
            if ~ismember('time_sn', data.Properties.VariableNames)
                error('Invalid CSV: missing "time_sn" column');
            end
        end
    end
end

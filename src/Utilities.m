classdef Utilities
    methods (Static)
        function success = validateCSVFile(filename)
            try
                data = readtable(filename);
                required = {'time_s', 'ax_m_s2', 'ay_m_s2', 'az_m_s2', 'p_rad_s', 'q_rad_s', 'r_rad_s'};
                success = all(ismember(required, data.Properties.VariableNames)) && height(data) >= 2;
            catch, success = false; end
        end
        
        function data = cleanData(data)
            % Supprimer les lignes avec NaN dans les colonnes critiques
            critical = {'time_s', 'ax_m_s2', 'ay_m_s2', 'az_m_s2', 'tas_m_s'};
            validRows = all(~isnan(table2array(data(:, intersect(critical, data.Properties.VariableNames))), 2);
            data = data(validRows, :);
        end
    end
end
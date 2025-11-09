classdef FlightDataManager < handle
    properties
        RawData table
        CalculatedData struct
        CurrentFile string
        ReferenceLLA double
        Units string = 'SI'
    end
    
    properties (Constant)
        CMAC = 0.19, Wingspan = 0.55, WingArea = 0.55, g = 9.80665
    end
    
    methods
        function obj = FlightDataManager()
            obj.CalculatedData = struct();
        end
        
        function success = loadData(obj, filename)
            try
                obj.RawData = readtable(filename);
                obj.CurrentFile = filename;
                obj.ReferenceLLA = [obj.RawData.lat_rad(1), obj.RawData.lon_rad(1), obj.RawData.alt_m(1)];
                
                fprintf('Data loaded successfully: %s\n', filename);
                fprintf('Rows: %d, Columns: %d\n', height(obj.RawData), width(obj.RawData));
                fprintf('Variables: %s\n', strjoin(obj.RawData.Properties.VariableNames, ', '));
                
                % EXÉCUTER LES CALCULS
                fprintf('Executing calculations...\n');
                obj.calculateAll();
                fprintf('Calculations completed.\n');
                
                % Afficher les variables calculées
                if ~isempty(obj.CalculatedData)
                    calcVars = fieldnames(obj.CalculatedData);
                    fprintf('Calculated variables: %s\n', strjoin(calcVars, ', '));
                end
                
                success = true;
            catch ME
                fprintf('ERROR loading data: %s\n', ME.message);
                success = false;
            end
        end
        
        function calculateAll(obj)
            obj.quaternionToEuler();
            obj.convertLLAtoNED();
            obj.calculateBodyVelocity();
            obj.calculateCoefficients();
            obj.calculateAerodynamicForces();
        end
        
        function quaternionToEuler(obj)
            q = [obj.RawData.quat_e0, obj.RawData.quat_ex, obj.RawData.quat_ey, obj.RawData.quat_ez];
            eul = quat2eul(q, 'ZYX');
            obj.CalculatedData.yaw_rad = eul(:,1)';
            obj.CalculatedData.pitch_rad = eul(:,2)';
            obj.CalculatedData.roll_rad = eul(:,3)';
        end
        
        function convertLLAtoNED(obj)
            lat0 = obj.ReferenceLLA(1); lon0 = obj.ReferenceLLA(2); alt0 = obj.ReferenceLLA(3);
            R = 6378137;
            obj.CalculatedData.north_m = (obj.RawData.lat_rad - lat0) * R;
            obj.CalculatedData.east_m = (obj.RawData.lon_rad - lon0) * R * cos(lat0);
            obj.CalculatedData.down_m = -(obj.RawData.alt_m - alt0);
        end
        
        function calculateBodyVelocity(obj)
            tas = obj.RawData.tas_m_s; alpha = obj.RawData.alpha_rad; beta = obj.RawData.beta_rad;
            obj.CalculatedData.u_m_s = tas .* cos(alpha) .* cos(beta);
            obj.CalculatedData.v_m_s = tas .* sin(beta);
            obj.CalculatedData.w_m_s = tas .* sin(alpha) .* cos(beta);
        end
        
        function calculateCoefficients(obj)
            rho = obj.calculateAirDensity();
            q = 0.5 * rho .* obj.RawData.tas_m_s.^2;
            S = obj.WingArea;
            
            obj.CalculatedData.CL = (obj.RawData.mass_kg .* obj.RawData.az_m_s2 + obj.RawData.mass_kg * obj.g) ./ (q * S);
            obj.CalculatedData.CD = (obj.RawData.mass_kg .* obj.RawData.ax_m_s2 - obj.RawData.thrust_N) ./ (q * S);
            obj.CalculatedData.CY = (obj.RawData.mass_kg .* obj.RawData.ay_m_s2) ./ (q * S);
        end
        
        function calculateAerodynamicForces(obj)
            rho = obj.calculateAirDensity();
            q = 0.5 * rho .* obj.RawData.tas_m_s.^2;
            S = obj.WingArea;
            obj.CalculatedData.Lift_N = q * S .* obj.CalculatedData.CL;
            obj.CalculatedData.Drag_N = q * S .* obj.CalculatedData.CD;
            obj.CalculatedData.SideForce_N = q * S .* obj.CalculatedData.CY;
        end
        
        function rho = calculateAirDensity(obj)
            alt = obj.RawData.alt_m;
            [~, ~, rho] = atmoscoesa(alt);
        end
        
        function data = getDataForPlotting(obj, variableName)
            try
                fprintf('getDataForPlotting: searching for "%s"\n', variableName);
                
                % Vérifier d'abord dans RawData
                if ismember(variableName, obj.RawData.Properties.VariableNames)
                    data = obj.RawData.(variableName);
                    fprintf('SUCCESS: Found "%s" in RawData, length: %d\n', variableName, length(data));
                    
                % Vérifier ensuite dans CalculatedData
                elseif isfield(obj.CalculatedData, variableName)
                    data = obj.CalculatedData.(variableName);
                    fprintf('SUCCESS: Found "%s" in CalculatedData, length: %d\n', variableName, length(data));
                    
                else
                    fprintf('ERROR: Variable "%s" not found in RawData or CalculatedData\n', variableName);
                    fprintf('RawData variables: %s\n', strjoin(obj.RawData.Properties.VariableNames, ', '));
                    if ~isempty(obj.CalculatedData)
                        fprintf('CalculatedData variables: %s\n', strjoin(fieldnames(obj.CalculatedData), ', '));
                    end
                    
                    error('Variable "%s" not found in dataset', variableName);
                end
                
                % Appliquer la conversion d'unités
                data = obj.convertUnits(data, variableName);
                
            catch ME
                fprintf('CRITICAL ERROR in getDataForPlotting for "%s": %s\n', variableName, ME.message);
                rethrow(ME);
            end
        end
        
        function data = convertUnits(obj, data, varName)
            if strcmp(obj.Units, 'Aviation')
                if endsWith(varName, {'_rad', '_rad_s'})
                    data = rad2deg(data);
                elseif endsWith(varName, '_m')
                    data = data * 3.28084; % m to feet
                elseif endsWith(varName, '_m_s')
                    data = data * 1.94384; % m/s to knots
                end
            end
        end
        
        function unit = getUnit(obj, varName)
            if strcmp(obj.Units, 'Aviation')
                if endsWith(varName, {'_rad', '_rad_s'}), unit = 'deg';
                elseif endsWith(varName, '_m'), unit = 'ft';
                elseif endsWith(varName, '_m_s'), unit = 'kts';
                else, unit = ''; end
            else
                if endsWith(varName, '_rad'), unit = 'rad';
                elseif endsWith(varName, '_rad_s'), unit = 'rad/s';
                elseif endsWith(varName, '_m'), unit = 'm';
                elseif endsWith(varName, '_m_s'), unit = 'm/s';
                elseif endsWith(varName, '_m_s2'), unit = 'm/s²';
                elseif endsWith(varName, '_N'), unit = 'N';
                else, unit = ''; end
            end
        end
    end
end
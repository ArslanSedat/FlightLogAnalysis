classdef FlightDataManager < handle
    % FlightDataManager
    % =================
    % This class handles flight data loading, conversion, and
    % aerodynamic calculations for the Flight Log Analysis Application.
    %
    % Author: Sedat ARSLAN
    % Date: November 2025

    properties
        RawData table                 % Raw flight log data
        CalculatedData struct         % Struct containing computed parameters
        CurrentFile string            % Path to the current data file
        ReferenceLLA double           % Reference Latitude, Longitude, Altitude
        Units string = 'SI'           % Unit system (
    end

    properties (Constant)
        % Aircraft constants
        CMAC = 0.19                   % Mean Aerodynamic Chord [m]
        Wingspan = 0.55               % Wingspan [m]
        WingArea = 0.55               % Wing area [m²]
        g = 9.80665                   % Gravitational acceleration [m/s²]
    end

    methods
        function obj = FlightDataManager()
            % Constructor: Initialize empty calculation structure
            obj.CalculatedData = struct();
        end

        function success = loadData(obj, filename)
            % Load flight data from file and compute all derived variables.
            try
                obj.RawData = readtable(filename);
                obj.CurrentFile = filename;

                % Reference point for coordinate conversion (first data point)
                obj.ReferenceLLA = [obj.RawData.lat_rad(1), ...
                                    obj.RawData.lon_rad(1), ...
                                    obj.RawData.alt_m(1)];

                % Compute derived quantities
                obj.calculateAll();
                success = true;
            catch
                success = false;
            end
        end

        function calculateAll(obj)
            % Execute all data processing steps sequentially
            obj.quaternionToEuler();
            obj.convertLLAtoNED();
            obj.calculateBodyVelocity();
            obj.calculateCoefficients();
            obj.calculateAerodynamicForces();
        end

        function quaternionToEuler(obj)
            % Convert quaternion orientation to Euler angles (yaw, pitch, roll)
            q = [obj.RawData.quat_e0, obj.RawData.quat_ex, ...
                 obj.RawData.quat_ey, obj.RawData.quat_ez];
            eul = quat2eul(q, 'ZYX');

            obj.CalculatedData.yaw_rad   = eul(:, 1)';
            obj.CalculatedData.pitch_rad = eul(:, 2)';
            obj.CalculatedData.roll_rad  = eul(:, 3)';
        end

        function convertLLAtoNED(obj)
            % Convert Latitude, Longitude, Altitude to NED (North-East-Down)
            lat0 = obj.ReferenceLLA(1);
            lon0 = obj.ReferenceLLA(2);
            alt0 = obj.ReferenceLLA(3);
            R = 6378137; % Earth radius [m]

            obj.CalculatedData.north_m = (obj.RawData.lat_rad - lat0) * R;
            obj.CalculatedData.east_m  = (obj.RawData.lon_rad - lon0) * R * cos(lat0);
            obj.CalculatedData.down_m  = -(obj.RawData.alt_m - alt0);
        end

        function calculateBodyVelocity(obj)
            % Compute body-axis velocity components from TAS, alpha, and beta
            tas = obj.RawData.tas_m_s;
            alpha = obj.RawData.alpha_rad;
            beta = obj.RawData.beta_rad;

            obj.CalculatedData.u_m_s = tas .* cos(alpha) .* cos(beta);
            obj.CalculatedData.v_m_s = tas .* sin(beta);
            obj.CalculatedData.w_m_s = tas .* sin(alpha) .* cos(beta);
        end

        function calculateCoefficients(obj)
            % Compute aerodynamic coefficients (CL, CD, CY)
            rho = obj.calculateAirDensity();
            q = 0.5 * rho .* obj.RawData.tas_m_s.^2; % Dynamic pressure
            S = obj.WingArea;

            obj.CalculatedData.CL = (obj.RawData.mass_kg .* obj.RawData.az_m_s2 ...
                                     + obj.RawData.mass_kg * obj.g) ./ (q * S);

            obj.CalculatedData.CD = (obj.RawData.mass_kg .* obj.RawData.ax_m_s2 ...
                                     - obj.RawData.thrust_N) ./ (q * S);

            obj.CalculatedData.CY = (obj.RawData.mass_kg .* obj.RawData.ay_m_s2) ./ (q * S);
        end

        function calculateAerodynamicForces(obj)
            % Compute aerodynamic forces (Lift, Drag, SideForce)
            rho = obj.calculateAirDensity();
            q = 0.5 * rho .* obj.RawData.tas_m_s.^2;
            S = obj.WingArea;

            obj.CalculatedData.Lift_N      = q * S .* obj.CalculatedData.CL;
            obj.CalculatedData.Drag_N      = q * S .* obj.CalculatedData.CD;
            obj.CalculatedData.SideForce_N = q * S .* obj.CalculatedData.CY;
        end

        function rho = calculateAirDensity(obj)
            % Calculate air density from altitude using standard atmosphere
            alt = obj.RawData.alt_m;
            [~, ~, rho] = atmoscoesa(alt);
        end

        function data = getDataForPlotting(obj, variableName)
            % Retrieve variable for plotting from RawData or CalculatedData
            if ismember(variableName, obj.RawData.Properties.VariableNames)
                data = obj.RawData.(variableName);
            elseif isfield(obj.CalculatedData, variableName)
                data = obj.CalculatedData.(variableName);
            else
                data = [];
            end

            % Apply unit conversion if required
            data = obj.convertUnits(data, variableName);
        end

        function data = convertUnits(obj, data, varName)
            % Convert data to aviation units if selected
            if strcmp(obj.Units, 'Aviation')
                if endsWith(varName, {'_rad', '_rad_s'})
                    data = rad2deg(data); % radians to degrees
                elseif endsWith(varName, '_m')
                    data = data * 3.28084; % meters to feet
                elseif endsWith(varName, '_m_s')
                    data = data * 1.94384; % m/s to knots
                end
            end
        end

        function unit = getUnit(obj, varName)
            % Return the display unit for a given variable name
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

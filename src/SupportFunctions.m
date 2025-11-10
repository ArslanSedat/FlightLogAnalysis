classdef SupportFunctions
    methods (Static)
           
        % Create new figure with panner and add to entity tree
        function createNewFigure(app)
            try
                figId = app.NextFigureId;
                app.NextFigureId = app.NextFigureId + 1;
                
                % Create tab group if it doesn't exist
                if isempty(app.TabGroup) || ~isvalid(app.TabGroup)
                    app.TabGroup = uitabgroup(app.GridLayout);
                    app.TabGroup.Layout.Row = [1 3];
                    app.TabGroup.Layout.Column = 2;
                end
                
                % Create new tab and grid layout
                newTab = uitab(app.TabGroup, 'Title', sprintf('Figure %d', figId));
                gridLayout = uigridlayout(newTab, [3, 2]);
                gridLayout.RowHeight = {'1x', '1x', '0.3x'};  % Panner dimension
                gridLayout.ColumnWidth = {'1x', '1x'};
                
                % Create panner axes
                pannerAxes = uiaxes(gridLayout);
                pannerAxes.Layout.Row = 3;
                pannerAxes.Layout.Column = [1, 2];
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag bars to change view';
                pannerAxes.Visible = app.PannerVisible;
                grid(pannerAxes, 'on');
                
                % figure structure
                newFigure = struct(...
                    'Id', figId, ...
                    'Tab', newTab, ...
                    'GridLayout', gridLayout, ...
                    'Axes', struct(), ...
                    'Panner', pannerAxes, ...
                    'LeftBar', [], ...
                    'RightBar', [], ...
                    'FillArea', [], ...
                    'PannerTimeData', [], ...
                    'PannerAltData', [], ...
                    'DraggingBar', '', ...  % 'left', 'right', ou ''
                    'DragStartPoint', [] ...
                );
                
                app.Figures = [app.Figures, newFigure];
                figureIndex = length(app.Figures);
                
                % Initialize panner if data is loaded
                if ~isempty(app.CurrentData)
                    SupportFunctions.updatePannerData(app, figureIndex);
                end
                
                figNode = uitreenode(app.Tree, 'Text', sprintf('Figure %d', figId));
                figNode.NodeData = struct('Type', 'Figure', 'Id', figId, 'Visible', true);
                app.Tree.SelectedNodes = figNode;
                app.SelectedNode = figNode;
                
                app.Label.Text = sprintf('Figure %d created', figId);
                
            catch ME
                fprintf('Error in createNewFigure: %s\n', ME.message);
                uialert(app.UIFigure, ME.message, 'Creation Error');
            end
        end
        
        % Update panner with altitude and with draggable bars
        function updatePannerData(app, idx)
            if idx > length(app.Figures) || isempty(app.CurrentData), return; 
            end
            
            try
                pannerAxes = app.Figures(idx).Panner;
                dataManager = app.CurrentData;
                
                time = dataManager.getDataForPlotting('time_sn');
                altitude = dataManager.getDataForPlotting('alt_m');
                
                % Clean axes
                cla(pannerAxes);
                
                plot(pannerAxes, time, altitude, 'k-', 'LineWidth', 1);
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag bars to change view';
                grid(pannerAxes, 'on');
                
                % Set Y-axis
                yMin = min(altitude);
                yMax = max(altitude);
                yMargin = 0.05 * (yMax - yMin); 
                pannerAxes.YLim = [yMin - yMargin, yMax + yMargin];
                
                
                yLimits = pannerAxes.YLim;
                
                % Create draggable bars covering full time range
                xRange = range(time);
                viewWidth = xRange;  % remove
                leftPos = min(time);
                rightPos = max(time);
                
                hold(pannerAxes, 'on');
                
                % Create fill area between bars
                fillX = [leftPos, rightPos, rightPos, leftPos];
                fillY = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
                
                fillArea = fill(pannerAxes, fillX, fillY, [0.2, 0.6, 1.0], ...
                    'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
                    'HitTest', 'off', 'PickableParts', 'none');
                
                leftBar = plot(pannerAxes, [leftPos, leftPos], [yLimits(1), yLimits(2)], ...
                    'Color', [0.2, 0.6, 1.0], 'LineWidth', 4, ...
                    'Marker', 'none');
                
                rightBar = plot(pannerAxes, [rightPos, rightPos], [yLimits(1), yLimits(2)], ...
                    'Color', [0.2, 0.6, 1.0], 'LineWidth', 4, ...
                    'Marker', 'none');
                
                hold(pannerAxes, 'off');
                
                app.Figures(idx).LeftBar = leftBar;
                app.Figures(idx).RightBar = rightBar;
                app.Figures(idx).FillArea = fillArea;
                app.Figures(idx).PannerTimeData = time;
                app.Figures(idx).PannerAltData = altitude;
                app.Figures(idx).DraggingBar = '';
                
                SupportFunctions.setupPannerInteractions(app, idx);
                
                SupportFunctions.updateMainAxesFromPanner(app, idx);
                
            catch ME
                fprintf('Panner update error: %s\n', ME.message);
            end
        end

        % Update all axes based on panner time range
        function updateMainAxesFromPanner(app, idx)
            if idx > length(app.Figures) || ~isfield(app.Figures(idx), 'LeftBar'), return; end
            
            timeMin = app.Figures(idx).LeftBar.XData(1);
            timeMax = app.Figures(idx).RightBar.XData(1);
            
            % Update all axes in the figure
            if isfield(app.Figures(idx), 'Axes')
                axesFields = fieldnames(app.Figures(idx).Axes);
                for i = 1:length(axesFields)
                    axInfo = app.Figures(idx).Axes.(axesFields{i});
                    if isfield(axInfo, 'Handle') && isvalid(axInfo.Handle)
                        if strcmp(axInfo.Type, 'line')
                            % Line plots x limits
                            axInfo.Handle.XLim = [timeMin, timeMax];
                        else
                            % data by time
                            SupportFunctions.filterScatterByTime(app, idx, axesFields{i}, timeMin, timeMax);
                        end
                    end
                end
            end
        end

        % Add new axes to selected figure
        function addNewAxes(app, figId, type)
            if isempty(figId)
                uialert(app.UIFigure, 'Please select a FIGURE in the tree first.', 'No Figure Selected');
                return; 
            end
            
            if isempty(app.Figures)
                uialert(app.UIFigure, 'No figures exist. Create a figure first.', 'No Figures');
                return;
            end
            
            % Find figure in array
            figureIndex = [];
            for i = 1:length(app.Figures)
                if app.Figures(i).Id == figId
                    figureIndex = i;
                    break;
                end
            end
            
            if isempty(figureIndex)
                uialert(app.UIFigure, sprintf('Figure %d not found in app.Figures array', figId), 'Figure Not Found');
                return; 
            end
            
            disp(['Found Figure at index: ', num2str(figureIndex)]);
            
            axesId = app.NextAxesId;
            app.NextAxesId = app.NextAxesId + 1;
            
            gridLayout = app.Figures(figureIndex).GridLayout;
            
            [row, col] = SupportFunctions.findFreePosition(app, figureIndex);
            if isempty(row)
                uialert(app.UIFigure, 'No more space (max 4 axes).', 'Grid Full');
                return;
            end
            
            % Create new axis
            newAxes = uiaxes(gridLayout);
            newAxes.Layout.Row = row;
            newAxes.Layout.Column = col;
            newAxes.XLabel.String = 'Time (s)';
            newAxes.YLabel.String = 'Value';
            newAxes.Title.String = sprintf('%s Axes %d', type, axesId);
            grid(newAxes, 'on');
            
            % Stockage of new data
            if ~isfield(app.Figures(figureIndex), 'Axes') || isempty(fieldnames(app.Figures(figureIndex).Axes))
                app.Figures(figureIndex).Axes = struct();
            end
                    
            axFieldName = sprintf('axes%d', axesId);
            app.Figures(figureIndex).Axes.(axFieldName) = struct();
            app.Figures(figureIndex).Axes.(axFieldName).Handle = newAxes;
            app.Figures(figureIndex).Axes.(axFieldName).Type = type;
            app.Figures(figureIndex).Axes.(axFieldName).Variables = {};
            app.Figures(figureIndex).Axes.(axFieldName).Row = row;
            app.Figures(figureIndex).Axes.(axFieldName).Column = col;
            
            % Add to tree
            figNode = SupportFunctions.findTreeNode(app, sprintf('Figure %d', figId));
            if ~isempty(figNode)
                axesNode = uitreenode(figNode);
                axesNode.Text = sprintf('Axes %d (%s)', axesId, type);
                axesNode.NodeData = struct('Type', 'Axes', 'FigureId', figId, 'AxesId', axesId, 'Visible', true);
            end
            
            if ~isempty(app.CurrentData)
                SupportFunctions.configureAxesWithSampleData(app, figureIndex, axesId);
            else
                SupportFunctions.plotSampleData(newAxes, type);
            end
            
            drawnow;
            
            app.Label.Text = sprintf('Axes %d added to Figure %d', axesId, figId);
            disp(['SUCCESS: Axes ', num2str(axesId), ' created in Figure ', num2str(figId)]);
        end
        
        % Setup drag interactions for panner bars
        function setupPannerInteractions(app, idx)
            if idx > length(app.Figures), return; end
            
            pannerAxes = app.Figures(idx).Panner;
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            
            % Set button down functions for bars and background
            leftBar.ButtonDownFcn = @(src, event) SupportFunctions.startBarDrag(app, idx, 'left', src, event);
            rightBar.ButtonDownFcn = @(src, event) SupportFunctions.startBarDrag(app, idx, 'right', src, event);
            
            pannerAxes.ButtonDownFcn = @(src, event) SupportFunctions.startBackgroundDrag(app, idx, src, event);
        end
                
        % Handle bar dragging
        function duringBarDrag(app, idx, src, event)
            if idx > length(app.Figures) || isempty(app.Figures(idx).DraggingBar)
                return;
            end
            
            pannerAxes = app.Figures(idx).Panner;
            currentPoint = pannerAxes.CurrentPoint(1, 1);
            timeData = app.Figures(idx).PannerTimeData;
            
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            fillArea = app.Figures(idx).FillArea;
            
            minSeparation = 0.01 * range(timeData);
            
            if strcmp(app.Figures(idx).DraggingBar, 'left')
                % move left
                newX = currentPoint;
                newX = max(min(timeData), min(newX, rightBar.XData(1) - minSeparation));
                
                leftBar.XData = [newX, newX];
                
            elseif strcmp(app.Figures(idx).DraggingBar, 'right')
                % move right
                newX = currentPoint;
                newX = max(leftBar.XData(1) + minSeparation, min(newX, max(timeData)));
                
                rightBar.XData = [newX, newX];
            end
            
            % Update of new area
            yLimits = pannerAxes.YLim;
            fillArea.XData = [leftBar.XData(1), rightBar.XData(1), rightBar.XData(1), leftBar.XData(1)];
            fillArea.YData = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
            
            % Update of every axis components
            SupportFunctions.updateMainAxesFromPanner(app, idx);
            
            drawnow;
        end

        % End bar dragging
        function endBarDrag(app, idx, src, event)
            if idx > length(app.Figures), return; 
            end
            fprintf('Ending bar drag\n');
            if isfield(app.Figures(idx), 'LeftBar') && isvalid(app.Figures(idx).LeftBar)
                app.Figures(idx).LeftBar.Color = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'RightBar') && isvalid(app.Figures(idx).RightBar)
                app.Figures(idx).RightBar.Color = [0.2, 0.6, 1.0];
            end
            app.Figures(idx).DraggingBar = '';
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
        end
        
        % Delete figure and remove from tree
        function deleteFigure(app, figId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex)
                fprintf('Figure %d not found for deletion\n', figId);
                return;
            end
            
            % Delete tab and remove from structure
            if isvalid(app.Figures(figureIndex).Tab)
                delete(app.Figures(figureIndex).Tab);
            end
            
            app.Figures(figureIndex) = [];
            
            % Remove from entity tree
            figNode = SupportFunctions.findTreeNode(app, sprintf('Figure %d', figId));
            if ~isempty(figNode) && isvalid(figNode)
                delete(figNode);
            end
            
            app.Label.Text = sprintf('Figure %d deleted', figId);
        end
        
        % Delete axes and rebuild tree
        function deleteAxes(app, figId, axesId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex), return; end
            
            axFieldName = sprintf('axes%d', axesId);
            if isfield(app.Figures(figureIndex).Axes, axFieldName)
                delete(app.Figures(figureIndex).Axes.(axFieldName).Handle);
                app.Figures(figureIndex).Axes = rmfield(app.Figures(figureIndex).Axes, axFieldName);
                
                delete(app.Tree.Children);
                for i = 1:length(app.Figures)
                    figNode = uitreenode(app.Tree, 'Text', sprintf('Figure %d', app.Figures(i).Id));
                    if isfield(app.Figures(i), 'Axes')
                        axesFields = fieldnames(app.Figures(i).Axes);
                        for j = 1:length(axesFields)
                            axesInfo = app.Figures(i).Axes.(axesFields{j});
                            axesNode = uitreenode(figNode);
                            axesNode.Text = sprintf('Axes %d (%s)', str2double(regexp(axesFields{j}, '\d+', 'match')), axesInfo.Type);
                        end
                    end
                end
            end
        end

        % Find figure index by ID
        function figureIndex = findFigureIndex(app, figId)
            figureIndex = [];
            for i = 1:length(app.Figures)
                if app.Figures(i).Id == figId
                    figureIndex = i;
                    break;
                end
            end
        end

        % Update Panner
        function updatePannerVisibility(app)
            figIds = fieldnames(app.Figures);
            for i = 1:length(figIds)
                figId = str2double(figIds{i});
                if isfield(app.Figures, figId) && ~isempty(app.Figures(figId).Panner)
                    if app.PannerVisible
                        app.Figures(figId).Panner.Visible = 'on';
                    else
                        app.Figures(figId).Panner.Visible = 'off';
                    end
                end
            end
        end
        
        % Find free position in 2x2 grid
        function [row, col] = findFreePosition(app, figureIndex)
            % Available positions
            positions = [1,1; 1,2; 2,1; 2,2];
            
            % Return first position if no axes exist
            if figureIndex > length(app.Figures) || ~isfield(app.Figures(figureIndex), 'Axes')
                row = positions(1,1);
                col = positions(1,2);
                disp(['First axes - Position: (', num2str(row), ',', num2str(col), ')']);
                return;
            end
            
            % Check if axiss empty
            if isempty(fieldnames(app.Figures(figureIndex).Axes))
                row = positions(1,1);
                col = positions(1,2);
                disp(['First axes - Position: (', num2str(row), ',', num2str(col), ')']);
                return;
            end
            
            for i = 1:size(positions,1)
                row = positions(i,1);
                col = positions(i,2);
                occupied = false;
                
                axesFields = fieldnames(app.Figures(figureIndex).Axes);
                
                for j = 1:length(axesFields)
                    if isstruct(app.Figures(figureIndex).Axes.(axesFields{j})) && ...
                       isfield(app.Figures(figureIndex).Axes.(axesFields{j}), 'Handle') && ...
                       isfield(app.Figures(figureIndex).Axes.(axesFields{j}), 'Row') && ...
                       isfield(app.Figures(figureIndex).Axes.(axesFields{j}), 'Column')
                       
                        axHandle = app.Figures(figureIndex).Axes.(axesFields{j}).Handle;
                        axRow = app.Figures(figureIndex).Axes.(axesFields{j}).Row;
                        axCol = app.Figures(figureIndex).Axes.(axesFields{j}).Column;
                        
                        if isvalid(axHandle) && axRow == row && axCol == col
                            occupied = true;
                            break;
                        end
                    end
                end
                
                if ~occupied
                    disp(['Free position found: (', num2str(row), ',', num2str(col), ')']);
                    return;
                end
            end
            
            row = [];
            col = [];
            disp('No free positions found - grid is full');
        end
        
        % Configure axes with sample data from flight log
        function configureAxesWithSampleData(app, figId, axesId)
            if ~isfield(app.Figures, figId) || ~isfield(app.Figures(figId).Axes, axesId)
                return;
            end
            axesInfo = app.Figures(figId).Axes(axesId);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            cla(axesHandle);
            try
                time = dataManager.getDataForPlotting('time_sn');
                
                if strcmp(axesInfo.Type, 'line')
                    if ismember('ax_m_s2', dataManager.RawData.Properties.VariableNames)
                        yData = dataManager.getDataForPlotting('ax_m_s2');
                        plot(axesHandle, time, yData, 'b-', 'LineWidth', 1.5);
                        ylabel(axesHandle, sprintf('Acceleration X (%s)', dataManager.getUnit('ax_m_s2')));
                    end
                else
                    if ismember('ax_m_s2', dataManager.RawData.Properties.VariableNames) && ...
                       ismember('ay_m_s2', dataManager.RawData.Properties.VariableNames)
                        xData = dataManager.getDataForPlotting('ax_m_s2');
                        yData = dataManager.getDataForPlotting('ay_m_s2');
                        scatter(axesHandle, xData, yData, 'filled');
                        xlabel(axesHandle, sprintf('Acceleration X (%s)', dataManager.getUnit('ax_m_s2')));
                        ylabel(axesHandle, sprintf('Acceleration Y (%s)', dataManager.getUnit('ay_m_s2')));
                    end
                end
                
                title(axesHandle, sprintf('%s Plot - Real Data', axesInfo.Type));
                
            catch
                SupportFunctions.plotSampleData(axesHandle, axesInfo.Type);
            end
        end
        
        % Plot sample data when no flight data is loaded
        function plotSampleData(axesHandle, plotType)
            time = 0:0.1:10;
            
            if strcmp(plotType, 'line')
                plot(axesHandle, time, sin(time), 'b-', 'LineWidth', 1.5);
                title(axesHandle, 'Sample Line Plot - Load data');
            else
                scatter(axesHandle, time, randn(size(time)), 'filled');
                title(axesHandle, 'Sample Scatter Plot - Load data');
            end
            xlabel(axesHandle, 'Time (s)');
            ylabel(axesHandle, 'Amplitude');
            grid(axesHandle, 'on');
        end
        
        % Start bar dragging
        function startBarDrag(app, idx, barType, src, event)
            fprintf('Starting %s bar drag\n', barType);
            
            app.Figures(idx).DraggingBar = barType;
            app.Figures(idx).DragStartPoint = event.IntersectionPoint(1); % Position X only

            src.Color = [1.0, 0.3, 0.3]; % Red during drga
            
            app.UIFigure.WindowButtonMotionFcn = @(src, event) SupportFunctions.duringBarDrag(app, idx, src, event);
            app.UIFigure.WindowButtonUpFcn = @(src, event) SupportFunctions.endBarDrag(app, idx, src, event);
        end

        % Handle background click to move view
        function startBackgroundDrag(app, idx, src, event)
            fprintf('Starting background drag\n');
            
            currentPoint = event.IntersectionPoint(1);
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            timeData = app.Figures(idx).PannerTimeData;
            
            % Calculate current center and new
            currentCenter = (leftBar.XData(1) + rightBar.XData(1)) / 2;
            viewWidth = rightBar.XData(1) - leftBar.XData(1);
            
            % Apply boundaries
            newLeft = currentPoint - viewWidth / 2;
            newRight = currentPoint + viewWidth / 2;
            newLeft = max(min(timeData), newLeft);
            newRight = min(max(timeData), newRight);

            if newRight - newLeft < viewWidth
                if newLeft == min(timeData)
                    newRight = newLeft + viewWidth;
                else
                    newLeft = newRight - viewWidth;
                end
            end
            
            % Updates
            leftBar.XData = [newLeft, newLeft];
            rightBar.XData = [newRight, newRight];

            yLimits = app.Figures(idx).Panner.YLim;
            app.Figures(idx).FillArea.XData = [newLeft, newRight, newRight, newLeft];
            app.Figures(idx).FillArea.YData = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];

            SupportFunctions.updateMainAxesFromPanner(app, idx);
        end

        % Find tree node with the text
        function node = findTreeNode(app, text)
            node = [];
            allNodes = findall(app.Tree, '-property', 'Text');
            for i = 1:length(allNodes)
                if strcmp(allNodes(i).Text, text)
                    node = allNodes(i);
                    return;
                end
            end
        end
        
        % Get selected figure and axes IDs from tree
        function [figId, axesId] = getSelectedIds(app)
            figId = [];
            axesId = [];
            
            if isempty(app.SelectedNode)
                disp('No node selected');
                return;
            end
            
            nodeText = app.SelectedNode.Text;
            disp(['Selected: "', nodeText, '"']);
            
            if startsWith(nodeText, 'Figure ')
                figId = str2double(regexp(nodeText, '\d+', 'match', 'once'));
                disp(['Parsed Figure ID: ', num2str(figId)]);
                
                if isempty(app.Figures)
                    disp('ERROR: app.Figures is empty');
                    figId = [];
                    return;
                end
                
                figureExists = false;
                for i = 1:length(app.Figures)
                    if app.Figures(i).Id == figId
                        figureExists = true;
                        break;
                    end
                end
                
                if ~figureExists
                    disp(['ERROR: Figure ', num2str(figId), ' not found in app.Figures array']);
                    figId = [];
                else
                    disp(['SUCCESS: Figure ', num2str(figId), ' found in array']);
                end
                
            elseif startsWith(nodeText, 'Axes ')
                if ~isempty(app.SelectedNode.Parent)
                    parentText = app.SelectedNode.Parent.Text;
                    if startsWith(parentText, 'Figure ')
                        figId = str2double(regexp(parentText, '\d+', 'match', 'once'));
                        axesId = str2double(regexp(nodeText, '\d+', 'match', 'once'));
                        disp(['Parsed - Figure: ', num2str(figId), ', Axes: ', num2str(axesId)]);
                    end
                end
            end
        end
        
        % Filter scatter plot data by time range
        function filterScatterByTime(app, figIndex, axFieldName, timeMin, timeMax)
            axInfo = app.Figures(figIndex).Axes.(axFieldName);
            if ~strcmp(axInfo.Type, 'scatter') || length(axInfo.Variables) < 2, return; end
            
            dataManager = app.CurrentData;
            timeData = dataManager.getDataForPlotting('time_sn');
            timeMask = (timeData >= timeMin) & (timeData <= timeMax);
            
            if ~any(timeMask), return; end
            
            xVar = axInfo.Variables{1};
            yVars = axInfo.Variables(2:end);
            xData = dataManager.getDataForPlotting(xVar);
            
            % Clear and replot filtered data
            cla(axInfo.Handle);
            hold(axInfo.Handle, 'on');
            for i = 1:length(yVars)
                yData = dataManager.getDataForPlotting(yVars{i});
                scatter(axInfo.Handle, xData(timeMask), yData(timeMask), 'filled', 'DisplayName', yVars{i});
            end
            hold(axInfo.Handle, 'off');
            xlabel(axInfo.Handle, xVar);
            if length(yVars) > 1, legend(axInfo.Handle, 'show'); end
        end

        % Update axes plot with selected variables
        function updateAxesPlot(app, figureIndex, axesId)
            axFieldName = sprintf('axes%d', axesId);
            axesInfo = app.Figures(figureIndex).Axes.(axFieldName);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            
            cla(axesHandle);
            
            if strcmp(axesInfo.Type, 'scatter') && length(axesInfo.Variables) >= 2
                % Scatter with specific x
                xVar = axesInfo.Variables{1};
                yVars = axesInfo.Variables(2:end);
                xData = dataManager.getDataForPlotting(xVar);
                
                hold(axesHandle, 'on');
                colors = ['b', 'r', 'g', 'm', 'c', 'k'];
                for i = 1:length(yVars)
                    yData = dataManager.getDataForPlotting(yVars{i});
                    scatter(axesHandle, xData, yData, 'filled', 'DisplayName', yVars{i});
                end
                hold(axesHandle, 'off');
                xlabel(axesHandle, xVar);
            else
                % Line plot normal
                time = dataManager.getDataForPlotting('time_sn');
                hold(axesHandle, 'on');
                for i = 1:length(axesInfo.Variables)
                    yData = dataManager.getDataForPlotting(axesInfo.Variables{i});
                    plot(axesHandle, time, yData, 'DisplayName', axesInfo.Variables{i});
                end
                hold(axesHandle, 'off');
                xlabel(axesHandle, 'Time (s)');
            end
            
            if length(axesInfo.Variables) > 1, legend(axesHandle, 'show'); end
            grid(axesHandle, 'on');
        end

    end
end
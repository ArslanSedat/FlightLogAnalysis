classdef SupportFunctions
    methods (Static)
        
        function createNewFigure(app)
            try
                figId = app.NextFigureId;
                app.NextFigureId = app.NextFigureId + 1;
                
                if isempty(app.TabGroup) || ~isvalid(app.TabGroup)
                    app.TabGroup = uitabgroup(app.GridLayout);
                    app.TabGroup.Layout.Row = [1 3];
                    app.TabGroup.Layout.Column = 2;
                end
                
                newTab = uitab(app.TabGroup, 'Title', sprintf('Figure %d', figId));
                gridLayout = uigridlayout(newTab, [3, 2]);
                gridLayout.RowHeight = {'1x', '1x', '0.3x'};
                gridLayout.ColumnWidth = {'1x', '1x'};
                
                % Créer panner
                pannerAxes = uiaxes(gridLayout);
                pannerAxes.Layout.Row = 3;
                pannerAxes.Layout.Column = [1, 2];
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner';
                pannerAxes.Visible = app.PannerVisible;
                grid(pannerAxes, 'on');
                
                % Structure cohérente
                newFigure = struct(...
                    'Id', figId, ...
                    'Tab', newTab, ...
                    'GridLayout', gridLayout, ...
                    'Axes', struct(), ...
                    'Panner', pannerAxes, ...
                    'ViewRect', [], ...
                    'LeftHandle', [], ...
                    'RightHandle', [], ...
                    'PannerTimeData', [], ...
                    'PannerAltData', [], ...
                    'DraggingMode', '', ...
                    'DragStartPoint', [], ...
                    'DragStartRect', [] ...
                );
                
                app.Figures = [app.Figures, newFigure];
                figureIndex = length(app.Figures);
                
                if ~isempty(app.CurrentData)
                    SupportFunctions.updatePannerData(app, figureIndex);
                end
                
                % Ajouter à l'arbre
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
        
        function updatePannerData(app, idx)
            if idx > length(app.Figures) || isempty(app.CurrentData), return; end
            
            try
                pannerAxes = app.Figures(idx).Panner;
                dataManager = app.CurrentData;
                
                time = dataManager.getDataForPlotting('time_sn');
                altitude = dataManager.getDataForPlotting('alt_m');
                
                cla(pannerAxes);
                plot(pannerAxes, time, altitude, 'k-', 'LineWidth', 1);
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag to zoom/pan';
                grid(pannerAxes, 'on');
                
                % Rectangle SIMPLE et FONCTIONNEL
                xRange = range(time);
                rectWidth = xRange * 0.3;
                rectX = min(time) + (xRange - rectWidth) / 2;
                rectHeight = range(altitude);
                rectY = min(altitude);
                
                % Rectangle avec couleur UNIFORME
                viewRect = rectangle(pannerAxes, 'Position', [rectX, rectY, rectWidth, rectHeight], ...
                    'FaceColor', [0.8, 0.9, 1.0], ...  % Bleu clair UNIFORME
                    'EdgeColor', [0.2, 0.6, 1.0], ...
                    'LineWidth', 2);
                
                % Poignées
                hold(pannerAxes, 'on');
                leftHandle = plot(pannerAxes, rectX, rectY + rectHeight/2, 's', ...
                    'MarkerSize', 8, 'MarkerFaceColor', [0.2, 0.6, 1.0], 'MarkerEdgeColor', 'white', 'LineWidth', 1.5);
                rightHandle = plot(pannerAxes, rectX + rectWidth, rectY + rectHeight/2, 's', ...
                    'MarkerSize', 8, 'MarkerFaceColor', [0.2, 0.6, 1.0], 'MarkerEdgeColor', 'white', 'LineWidth', 1.5);
                hold(pannerAxes, 'off');
                
                % Stocker
                app.Figures(idx).ViewRect = viewRect;
                app.Figures(idx).LeftHandle = leftHandle;
                app.Figures(idx).RightHandle = rightHandle;
                app.Figures(idx).PannerTimeData = time;
                app.Figures(idx).PannerAltData = altitude;
                app.Figures(idx).DraggingMode = '';
                
                % Configurer interactions
                SupportFunctions.setupPannerInteractions(app, idx);
                SupportFunctions.updateMainAxesFromPanner(app, idx);
                
            catch ME
                fprintf('Panner error: %s\n', ME.message);
            end
        end
        
        function setupPannerInteractions(app, idx)
            if idx > length(app.Figures) || ~isfield(app.Figures(idx), 'ViewRect'), return; end
            
            pannerAxes = app.Figures(idx).Panner;
            viewRect = app.Figures(idx).ViewRect;
            leftHandle = app.Figures(idx).LeftHandle;
            rightHandle = app.Figures(idx).RightHandle;
            
            % Callbacks SIMPLES
            leftHandle.ButtonDownFcn = @(src, event) startDrag(app, idx, 'left');
            rightHandle.ButtonDownFcn = @(src, event) startDrag(app, idx, 'right');
            viewRect.ButtonDownFcn = @(src, event) startDrag(app, idx, 'center');
            pannerAxes.ButtonDownFcn = @(src, event) startDrag(app, idx, 'background');
        end
        
        function startDrag(app, idx, mode)
            app.Figures(idx).DraggingMode = mode;
            pannerAxes = app.Figures(idx).Panner;
            app.Figures(idx).DragStartPoint = pannerAxes.CurrentPoint(1, 1:2);
            app.Figures(idx).DragStartRect = app.Figures(idx).ViewRect.Position;
            
            % Feedback visuel SIMPLE
            if strcmp(mode, 'left')
                app.Figures(idx).LeftHandle.MarkerFaceColor = [1.0, 0.3, 0.3];
            elseif strcmp(mode, 'right')
                app.Figures(idx).RightHandle.MarkerFaceColor = [1.0, 0.3, 0.3];
            elseif strcmp(mode, 'center')
                app.Figures(idx).ViewRect.FaceColor = [1.0, 0.8, 0.8]; % Rose clair
            end
            
            % Configurer callbacks globaux
            app.UIFigure.WindowButtonMotionFcn = @(src, event) duringDrag(app, idx);
            app.UIFigure.WindowButtonUpFcn = @(src, event) endDrag(app, idx);
        end
        
        function duringDrag(app, idx)
            if idx > length(app.Figures) || isempty(app.Figures(idx).DraggingMode), return; end
            
            pannerAxes = app.Figures(idx).Panner;
            currentPoint = pannerAxes.CurrentPoint(1, 1:2);
            startPoint = app.Figures(idx).DragStartPoint;
            startRect = app.Figures(idx).DragStartRect;
            timeData = app.Figures(idx).PannerTimeData;
            
            viewRect = app.Figures(idx).ViewRect;
            leftHandle = app.Figures(idx).LeftHandle;
            rightHandle = app.Figures(idx).RightHandle;
            
            deltaX = currentPoint(1) - startPoint(1);
            
            switch app.Figures(idx).DraggingMode
                case 'left'
                    newX = startRect(1) + deltaX;
                    newWidth = startRect(3) - deltaX;
                    if newWidth > 0.01 * range(timeData) && newX >= min(timeData)
                        viewRect.Position = [newX, startRect(2), newWidth, startRect(4)];
                        leftHandle.XData = newX;
                        rightHandle.XData = newX + newWidth;
                    end
                    
                case 'right'
                    newWidth = startRect(3) + deltaX;
                    if newWidth > 0.01 * range(timeData) && (startRect(1) + newWidth) <= max(timeData)
                        viewRect.Position = [startRect(1), startRect(2), newWidth, startRect(4)];
                        leftHandle.XData = startRect(1);
                        rightHandle.XData = startRect(1) + newWidth;
                    end
                    
                case 'center'
                    newX = startRect(1) + deltaX;
                    newX = max(min(timeData), min(newX, max(timeData) - startRect(3)));
                    viewRect.Position = [newX, startRect(2), startRect(3), startRect(4)];
                    leftHandle.XData = newX;
                    rightHandle.XData = newX + startRect(3);
                    app.Figures(idx).DragStartPoint = currentPoint;
                    
                case 'background'
                    newCenter = currentPoint(1);
                    rectWidth = viewRect.Position(3);
                    newX = newCenter - rectWidth/2;
                    newX = max(min(timeData), min(newX, max(timeData) - rectWidth));
                    viewRect.Position = [newX, startRect(2), rectWidth, startRect(4)];
                    leftHandle.XData = newX;
                    rightHandle.XData = newX + rectWidth;
            end
            
            SupportFunctions.updateMainAxesFromPanner(app, idx);
        end
        
        function endDrag(app, idx)
            % Restaurer couleurs UNIFORMES
            if isfield(app.Figures(idx), 'LeftHandle')
                app.Figures(idx).LeftHandle.MarkerFaceColor = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'RightHandle')
                app.Figures(idx).RightHandle.MarkerFaceColor = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'ViewRect')
                app.Figures(idx).ViewRect.FaceColor = [0.8, 0.9, 1.0]; % MÊME COULEUR QUE updatePannerData
            end
            
            app.Figures(idx).DraggingMode = '';
            
            % Nettoyer les callbacks globaux
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
        end
        
        function updateMainAxesFromPanner(app, idx)
            if idx > length(app.Figures) || ~isfield(app.Figures(idx), 'ViewRect'), return; end
            
            viewRect = app.Figures(idx).ViewRect;
            rectPos = viewRect.Position;
            xMin = rectPos(1);
            xMax = rectPos(1) + rectPos(3);
            
            if isfield(app.Figures(idx), 'Axes')
                axesFields = fieldnames(app.Figures(idx).Axes);
                for i = 1:length(axesFields)
                    axInfo = app.Figures(idx).Axes.(axesFields{i});
                    if isfield(axInfo, 'Handle') && isvalid(axInfo.Handle)
                        axInfo.Handle.XLim = [xMin, xMax];
                    end
                end
            end
        end
        
        function addNewAxes(app, figId, type)
            % [VOTRE CODE EXISTANT - inchangé]
            if isempty(figId)
                uialert(app.UIFigure, 'Please select a FIGURE in the tree first.', 'No Figure Selected');
                return; 
            end
            
            if isempty(app.Figures)
                uialert(app.UIFigure, 'No figures exist. Create a figure first.', 'No Figures');
                return;
            end
            
            figureIndex = [];
            for i = 1:length(app.Figures)
                if app.Figures(i).Id == figId
                    figureIndex = i;
                    break;
                end
            end
            
            if isempty(figureIndex)
                uialert(app.UIFigure, sprintf('Figure %d not found', figId), 'Figure Not Found');
                return; 
            end
            
            axesId = app.NextAxesId;
            app.NextAxesId = app.NextAxesId + 1;
            gridLayout = app.Figures(figureIndex).GridLayout;
            
            [row, col] = SupportFunctions.findFreePosition(app, figureIndex);
            if isempty(row)
                uialert(app.UIFigure, 'No more space (max 4 axes).', 'Grid Full');
                return;
            end
            
            newAxes = uiaxes(gridLayout);
            newAxes.Layout.Row = row;
            newAxes.Layout.Column = col;
            newAxes.XLabel.String = 'Time (s)';
            newAxes.YLabel.String = 'Value';
            newAxes.Title.String = sprintf('%s Axes %d', type, axesId);
            grid(newAxes, 'on');
            
            if ~isfield(app.Figures(figureIndex), 'Axes')
                app.Figures(figureIndex).Axes = struct();
            end
            
            axFieldName = sprintf('axes%d', axesId);
            app.Figures(figureIndex).Axes.(axFieldName) = struct();
            app.Figures(figureIndex).Axes.(axFieldName).Handle = newAxes;
            app.Figures(figureIndex).Axes.(axFieldName).Type = type;
            app.Figures(figureIndex).Axes.(axFieldName).Variables = {};
            app.Figures(figureIndex).Axes.(axFieldName).Row = row;
            app.Figures(figureIndex).Axes.(axFieldName).Column = col;
            
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
        end
        
        % [GARDEZ TOUTES VOS AUTRES MÉTHODES EXISTANTES - inchangées]
        function deleteFigure(app, figId)
            % [VOTRE CODE EXISTANT]
        end
        
        function deleteAxes(app, figId, axesId)
            % [VOTRE CODE EXISTANT]
        end
        
        function [row, col] = findFreePosition(app, figureIndex)
            % [VOTRE CODE EXISTANT]
        end
        
        function updateAxesPlot(app, figureIndex, axesId)
            % [VOTRE CODE EXISTANT]
        end
        
        function [figId, axesId] = getSelectedIds(app)
            % [VOTRE CODE EXISTANT]
        end
        
        % ... toutes vos autres méthodes
    end
end
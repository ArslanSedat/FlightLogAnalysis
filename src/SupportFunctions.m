classdef SupportFunctions
    methods (Static)
        
        function createNewFigure(app)
            % Créer TabGroup au premier appel si nécessaire
            if ~isprop(app, 'TabGroup') || isempty(app.TabGroup)
                % Supprimer le panel vide s'il existe
                if isprop(app, 'PlotAreaPanel')
                    delete(app.PlotAreaPanel);
                end
                
                % Créer le TabGroup
                app.TabGroup = uitabgroup(app.GridLayout);
                app.TabGroup.Layout.Row = [1 3];
                app.TabGroup.Layout.Column = 2;
            end
            
            figId = app.NextFigureId;
            app.NextFigureId = app.NextFigureId + 1;
            
            % Créer nouvel onglet
            newTab = uitab(app.TabGroup);
            newTab.Title = sprintf('Figure %d', figId);
            
            % Grid layout
            gridLayout = uigridlayout(newTab);
            gridLayout.RowHeight = {'1x', '1x', '0.3x'};
            gridLayout.ColumnWidth = {'1x', '1x'};
            
            % Stocker info figure
            app.Figures(figId).Tab = newTab;
            app.Figures(figId).GridLayout = gridLayout;
            app.Figures(figId).Axes = struct();
            
            % Créer panner
            pannerAxes = uiaxes(gridLayout);
            pannerAxes.Layout.Row = 3;
            pannerAxes.Layout.Column = [1 2];
            pannerAxes.XLabel.String = 'Time (s)';
            pannerAxes.YLabel.String = 'Altitude';
            pannerAxes.Title.String = 'Altitude Panner';
            grid(pannerAxes, 'on');
            
            app.Figures(figId).Panner = pannerAxes;
            
            % Ajouter à l'arbre
            figNode = uitreenode(app.Tree);
            figNode.Text = sprintf('Figure %d', figId);
            figNode.NodeData = struct('Type', 'Figure', 'Id', figId);
            
            app.Label.Text = sprintf('Figure %d créée - Sélectionnez-la dans l''arbre', figId);
        end
        
        function addNewAxes(app, figId, type)
            if ~isfield(app.Figures, figId), return; end
            
            axesId = app.NextAxesId;
            app.NextAxesId = app.NextAxesId + 1;
            
            gridLayout = app.Figures(figId).GridLayout;
            
            % Trouver position libre
            [row, col] = AppSupportMethods.findFreePosition(app, figId);
            if isempty(row)
                uialert(app.UIFigure, 'No more space (max 4 axes).', 'Grid Full');
                return;
            end
            
            % Créer nouvel axe
            newAxes = uiaxes(gridLayout);
            newAxes.Layout.Row = row;
            newAxes.Layout.Column = col;
            newAxes.XLabel.String = 'Time (s)';
            newAxes.YLabel.String = 'Value';
            newAxes.Title.String = sprintf('%s Axes %d', type, axesId);
            grid(newAxes, 'on');
            
            % Stocker info
            app.Figures(figId).Axes(axesId).Handle = newAxes;
            app.Figures(figId).Axes(axesId).Type = type;
            app.Figures(figId).Axes(axesId).Variables = {};
            
            % Ajouter à l'arbre
            figNode = AppSupportMethods.findTreeNode(app, sprintf('Figure %d', figId));
            if ~isempty(figNode)
                axesNode = uitreenode(figNode);
                axesNode.Text = sprintf('Axes %d (%s)', axesId, type);
                axesNode.NodeData = struct('Type', 'Axes', 'FigureId', figId, 'AxesId', axesId);
            end
            
            % Configurer auto si données disponibles
            if ~isempty(app.CurrentData)
                AppSupportMethods.configureAxesWithSampleData(app, figId, axesId);
            end
        end
        
        function deleteFigure(app, figId)
            if isfield(app.Figures, figId)
                % Empêcher suppression si dernière figure
                remainingFigs = fieldnames(app.Figures);
                if length(remainingFigs) == 1
                    uialert(app.UIFigure, 'Cannot delete the last figure.', 'Last Figure');
                    return;
                end
                
                delete(app.Figures(figId).Tab);
                app.Figures = rmfield(app.Figures, figId);
                
                figNode = AppSupportMethods.findTreeNode(app, sprintf('Figure %d', figId));
                if ~isempty(figNode)
                    delete(figNode);
                end
                
                app.Label.Text = sprintf('Figure %d supprimée', figId);
            end
        end
        
        function deleteAxes(app, figId, axesId)
            if isfield(app.Figures, figId) && isfield(app.Figures(figId).Axes, axesId)
                delete(app.Figures(figId).Axes(axesId).Handle);
                app.Figures(figId).Axes = rmfield(app.Figures(figId).Axes, axesId);
                
                axesNode = AppSupportMethods.findTreeNode(app, sprintf('Axes %d', axesId));
                if ~isempty(axesNode)
                    delete(axesNode);
                end
                
                app.Label.Text = sprintf('Axes %d supprimé', axesId);
            end
        end
        
        function saveFigureAsPNG(app, figId)
            if ~isfield(app.Figures, figId), return; end
            
            [file, path] = uiputfile('*.png', 'Save Figure as PNG', sprintf('figure_%d.png', figId));
            if isequal(file, 0), return; end
            
            filename = fullfile(path, file);
            exportgraphics(app.Figures(figId).Tab, filename, 'Resolution', 300);
            app.Label.Text = sprintf('Saved: %s', file);
        end
        
        function saveFigureAsFIG(app, figId)
            if ~isfield(app.Figures, figId), return; end
            
            [file, path] = uiputfile('*.fig', 'Save Figure as FIG', sprintf('figure_%d.fig', figId));
            if isequal(file, 0), return; end
            
            filename = fullfile(path, file);
            newFig = figure('Visible', 'off');
            copyobj(app.Figures(figId).GridLayout.Children, newFig);
            saveas(newFig, filename, 'fig');
            close(newFig);
            app.Label.Text = sprintf('Saved: %s', file);
        end
        
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
        
        function [row, col] = findFreePosition(app, figId)
            positions = [1,1; 1,2; 2,1; 2,2];
            
            for i = 1:size(positions,1)
                row = positions(i,1);
                col = positions(i,2);
                occupied = false;
                
                if isfield(app.Figures, figId)
                    axesIds = fieldnames(app.Figures(figId).Axes);
                    for j = 1:length(axesIds)
                        axId = str2double(axesIds{j});
                        if app.Figures(figId).Axes(axId).Handle.Layout.Row == row && ...
                           app.Figures(figId).Axes(axId).Handle.Layout.Column == col
                            occupied = true;
                            break;
                        end
                    end
                end
                
                if ~occupied
                    return;
                end
            end
            row = []; col = [];
        end
        
        function configureAxesWithSampleData(app, figId, axesId)
            if ~isfield(app.Figures, figId) || ~isfield(app.Figures(figId).Axes, axesId)
                return;
            end
            
            axesInfo = app.Figures(figId).Axes(axesId);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            
            cla(axesHandle);
            
            try
                time = dataManager.getDataForPlotting('time_s');
                
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
                AppSupportMethods.plotSampleData(axesHandle, axesInfo.Type);
            end
        end
        
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
        
        function [figId, axesId] = getSelectedIds(app)
            % Retourne les IDs de la sélection actuelle
            figId = [];
            axesId = [];
            
            if isempty(app.SelectedNode) || ~isprop(app.SelectedNode, 'NodeData')
                return;
            end
            
            nodeData = app.SelectedNode.NodeData;
            if strcmp(nodeData.Type, 'Figure')
                figId = nodeData.Id;
            elseif strcmp(nodeData.Type, 'Axes')
                figId = nodeData.FigureId;
                axesId = nodeData.AxesId;
            end
        end
        
        function updateAxesPlot(app, figId, axesId)
            if ~isfield(app.Figures, figId) || ~isfield(app.Figures(figId).Axes, axesId)
                return;
            end
            
            axesInfo = app.Figures(figId).Axes(axesId);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            
            cla(axesHandle);
            
            if isempty(axesInfo.Variables)
                AppSupportMethods.plotSampleData(axesHandle, axesInfo.Type);
                return;
            end
            
            try
                time = dataManager.getDataForPlotting('time_s');
                hold(axesHandle, 'on');
                
                colors = ['b', 'r', 'g', 'm', 'c', 'k'];
                
                for i = 1:length(axesInfo.Variables)
                    varName = axesInfo.Variables{i};
                    yData = dataManager.getDataForPlotting(varName);
                    color = colors(mod(i-1, length(colors)) + 1);
                    
                    if strcmp(axesInfo.Type, 'line')
                        plot(axesHandle, time, yData, [color, '-'], 'LineWidth', 1.5, ...
                            'DisplayName', varName);
                    else
                        scatter(axesHandle, time, yData, 'filled', ...
                            'DisplayName', varName);
                    end
                end
                hold(axesHandle, 'off');
                
                if length(axesInfo.Variables) > 1
                    legend(axesHandle, 'show');
                end
                
                if length(axesInfo.Variables) == 1
                    ylabel(axesHandle, sprintf('%s (%s)', axesInfo.Variables{1}, ...
                        dataManager.getUnit(axesInfo.Variables{1})));
                else
                    ylabel(axesHandle, 'Multiple Variables');
                end
                
            catch
                AppSupportMethods.plotSampleData(axesHandle, axesInfo.Type);
            end
        end
    end
end
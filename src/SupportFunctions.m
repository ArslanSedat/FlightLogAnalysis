classdef SupportFunctions
    methods (Static)
        
        function createNewFigure(app)
            try
                figId = app.NextFigureId;
                app.NextFigureId = app.NextFigureId + 1;
                
                % Créer TabGroup si nécessaire
                if isempty(app.TabGroup) || ~isvalid(app.TabGroup)
                    app.TabGroup = uitabgroup(app.GridLayout);
                    app.TabGroup.Layout.Row = [1 3];
                    app.TabGroup.Layout.Column = 2;
                end
                
                % Créer nouvel onglet
                newTab = uitab(app.TabGroup, 'Title', sprintf('Figure %d', figId));
                
                % Grid layout
                gridLayout = uigridlayout(newTab, [3, 2]);
                gridLayout.RowHeight = {'1x', '1x', '0.15x'};
                gridLayout.ColumnWidth = {'1x', '1x'};
                
                % Créer panner
                pannerPanel = uipanel(gridLayout);
                pannerPanel.Layout.Row = 3;
                pannerPanel.Layout.Column = [1, 2];
                pannerPanel.Title = 'Altitude Panner';
                pannerPanel.Visible = app.PannerVisible;
                
                % Stocker dans un tableau (plus simple)
                newFigure = struct();
                newFigure.Id = figId;
                newFigure.Tab = newTab;
                newFigure.GridLayout = gridLayout;
                newFigure.Axes = struct();
                newFigure.Panner = pannerPanel;
                
                app.Figures = [app.Figures, newFigure];
                
                % Ajouter à l'arbre
                figNode = uitreenode(app.Tree, 'Text', sprintf('Figure %d', figId));
                figNode.NodeData = struct('Type', 'Figure', 'Id', figId, 'Visible', true);
                
                app.Tree.SelectedNodes = figNode;
                app.SelectedNode = figNode;
                
                app.Label.Text = sprintf('Figure %d created - READY!', figId);
                
            catch ME
                uialert(app.UIFigure, ME.message, 'Creation Error');
            end
        end
        
        function addNewAxes(app, figId, type)
            % Vérification plus robuste
            if isempty(figId)
                uialert(app.UIFigure, 'Please select a FIGURE in the tree first.', 'No Figure Selected');
                return; 
            end
            
            if isempty(app.Figures)
                uialert(app.UIFigure, 'No figures exist. Create a figure first.', 'No Figures');
                return;
            end
            
            % Trouver la figure dans le tableau
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
            
            % CONTINUER AVEC LE RESTE DU CODE...
            axesId = app.NextAxesId;
            app.NextAxesId = app.NextAxesId + 1;
            
            gridLayout = app.Figures(figureIndex).GridLayout;
            
            % Trouver position libre
            [row, col] = SupportFunctions.findFreePosition(app, figureIndex);
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
            
            % Stocker info dans la structure Axes de la figure
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
            
            % Ajouter à l'arbre
            figNode = SupportFunctions.findTreeNode(app, sprintf('Figure %d', figId));
            if ~isempty(figNode)
                axesNode = uitreenode(figNode);
                axesNode.Text = sprintf('Axes %d (%s)', axesId, type);
                axesNode.NodeData = struct('Type', 'Axes', 'FigureId', figId, 'AxesId', axesId, 'Visible', true);
            end
            
            % Configurer auto si données disponibles
            if ~isempty(app.CurrentData)
                SupportFunctions.configureAxesWithSampleData(app, figureIndex, axesId);
            else
                % Afficher des données d'exemple même sans données chargées
                SupportFunctions.plotSampleData(newAxes, type);
            end
            
            % Forcer l'affichage
            drawnow;
            
            app.Label.Text = sprintf('Axes %d added to Figure %d', axesId, figId);
            disp(['SUCCESS: Axes ', num2str(axesId), ' created in Figure ', num2str(figId)]);
        end
        
        function deleteFigure(app, figId)
            if isfield(app.Figures, figId)
                % Empêcher suppression si dernière figure
                remainingFigs = fieldnames(app.Figures);
                if isscalar(remainingFigs)
                    uialert(app.UIFigure, 'Cannot delete the last figure.', 'Last Figure');
                    return;
                end
                
                delete(app.Figures(figId).Tab);
                app.Figures = rmfield(app.Figures, figId);
                
                figNode = SupportFunctions.findTreeNode(app, sprintf('Figure %d', figId));
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
                
                axesNode = SupportFunctions.findTreeNode(app, sprintf('Axes %d', axesId));
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
        
        function [row, col] = findFreePosition(app, figureIndex)
            % Positions disponibles dans la grille 2x2
            positions = [1,1; 1,2; 2,1; 2,2];
            
            % Vérifier si la figure existe et si la structure Axes est valide
            if figureIndex > length(app.Figures) || ~isfield(app.Figures(figureIndex), 'Axes')
                % Retourner la première position si pas d'axes
                row = positions(1,1);
                col = positions(1,2);
                disp(['First axes - Position: (', num2str(row), ',', num2str(col), ')']);
                return;
            end
            
            % Vérifier si Axes est vide
            if isempty(fieldnames(app.Figures(figureIndex).Axes))
                row = positions(1,1);
                col = positions(1,2);
                disp(['First axes - Position: (', num2str(row), ',', num2str(col), ')']);
                return;
            end
            
            % Vérifier chaque position
            for i = 1:size(positions,1)
                row = positions(i,1);
                col = positions(i,2);
                occupied = false;
                
                axesFields = fieldnames(app.Figures(figureIndex).Axes);
                
                for j = 1:length(axesFields)
                    % VÉRIFICATION SÉCURISÉE
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
            
            % Si toutes les positions sont occupées
            row = [];
            col = [];
            disp('No free positions found - grid is full');
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
                SupportFunctions.plotSampleData(axesHandle, axesInfo.Type);
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
                
                % VÉRIFIER SI LA FIGURE EXISTE DANS LE TABLEAU
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
                % Pour un axe, trouver la figure parente
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

        function figureIndex = findFigureIndex(app, figId)
            figureIndex = [];
            for i = 1:length(app.Figures)
                if app.Figures(i).Id == figId
                    figureIndex = i;
                    break;
                end
            end
        end
        
        function updateAxesPlot(app, figureIndex, axesId)
            disp(['=== UPDATE AXES PLOT DEBUG ===']);
            disp(['figureIndex: ', num2str(figureIndex)]);
            disp(['axesId: ', num2str(axesId)]);
            
            if figureIndex > length(app.Figures) || ~isfield(app.Figures(figureIndex), 'Axes')
                disp('ERROR: Figure not found or no Axes field');
                return;
            end
            
            axFieldName = sprintf('axes%d', axesId);
            if ~isfield(app.Figures(figureIndex).Axes, axFieldName)
                disp(['ERROR: Axes field ', axFieldName, ' not found']);
                return;
            end
            
            axesInfo = app.Figures(figureIndex).Axes.(axFieldName);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            
            disp(['Axes type: ', axesInfo.Type]);
            disp(['Axes variables: ', strjoin(axesInfo.Variables, ', ')]);
            
            % Vider l'axe
            cla(axesHandle);
            
            if isempty(axesInfo.Variables)
                disp('No variables selected - plotting sample data');
                SupportFunctions.plotSampleData(axesHandle, axesInfo.Type);
                return;
            end
            
            try
                time = dataManager.getDataForPlotting('time_s');
                disp(['Time data length: ', num2str(length(time))]);
                
                hold(axesHandle, 'on');
                
                colors = ['b', 'r', 'g', 'm', 'c', 'k'];
                legendEntries = {};
                
                for i = 1:length(axesInfo.Variables)
                    varName = axesInfo.Variables{i};
                    disp(['Processing variable: ', varName]);
                    
                    try
                        yData = dataManager.getDataForPlotting(varName);
                        disp(['Data length for ', varName, ': ', num2str(length(yData))]);
                        
                        color = colors(mod(i-1, length(colors)) + 1);
                        
                        if strcmp(axesInfo.Type, 'line')
                            plot(axesHandle, time, yData, [color, '-'], 'LineWidth', 1.5, ...
                                'DisplayName', varName);
                        else
                            scatter(axesHandle, time, yData, 'filled', ...
                                'DisplayName', varName);
                        end
                        legendEntries{end+1} = varName;
                        
                    catch varError
                        disp(['ERROR processing variable ', varName, ': ', varError.message]);
                    end
                end
                hold(axesHandle, 'off');
                
                % Configurer la légende
                if length(legendEntries) > 1
                    legend(axesHandle, 'show');
                elseif isscalar(legendEntries)
                    ylabel(axesHandle, sprintf('%s (%s)', legendEntries{1}, ...
                        dataManager.getUnit(legendEntries{1})));
                end
                
                % Titre et grille
                if strcmp(axesInfo.Type, 'line')
                    title(axesHandle, 'Line Plot - Flight Data');
                else
                    title(axesHandle, 'Scatter Plot - Flight Data');
                end
                xlabel(axesHandle, 'Time (s)');
                grid(axesHandle, 'on');
                
                disp('SUCCESS: Axes plot updated');
                
            catch ME
                disp(['ERROR in updateAxesPlot: ', ME.message]);
                SupportFunctions.plotSampleData(axesHandle, axesInfo.Type);
            end
            
            % Forcer le rafraîchissement
            drawnow;
        end
    end
end
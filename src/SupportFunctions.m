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
                gridLayout.RowHeight = {'1x', '1x', '0.3x'};
                gridLayout.ColumnWidth = {'1x', '1x'};
                
                % Créer panner
                pannerAxes = uiaxes(gridLayout);
                pannerAxes.Layout.Row = 3;
                pannerAxes.Layout.Column = [1, 2];
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner';
                pannerAxes.Visible = app.PannerVisible;  % ← Contrôle de visibilité direct
                grid(pannerAxes, 'on');
                
                % Stocker dans un tableau (plus simple)
                newFigure = struct();
                newFigure.Id = figId;
                newFigure.Tab = newTab;
                newFigure.GridLayout = gridLayout;
                newFigure.Axes = struct();
                newFigure.Panner = pannerAxes;  % ← Stocker l'axe, pas le panel
                
                % AJOUTER au tableau et obtenir l'index
                app.Figures = [app.Figures, newFigure];
                figureIndex = length(app.Figures);  % ← MAINTENANT figureIndex est défini !
                
                % Remplir le panner avec les données si disponibles
                if ~isempty(app.CurrentData)
                    SupportFunctions.updatePannerData(app, figureIndex);  % ← Maintenant ça marche !
                end
                
                % Ajouter à l'arbre
                figNode = uitreenode(app.Tree, 'Text', sprintf('Figure %d', figId));
                figNode.NodeData = struct('Type', 'Figure', 'Id', figId, 'Visible', true);
                
                app.Tree.SelectedNodes = figNode;
                app.SelectedNode = figNode;
                
                app.Label.Text = sprintf('Figure %d created - READY!', figId);
                fprintf('Figure %d created at index %d\n', figId, figureIndex);
                
            catch ME
                fprintf('Error in createNewFigure: %s\n', ME.message);
                uialert(app.UIFigure, ME.message, 'Creation Error');
            end
        end
        
        function updatePannerData(app, idx)
            fprintf('Updating panner for figure index: %d\n', idx);
            
            % Vérifications de base
            if isempty(app.Figures) || idx > length(app.Figures) || idx < 1
                fprintf('ERROR: Invalid figure index %d\n', idx);
                return;
            end
            
            if ~isfield(app.Figures(idx), 'Panner')
                fprintf('ERROR: No Panner field in figure %d\n', idx);
                return;
            end
            
            if isempty(app.CurrentData)
                fprintf('No data loaded for panner %d\n', idx);
                return;
            end
            
            try
                pannerAxes = app.Figures(idx).Panner;
                dataManager = app.CurrentData;
                
                % Obtenir les données
                time = dataManager.getDataForPlotting('time_sn');
                altitude = dataManager.getDataForPlotting('alt_m');
                
                % Plot des données
                cla(pannerAxes);
                plot(pannerAxes, time, altitude, 'b-', 'LineWidth', 1.5);
                
                % Configuration de l'axe
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag rectangle to zoom';
                grid(pannerAxes, 'on');
                
                % Créer le rectangle transparent (viewfinder)
                xRange = range(time);
                yRange = range(altitude);
                
                % Rectangle couvrant 50% de la vue au centre
                rectX = min(time) + xRange * 0.25;
                rectY = min(altitude) + yRange * 0.25;
                rectWidth = xRange * 0.5;
                rectHeight = yRange * 0.5;
                
                % Rectangle semi-transparent
                rect = rectangle(pannerAxes, 'Position', [rectX, rectY, rectWidth, rectHeight], ...
                    'FaceColor', [0.1, 0.1, 0.8, 0.3], ...  % Bleu transparent
                    'EdgeColor', 'blue', ...
                    'LineWidth', 2, ...
                    'LineStyle', '-');
                
                % Stocker le rectangle et les données de référence
                app.Figures(idx).PannerRect = rect;
                app.Figures(idx).PannerTimeData = time;
                app.Figures(idx).PannerAltData = altitude;
                
                % Configurer les interactions
                SupportFunctions.setupPannerInteractions(app, idx);
                
                fprintf('Panner %d updated with interactive rectangle\n', idx);
                
            catch ME
                fprintf('Error updating panner %d: %s\n', idx, ME.message);
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
            fprintf('=== UPDATE AXES PLOT - STRICT MODE ===\n');
            fprintf('figureIndex: %d, axesId: %d\n', figureIndex, axesId);
            
            % Vérifications de base
            if figureIndex > length(app.Figures) || ~isfield(app.Figures(figureIndex), 'Axes')
                error('Figure not found or no Axes field');
            end
            
            axFieldName = sprintf('axes%d', axesId);
            if ~isfield(app.Figures(figureIndex).Axes, axFieldName)
                error('Axes field %s not found', axFieldName);
            end
            
            axesInfo = app.Figures(figureIndex).Axes.(axFieldName);
            axesHandle = axesInfo.Handle;
            dataManager = app.CurrentData;
            
            fprintf('Axes type: %s\n', axesInfo.Type);
            fprintf('Axes variables: %s\n', strjoin(axesInfo.Variables, ', '));
            
            % VÉRIFICATIONS STRICTES
            if isempty(dataManager)
                error('dataManager is empty - Load data first!');
            end
            
            if isempty(dataManager.RawData)
                error('RawData is empty - Data loading failed!');
            end
            
            if isempty(axesInfo.Variables)
                error('No variables selected - Use Edit Axes to select variables!');
            end
            
            % Vider l'axe
            cla(axesHandle);
            
            % OBLIGATION : utiliser uniquement les vraies données
            time = dataManager.getDataForPlotting('time_sn');
            fprintf('Time data length: %d\n', length(time));
            
            hold(axesHandle, 'on');
            colors = ['b', 'r', 'g', 'm', 'c', 'k'];
            legendEntries = {};
            successCount = 0;
            
            for i = 1:length(axesInfo.Variables)
                varName = axesInfo.Variables{i};
                fprintf('Processing variable: %s\n', varName);
                
                try
                    % TENTATIVE D'ACCÈS AUX DONNÉES RÉELLES
                    yData = dataManager.getDataForPlotting(varName);
                    fprintf('SUCCESS: %s - length: %d, range: [%.3f, %.3f]\n', ...
                        varName, length(yData), min(yData), max(yData));
                    
                    color = colors(mod(i-1, length(colors)) + 1);
                    
                    if strcmp(axesInfo.Type, 'line')
                        plot(axesHandle, time, yData, [color, '-'], 'LineWidth', 1.5, ...
                            'DisplayName', varName);
                    else
                        scatter(axesHandle, time, yData, 'filled', ...
                            'DisplayName', varName);
                    end
                    legendEntries{end+1} = varName;
                    successCount = successCount + 1;
                    
                catch varError
                    % ÉCHEC CRITIQUE - ARRÊTER TOUT
                    fprintf('CRITICAL ERROR with variable %s: %s\n', varName, varError.message);
                    cla(axesHandle);
                    text(axesHandle, 0.5, 0.5, sprintf('ERROR: %s\nnot found in data', varName), ...
                        'HorizontalAlignment', 'center', 'Units', 'normalized');
                    title(axesHandle, 'DATA ERROR');
                    drawnow;
                    return;  % ← ARRÊTER IMMÉDIATEMENT
                end
            end
            hold(axesHandle, 'off');
            
            % Si au moins une variable a réussi
            if successCount > 0
                if length(legendEntries) > 1
                    legend(axesHandle, 'show');
                elseif length(legendEntries) == 1
                    ylabel(axesHandle, sprintf('%s (%s)', legendEntries{1}, ...
                        dataManager.getUnit(legendEntries{1})));
                end
                
                title(axesHandle, sprintf('%s Plot - Real Flight Data', axesInfo.Type));
                xlabel(axesHandle, 'Time (s)');
                grid(axesHandle, 'on');
                
                fprintf('SUCCESS: %d/%d variables plotted with REAL data\n', successCount, length(axesInfo.Variables));
            else
                % Aucune variable n'a fonctionné
                text(axesHandle, 0.5, 0.5, 'ALL VARIABLES FAILED\nCheck data loading', ...
                    'HorizontalAlignment', 'center', 'Units', 'normalized');
                title(axesHandle, 'ALL DATA ERRORS');
            end
            
            drawnow;
        end
    end
end
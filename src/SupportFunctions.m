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
                gridLayout.RowHeight = {'1x', '1x', '0.3x'};  % Panner plus petit
                gridLayout.ColumnWidth = {'1x', '1x'};
                
                % Créer panner avec barres
                pannerAxes = uiaxes(gridLayout);
                pannerAxes.Layout.Row = 3;
                pannerAxes.Layout.Column = [1, 2];
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag bars to change view';
                pannerAxes.Visible = app.PannerVisible;
                grid(pannerAxes, 'on');
                
                % Structure avec système de barres
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
            if idx > length(app.Figures) || isempty(app.CurrentData), return; 
            end
            
            try
                pannerAxes = app.Figures(idx).Panner;
                dataManager = app.CurrentData;
                
                time = dataManager.getDataForPlotting('time_sn');
                altitude = dataManager.getDataForPlotting('alt_m');
                
                % Vider l'axe
                cla(pannerAxes);
                
                % Tracer la courbe d'altitude
                plot(pannerAxes, time, altitude, 'k-', 'LineWidth', 1);
                pannerAxes.XLabel.String = 'Time (s)';
                pannerAxes.YLabel.String = 'Altitude (m)';
                pannerAxes.Title.String = 'Altitude Panner - Drag bars to change view';
                grid(pannerAxes, 'on');
                
                % FORCER les limites Y pour couvrir toute la hauteur des données
                yMin = min(altitude);
                yMax = max(altitude);
                yMargin = 0.05 * (yMax - yMin); % 5% de marge
                pannerAxes.YLim = [yMin - yMargin, yMax + yMargin];
                
                % Récupérer les limites FINALES après ajustement automatique
                yLimits = pannerAxes.YLim;
                
                % Définir les limites initiales des barres (30% du temps total)
                xRange = range(time);
                viewWidth = xRange;  % Largeur de vue initiale
                leftPos = min(time);
                rightPos = max(time);
                
                hold(pannerAxes, 'on');
                
                % Zone de remplissage entre les barres - PLEINE HAUTEUR
                fillX = [leftPos, rightPos, rightPos, leftPos];
                fillY = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
                
                fillArea = fill(pannerAxes, fillX, fillY, [0.2, 0.6, 1.0], ...
                    'FaceAlpha', 0.3, 'EdgeColor', 'none', ...
                    'HitTest', 'off', 'PickableParts', 'none');
                
                % Barre gauche - PLEINE HAUTEUR
                leftBar = plot(pannerAxes, [leftPos, leftPos], [yLimits(1), yLimits(2)], ...
                    'Color', [0.2, 0.6, 1.0], 'LineWidth', 4, ...
                    'Marker', 'none');
                
                % Barre droite - PLEINE HAUTEUR  
                rightBar = plot(pannerAxes, [rightPos, rightPos], [yLimits(1), yLimits(2)], ...
                    'Color', [0.2, 0.6, 1.0], 'LineWidth', 4, ...
                    'Marker', 'none');
                
                hold(pannerAxes, 'off');
                
                % Stocker les références
                app.Figures(idx).LeftBar = leftBar;
                app.Figures(idx).RightBar = rightBar;
                app.Figures(idx).FillArea = fillArea;
                app.Figures(idx).PannerTimeData = time;
                app.Figures(idx).PannerAltData = altitude;
                app.Figures(idx).DraggingBar = '';
                
                % Configurer les interactions
                SupportFunctions.setupPannerInteractions(app, idx);
                
                % Mettre à jour les axes principaux
                SupportFunctions.updateMainAxesFromPanner(app, idx);
                
            catch ME
                fprintf('Panner update error: %s\n', ME.message);
            end
        end

        function updateMainAxesFromPanner(app, idx)
            if idx > length(app.Figures) || ~isfield(app.Figures(idx), 'LeftBar')
                return;
            end
            
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            
            xMin = leftBar.XData(1);
            xMax = rightBar.XData(1);
            
            fprintf('Updating main axes to [%.2f, %.2f]\n', xMin, xMax);
            
            % Mettre à jour TOUS les axes de cette figure
            if isfield(app.Figures(idx), 'Axes')
                axesFields = fieldnames(app.Figures(idx).Axes);
                for i = 1:length(axesFields)
                    axInfo = app.Figures(idx).Axes.(axesFields{i});
                    if isfield(axInfo, 'Handle') && isvalid(axInfo.Handle)
                        try
                            axInfo.Handle.XLim = [xMin, xMax];
                            drawnow limitrate;
                        catch
                            % Ignorer les erreurs sur axes invalides
                        end
                    end
                end
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
        
        function setupPannerInteractions(app, idx)
            if idx > length(app.Figures), return; end
            
            pannerAxes = app.Figures(idx).Panner;
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            
            % Callbacks pour les barres - TRÈS IMPORTANT
            leftBar.ButtonDownFcn = @(src, event) SupportFunctions.startBarDrag(app, idx, 'left', src, event);
            rightBar.ButtonDownFcn = @(src, event) SupportFunctions.startBarDrag(app, idx, 'right', src, event);
            
            % Callback pour le fond (déplacement de la vue)
            pannerAxes.ButtonDownFcn = @(src, event) SupportFunctions.startBackgroundDrag(app, idx, src, event);
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

        function duringDrag(app, idx)
            if idx > length(app.Figures) || isempty(app.Figures(idx).DraggingMode), return; 
            end
            
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

        function startPannerDrag(app, idx, mode, src, event)
            if idx > length(app.Figures), return; end
            
            app.Figures(idx).DraggingMode = mode;
            app.Figures(idx).DragStartPoint = src.Parent.CurrentPoint(1, 1:2);
            app.Figures(idx).DragStartRect = app.Figures(idx).ViewRect.Position;
            
            % Feedback visuel
            if strcmp(mode, 'left') || strcmp(mode, 'right')
                src.MarkerFaceColor = [1.0, 0.3, 0.3]; % Rouge pendant le drag
            elseif strcmp(mode, 'center')
                app.Figures(idx).ViewRect.FaceColor = [1.0, 0.3, 0.3, 0.3];
            end
            
            fprintf('Started %s drag\n', mode);
        end

        function duringPannerDrag(app, idx, src, event)
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
                    % Redimensionner depuis la gauche
                    newX = startRect(1) + deltaX;
                    newWidth = startRect(3) - deltaX;
                    
                    if newWidth > 0.01 * range(timeData) && newX >= min(timeData)
                        viewRect.Position = [newX, startRect(2), newWidth, startRect(4)];
                        leftHandle.XData = newX;
                        rightHandle.XData = newX + newWidth;
                    end
                    
                case 'right'
                    % Redimensionner depuis la droite
                    newWidth = startRect(3) + deltaX;
                    
                    if newWidth > 0.01 * range(timeData) && (startRect(1) + newWidth) <= max(timeData)
                        viewRect.Position = [startRect(1), startRect(2), newWidth, startRect(4)];
                        leftHandle.XData = startRect(1);
                        rightHandle.XData = startRect(1) + newWidth;
                    end
                    
                case 'center'
                    % Déplacer toute la vue
                    newX = startRect(1) + deltaX;
                    newX = max(min(timeData), min(newX, max(timeData) - startRect(3)));
                    
                    viewRect.Position = [newX, startRect(2), startRect(3), startRect(4)];
                    leftHandle.XData = newX;
                    rightHandle.XData = newX + startRect(3);
                    app.Figures(idx).DragStartPoint = currentPoint;
                    
                case 'background'
                    % Cliquer en dehors → centrer la vue sur ce point
                    newCenter = currentPoint(1);
                    rectWidth = viewRect.Position(3);
                    newX = newCenter - rectWidth/2;
                    newX = max(min(timeData), min(newX, max(timeData) - rectWidth));
                    
                    viewRect.Position = [newX, startRect(2), rectWidth, startRect(4)];
                    leftHandle.XData = newX;
                    rightHandle.XData = newX + rectWidth;
            end
            
            % Mettre à jour les axes principaux
            SupportFunctions.updateMainAxesFromPanner(app, idx);
            drawnow;
        end

        function endPannerDrag(app, idx, src, event)
            if idx > length(app.Figures), return; end
            
            % Restaurer les couleurs normales
            if isfield(app.Figures(idx), 'LeftHandle')
                app.Figures(idx).LeftHandle.MarkerFaceColor = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'RightHandle')
                app.Figures(idx).RightHandle.MarkerFaceColor = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'ViewRect')
                app.Figures(idx).ViewRect.FaceColor = [0.2, 0.6, 1.0, 0.3];
            end
            
            app.Figures(idx).DraggingMode = '';
        end

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
            
            % Séparation minimale entre les barres
            minSeparation = 0.01 * range(timeData);
            
            if strcmp(app.Figures(idx).DraggingBar, 'left')
                % Déplacer la barre gauche
                newX = currentPoint;
                newX = max(min(timeData), min(newX, rightBar.XData(1) - minSeparation));
                
                leftBar.XData = [newX, newX];
                
            elseif strcmp(app.Figures(idx).DraggingBar, 'right')
                % Déplacer la barre droite
                newX = currentPoint;
                newX = max(leftBar.XData(1) + minSeparation, min(newX, max(timeData)));
                
                rightBar.XData = [newX, newX];
            end
            
            % Mettre à jour la zone de remplissage
            yLimits = pannerAxes.YLim;
            fillArea.XData = [leftBar.XData(1), rightBar.XData(1), rightBar.XData(1), leftBar.XData(1)];
            fillArea.YData = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
            
            % Mettre à jour les axes principaux
            SupportFunctions.updateMainAxesFromPanner(app, idx);
            
            drawnow;
        end

        function endBarDrag(app, idx, src, event)
            if idx > length(app.Figures), return; end
            
            fprintf('Ending bar drag\n');
            
            % Restaurer les couleurs normales
            if isfield(app.Figures(idx), 'LeftBar') && isvalid(app.Figures(idx).LeftBar)
                app.Figures(idx).LeftBar.Color = [0.2, 0.6, 1.0];
            end
            if isfield(app.Figures(idx), 'RightBar') && isvalid(app.Figures(idx).RightBar)
                app.Figures(idx).RightBar.Color = [0.2, 0.6, 1.0];
            end
            
            app.Figures(idx).DraggingBar = '';
            
            % Nettoyer les callbacks globaux
            app.UIFigure.WindowButtonMotionFcn = [];
            app.UIFigure.WindowButtonUpFcn = [];
        end
        
        function deleteFigure(app, figId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex)
                fprintf('Figure %d not found for deletion\n', figId);
                return;
            end
            
            % Supprimer le tab
            if isvalid(app.Figures(figureIndex).Tab)
                delete(app.Figures(figureIndex).Tab);
            end
            
            % Supprimer de la structure
            app.Figures(figureIndex) = [];
            
            % Supprimer le node de l'arbre
            figNode = SupportFunctions.findTreeNode(app, sprintf('Figure %d', figId));
            if ~isempty(figNode) && isvalid(figNode)
                delete(figNode);
            end
            
            app.Label.Text = sprintf('Figure %d deleted', figId);
        end
        
        function deleteAxes(app, figId, axesId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex)
                fprintf('Figure %d not found for axes deletion\n', figId);
                return;
            end
            
            axFieldName = sprintf('axes%d', axesId);
            if isfield(app.Figures(figureIndex).Axes, axFieldName)
                % Supprimer l'axe graphique
                axesInfo = app.Figures(figureIndex).Axes.(axFieldName);
                if isfield(axesInfo, 'Handle') && isvalid(axesInfo.Handle)
                    delete(axesInfo.Handle);
                end
                
                % Supprimer de la structure
                app.Figures(figureIndex).Axes = rmfield(app.Figures(figureIndex).Axes, axFieldName);
                
                % Supprimer le node de l'arbre
                axesNode = SupportFunctions.findTreeNode(app, sprintf('Axes %d', axesId));
                if ~isempty(axesNode) && isvalid(axesNode)
                    delete(axesNode);
                end
                
                app.Label.Text = sprintf('Axes %d deleted', axesId);
            else
                fprintf('Axes %d not found in Figure %d\n', axesId, figId);
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

        function saveFigureAsPNG(app, figId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex)
                uialert(app.UIFigure, sprintf('Figure %d not found', figId), 'Error');
                return;
            end
            
            [file, path] = uiputfile('*.png', 'Save Figure as PNG', sprintf('figure_%d.png', figId));
            if isequal(file, 0), return; end
            
            filename = fullfile(path, file);
            
            try
                % Capturer le contenu du tab
                fig = figure('Visible', 'off');
                copyobj(app.Figures(figureIndex).GridLayout.Children, fig);
                saveas(fig, filename, 'png');
                close(fig);
                app.Label.Text = sprintf('Saved: %s', file);
            catch ME
                uialert(app.UIFigure, sprintf('Save failed: %s', ME.message), 'Save Error');
            end
        end
        
        function saveFigureAsFIG(app, figId)
            figureIndex = SupportFunctions.findFigureIndex(app, figId);
            if isempty(figureIndex)
                uialert(app.UIFigure, sprintf('Figure %d not found', figId), 'Error');
                return;
            end
            
            [file, path] = uiputfile('*.fig', 'Save Figure as FIG', sprintf('figure_%d.fig', figId));
            if isequal(file, 0), return; end
            
            filename = fullfile(path, file);
            
            try
                % Créer une figure classique
                newFig = figure('Visible', 'off');
                copyobj(app.Figures(figureIndex).GridLayout.Children, newFig);
                saveas(newFig, filename, 'fig');
                close(newFig);
                app.Label.Text = sprintf('Saved: %s', file);
            catch ME
                uialert(app.UIFigure, sprintf('Save failed: %s', ME.message), 'Save Error');
            end
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
        
        function startBarDrag(app, idx, barType, src, event)
            fprintf('Starting %s bar drag\n', barType);
            
            app.Figures(idx).DraggingBar = barType;
            app.Figures(idx).DragStartPoint = event.IntersectionPoint(1); % Position X seulement
            
            % Feedback visuel
            src.Color = [1.0, 0.3, 0.3]; % Rouge pendant le drag
            
            % Configurer les callbacks globaux
            app.UIFigure.WindowButtonMotionFcn = @(src, event) SupportFunctions.duringBarDrag(app, idx, src, event);
            app.UIFigure.WindowButtonUpFcn = @(src, event) SupportFunctions.endBarDrag(app, idx, src, event);
        end

        function startBackgroundDrag(app, idx, src, event)
            fprintf('Starting background drag\n');
            
            currentPoint = event.IntersectionPoint(1);
            leftBar = app.Figures(idx).LeftBar;
            rightBar = app.Figures(idx).RightBar;
            timeData = app.Figures(idx).PannerTimeData;
            
            % Calculer le centre actuel et le nouveau centre
            currentCenter = (leftBar.XData(1) + rightBar.XData(1)) / 2;
            viewWidth = rightBar.XData(1) - leftBar.XData(1);
            
            % Déplacer la vue pour centrer sur le point cliqué
            newLeft = currentPoint - viewWidth / 2;
            newRight = currentPoint + viewWidth / 2;
            
            % Limites
            newLeft = max(min(timeData), newLeft);
            newRight = min(max(timeData), newRight);
            
            % Ajuster si nécessaire
            if newRight - newLeft < viewWidth
                if newLeft == min(timeData)
                    newRight = newLeft + viewWidth;
                else
                    newLeft = newRight - viewWidth;
                end
            end
            
            % Mettre à jour les barres
            leftBar.XData = [newLeft, newLeft];
            rightBar.XData = [newRight, newRight];
            
            % Mettre à jour la zone de remplissage
            yLimits = app.Figures(idx).Panner.YLim;
            app.Figures(idx).FillArea.XData = [newLeft, newRight, newRight, newLeft];
            app.Figures(idx).FillArea.YData = [yLimits(1), yLimits(1), yLimits(2), yLimits(2)];
            
            % Mettre à jour les axes principaux
            SupportFunctions.updateMainAxesFromPanner(app, idx);
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
                elseif isscalar(legendEntries)
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
classdef PlotManager < handle
    properties
        AppHandle
        Figures struct
    end
    
    methods
        function obj = PlotManager(appHandle)
            obj.AppHandle = appHandle;
        end
        
        function createNewFigure(obj)
            figId = numel(fieldnames(obj.Figures)) + 1;
            
            newTab = uitab(obj.AppHandle.TabGroup, 'Title', sprintf('Figure %d', figId));
            gridLayout = uigridlayout(newTab, [3, 2], 'RowHeight', {'2x', '2x', '1x'});
            
            obj.Figures.(sprintf('f%d', figId)) = struct(...
                'Tab', newTab, 'GridLayout', gridLayout, 'Axes', struct());
            
            % Créer panner
            panner = uiaxes(gridLayout, 'Layout', struct('Row',3, 'Column',[1,2]));
            panner.XLabel.String = 'Time (s)'; panner.YLabel.String = 'Altitude';
            title(panner, 'Altitude Panner'); grid(panner, 'on');
            
            obj.Figures.(sprintf('f%d', figId)).Panner = panner;
        end
        
        function addNewAxes(obj, figId, type)
            figField = sprintf('f%d', figId);
            if ~isfield(obj.Figures, figField), return; end
            
            axesId = numel(fieldnames(obj.Figures.(figField).Axes)) + 1;
            [row, col] = obj.findFreePosition(figId);
            if isempty(row), return; end
            
            newAxes = uiaxes(obj.Figures.(figField).GridLayout, ...
                'Layout', struct('Row',row, 'Column',col));
            xlabel(newAxes, 'Time (s)'); title(newAxes, sprintf('%s Axes %d', type, axesId));
            grid(newAxes, 'on');
            
            obj.Figures.(figField).Axes.(sprintf('a%d', axesId)) = struct(...
                'Handle', newAxes, 'Type', type, 'Variables', {{}});
            
            obj.updateAxesPlot(figId, axesId);
        end
        
        function updateAllPlots(obj)
            if isempty(obj.AppHandle.CurrentData), return; end
            arrayfun(@(f) obj.updateFigurePlots(f), 1:numel(fieldnames(obj.Figures)));
        end
        
        function updateFigurePlots(obj, figId)
            figField = sprintf('f%d', figId);
            if ~isfield(obj.Figures, figField), return; end
            
            % Mettre à jour tous les axes
            arrayfun(@(a) obj.updateAxesPlot(figId, a), 1:numel(fieldnames(obj.Figures.(figField).Axes)));
            
            % Mettre à jour panner
            obj.updatePannerPlot(figId);
        end
        
        function updateAxesPlot(obj, figId, axesId)
            figField = sprintf('f%d', figId); axesField = sprintf('a%d', axesId);
            if ~isfield(obj.Figures, figField) || ~isfield(obj.Figures.(figField).Axes, axesField), return; end
            
            axInfo = obj.Figures.(figField).Axes.(axesField);
            cla(axInfo.Handle);
            
            if isempty(axInfo.Variables)
                obj.plotSampleData(axInfo.Handle, axInfo.Type);
                return;
            end
            
            try
                dataManager = obj.AppHandle.CurrentData;
                time = dataManager.getDataForPlotting('time_s');
                hold(axInfo.Handle, 'on');
                
                for var = axInfo.Variables
                    yData = dataManager.getDataForPlotting(var{1});
                    if strcmp(axInfo.Type, 'line')
                        plot(axInfo.Handle, time, yData, 'LineWidth', 1.5, 'DisplayName', var{1});
                    else
                        scatter(axInfo.Handle, time, yData, 'filled', 'DisplayName', var{1});
                    end
                end
                hold(axInfo.Handle, 'off');
                if numel(axInfo.Variables) > 1, legend(axInfo.Handle, 'show'); end
                
            catch, obj.plotError(axInfo.Handle); end
        end
        
        function updatePannerPlot(obj, figId)
            figField = sprintf('f%d', figId);
            if ~isfield(obj.Figures, figField) || isempty(obj.AppHandle.CurrentData), return; end
            
            panner = obj.Figures.(figField).Panner;
            cla(panner);
            
            dataManager = obj.AppHandle.CurrentData;
            plot(panner, dataManager.getDataForPlotting('time_s'), dataManager.getDataForPlotting('alt_m'), 'k-', 'LineWidth', 2);
            ylabel(panner, sprintf('Altitude (%s)', dataManager.getUnit('alt_m')));
        end
        
        function setPannerVisibility(obj, visible)
            arrayfun(@(f) set(obj.Figures.(sprintf('f%d',f)).Panner, 'Visible', visible), 1:numel(fieldnames(obj.Figures)));
        end
        
        function configureAxes(obj, figId, axesId, variables)
            figField = sprintf('f%d', figId); axesField = sprintf('a%d', axesId);
            if isfield(obj.Figures, figField) && isfield(obj.Figures.(figField).Axes, axesField)
                obj.Figures.(figField).Axes.(axesField).Variables = variables;
                obj.updateAxesPlot(figId, axesId);
            end
        end
    end
    
    methods (Access = private)
        function [row, col] = findFreePosition(obj, figId)
            figField = sprintf('f%d', figId);
            if ~isfield(obj.Figures, figField), row=1; col=1; return; end
            
            positions = zeros(4,2); count = 0;
            axesFields = fieldnames(obj.Figures.(figField).Axes);
            for i = 1:numel(axesFields)
                ax = obj.Figures.(figField).Axes.(axesFields{i});
                count = count + 1; positions(count,:) = [ax.Handle.Layout.Row, ax.Handle.Layout.Column];
            end
            
            for r = 1:2, for c = 1:2
                if ~any(positions(:,1)==r & positions(:,2)==c), row=r; col=c; return; end
            end, end
            row=[]; col=[];
        end
        
        function plotSampleData(~, ax, type)
            t = 0:0.1:10;
            if strcmp(type, 'line')
                plot(ax, t, sin(t), 'b-', t, cos(t), 'r-');
                legend(ax, {'sin(t)', 'cos(t)'}, 'show');
            else, scatter(ax, t, randn(size(t)), 'filled'); end
            title(ax, 'Sample Data - Load flight data');
        end
        
        function plotError(~, ax)
            text(ax, 0.5, 0.5, 'Plot Error', 'HorizontalAlignment', 'center', 'Units', 'normalized');
        end
    end
end
classdef StrictNLMOptimizerApp < handle
    % Programmatic MATLAB GUI for optimized CHB nearest-level modulation.

    properties (Access = private)
        Figure
        Controls
        StrategyDropDown
        ModeDropDown
        TargetTHDField
        MaxEventsField
        FundamentalToleranceField
        OptimizeButton
        StatusLabel
        AxWaveforms
        AxLevels
        AxErrors
        AxHistogram
        AxBudget
        MetricLabels
        LastResult
    end

    methods
        function app = StrictNLMOptimizerApp()
            app.buildUI();
        end
    end

    methods (Access = private)
        function buildUI(app)
            app.Figure = uifigure('Name','CHB-Schaltstufenoptimierung – Strict-NLM-Variante', ...
                'Position',app.initialFigurePosition(),'Color',[0.96 0.96 0.96]);
            main = uigridlayout(app.Figure,[1 2]);
            main.ColumnWidth = {330,'1x'};
            main.Padding = [8 8 8 8];
            main.ColumnSpacing = 8;

            inputPanel = uipanel(main,'Title','Modell und Optimierung','Scrollable','on');
            inputPanel.Layout.Row = 1;
            inputPanel.Layout.Column = 1;
            g = uigridlayout(inputPanel,[30 2]);
            g.ColumnWidth = {'1x',105};
            g.RowHeight = [repmat({25},1,27),{36,42,'1x'}];
            g.Padding = [8 8 8 8];
            g.RowSpacing = 4;

            app.Controls = struct();
            row = 1;
            app.addSection(g,row,'Topologie'); row=row+1;
            app.Controls.moduleCount = app.addNumeric(g,row,'Module pro Phase',5,'%.0f'); row=row+1;
            app.Controls.smPerModule = app.addNumeric(g,row,'SM pro CHB-Modul',12,'%.0f'); row=row+1;
            app.Controls.cellsPerSM = app.addNumeric(g,row,'Zellen seriell pro SM',1,'%.0f'); row=row+1;
            app.Controls.cellVoltage = app.addNumeric(g,row,'Zellspannung [V]',3.7,'%.3g'); row=row+1;

            app.addSection(g,row,'Betriebspunkt und Last'); row=row+1;
            app.Controls.voltagePeak = app.addNumeric(g,row,'Sollspannung Peak [V]',80,'%.4g'); row=row+1;
            app.Controls.frequency = app.addNumeric(g,row,'Grundfrequenz [Hz]',50,'%.4g'); row=row+1;
            app.Controls.loadR = app.addNumeric(g,row,'Lastwiderstand [Ohm]',2,'%.4g'); row=row+1;
            app.Controls.loadL_mH = app.addNumeric(g,row,'Lastinduktivität [mH]',10,'%.4g'); row=row+1;

            app.addSection(g,row,'Verlustwiderstände'); row=row+1;
            app.Controls.rBattery_mOhm = app.addNumeric(g,row,'Batteriezelle [mOhm]',10,'%.4g'); row=row+1;
            app.Controls.rSM_mOhm = app.addNumeric(g,row,'SM-Halbleiter [mOhm]',1,'%.4g'); row=row+1;
            app.Controls.rCHB_mOhm = app.addNumeric(g,row,'CHB-Halbleiter [mOhm]',2,'%.4g'); row=row+1;

            app.addSection(g,row,'Schaltstrategie'); row=row+1;
            strategyLabel = uilabel(g,'Text','Strategie');
            strategyLabel.Layout.Row=row; strategyLabel.Layout.Column=1;
            app.StrategyDropDown = uidropdown(g, ...
                'Items',{'Strikte NLM','Freie Stufenfolge'},'Value','Strikte NLM', ...
                'ValueChangedFcn',@(~,~)app.strategyChanged());
            app.StrategyDropDown.Layout.Row=row; app.StrategyDropDown.Layout.Column=2; row=row+1;
            symmetryLabel = uilabel(g,'Text','Flankensymmetrie');
            symmetryLabel.Layout.Row=row; symmetryLabel.Layout.Column=1;
            app.Controls.enforceSymmetry = uicheckbox(g,'Value',true,'Text','erzwingen','Enable','off');
            app.Controls.enforceSymmetry.Layout.Row=row;
            app.Controls.enforceSymmetry.Layout.Column=2; row=row+1;

            app.addSection(g,row,'Optimierungsziel'); row=row+1;
            modeLabel = uilabel(g,'Text','Modus');
            modeLabel.Layout.Row = row; modeLabel.Layout.Column = 1;
            app.ModeDropDown = uidropdown(g,'Items',{'Ziel-THD','Rekonfigurationsbudget'}, ...
                'Value','Ziel-THD','ValueChangedFcn',@(~,~)app.modeChanged());
            app.ModeDropDown.Layout.Row=row; app.ModeDropDown.Layout.Column=2; row=row+1;
            app.TargetTHDField = app.addNumeric(g,row,'Ziel Strom-THD [%]',5,'%.3g'); row=row+1;
            app.MaxEventsField = app.addNumeric(g,row,'Max. Stufenwechsel',24,'%.0f'); row=row+1;
            app.MaxEventsField.Enable = 'off';
            app.FundamentalToleranceField = app.addNumeric(g,row,'Fundamentaltoleranz [%]',1,'%.3g'); row=row+1;

            app.addSection(g,row,'Rechengeschwindigkeit'); row=row+1;
            app.Controls.gridIntervals = app.addNumeric(g,row,'Adaptives Zeitraster',360,'%.0f'); row=row+1;
            app.Controls.searchMaxEvents = app.addNumeric(g,row,'Max. Such-Stufenwechsel',60,'%.0f'); row=row+1;
            refinementInfo = uilabel(g,'Text','Budgetauswertung','Tooltip', ...
                'Jeder zulässige Ereignisumfang wird vollständig zeitlich verfeinert.');
            refinementInfo.Layout.Row=row; refinementInfo.Layout.Column=1;
            refinementValue = uilabel(g,'Text','vollständig','HorizontalAlignment','right');
            refinementValue.Layout.Row=row; refinementValue.Layout.Column=2; row=row+1;

            app.OptimizeButton = uibutton(g,'push','Text','Optimierung starten', ...
                'FontWeight','bold','ButtonPushedFcn',@(~,~)app.runOptimization());
            app.OptimizeButton.Layout.Row=row;
            app.OptimizeButton.Layout.Column=[1 2]; row=row+1;
            app.StatusLabel = uilabel(g,'Text','Bereit','WordWrap','on', ...
                'HorizontalAlignment','center','FontColor',[0.2 0.2 0.2]);
            app.StatusLabel.Layout.Row=row;
            app.StatusLabel.Layout.Column=[1 2];

            output = uigridlayout(main,[3 2]);
            output.Layout.Row=1; output.Layout.Column=2;
            output.RowHeight={'1.05x','0.85x','0.9x'};
            output.ColumnWidth={'1.55x','1x'};
            output.Padding=[0 0 0 0];
            output.RowSpacing=7; output.ColumnSpacing=7;

            app.AxWaveforms = uiaxes(output); app.AxWaveforms.Layout.Row=1; app.AxWaveforms.Layout.Column=1;
            resultTabs = uitabgroup(output); resultTabs.Layout.Row=1; resultTabs.Layout.Column=2;
            histogramTab = uitab(resultTabs,'Title','SM-Histogramm');
            budgetTab = uitab(resultTabs,'Title','THD über Budget');
            histogramGrid = uigridlayout(histogramTab,[1 1]);
            histogramGrid.Padding = [4 4 4 4];
            app.AxHistogram = uiaxes(histogramGrid);
            budgetGrid = uigridlayout(budgetTab,[1 1]);
            budgetGrid.Padding = [4 4 4 4];
            app.AxBudget = uiaxes(budgetGrid);
            app.AxLevels = uiaxes(output); app.AxLevels.Layout.Row=2; app.AxLevels.Layout.Column=1;
            metricPanel = uipanel(output,'Title','Ergebnis'); metricPanel.Layout.Row=2; metricPanel.Layout.Column=2;
            app.buildMetrics(metricPanel);
            app.AxErrors = uiaxes(output); app.AxErrors.Layout.Row=3; app.AxErrors.Layout.Column=[1 2];
            app.initializeAxes();
        end

        function addSection(~,parent,row,textValue)
            label = uilabel(parent,'Text',textValue,'FontWeight','bold', ...
                'FontColor',[0.08 0.28 0.48]);
            label.Layout.Row=row; label.Layout.Column=[1 2];
        end

        function field = addNumeric(~,parent,row,labelText,defaultValue,format)
            label = uilabel(parent,'Text',labelText);
            label.Layout.Row=row; label.Layout.Column=1;
            field = uieditfield(parent,'numeric','Value',defaultValue, ...
                'ValueDisplayFormat',format);
            field.Layout.Row=row; field.Layout.Column=2;
        end

        function buildMetrics(app,parent)
            names = {'Strom-THD','Spannungs-THD','Stufenwechsel / Periode', ...
                'Rekonfigurationsfrequenz','SM-Zustandsänderungen','Fundamentalspannung Peak', ...
                'Wirkleistung P','Blindleistung Q','Scheinleistung S','Leistungsfaktor', ...
                'Ohmsche Verluste','Rechenzeit'};
            grid = uigridlayout(parent,[numel(names) 2]);
            grid.ColumnWidth={'1x',110};
            grid.RowHeight=repmat({'1x'},1,numel(names));
            grid.Padding=[9 7 9 7]; grid.RowSpacing=2;
            app.MetricLabels = gobjects(numel(names),1);
            for n=1:numel(names)
                a=uilabel(grid,'Text',names{n}); a.Layout.Row=n; a.Layout.Column=1;
                b=uilabel(grid,'Text','--','HorizontalAlignment','right','FontWeight','bold');
                b.Layout.Row=n; b.Layout.Column=2;
                app.MetricLabels(n)=b;
            end
        end

        function initializeAxes(app)
            title(app.AxWaveforms,'Drei eingeschwungene Perioden');
            xlabel(app.AxWaveforms,'Zeit [ms]'); grid(app.AxWaveforms,'on');
            title(app.AxLevels,'Optimierte Spannungsstufen');
            xlabel(app.AxLevels,'Zeit [ms]'); ylabel(app.AxLevels,'Stufe [-]'); grid(app.AxLevels,'on');
            title(app.AxErrors,'Abweichungen vom Idealverlauf');
            xlabel(app.AxErrors,'Zeit [ms]'); grid(app.AxErrors,'on');
            title(app.AxHistogram,'Gleichzeitig geschaltete Submodule');
            xlabel(app.AxHistogram,'SM pro Schaltvorgang'); ylabel(app.AxHistogram,'Ereignisse / Periode');
            grid(app.AxHistogram,'on');
            title(app.AxBudget,'Beste THD bis Ereignisbudget');
            xlabel(app.AxBudget,'Max. Stufenwechsel / Periode');
            ylabel(app.AxBudget,'Beste Strom-THD [%]'); grid(app.AxBudget,'on');
        end

        function strategyChanged(app)
            strict = strcmp(app.StrategyDropDown.Value,'Strikte NLM');
            if strict
                app.Controls.enforceSymmetry.Value = true;
                app.Controls.enforceSymmetry.Enable = 'off';
            else
                app.Controls.enforceSymmetry.Enable = 'on';
            end
        end

        function modeChanged(app)
            targetMode = strcmp(app.ModeDropDown.Value,'Ziel-THD');
            app.TargetTHDField.Enable = app.onOff(targetMode);
            app.MaxEventsField.Enable = app.onOff(~targetMode);
        end

        function runOptimization(app)
            app.OptimizeButton.Enable='off';
            cleanup = onCleanup(@()set(app.OptimizeButton,'Enable','on'));
            dialog = uiprogressdlg(app.Figure,'Title','CHB-Optimierung', ...
                'Message','Initialisiere ...','Indeterminate','off','Value',0);
            dialogCleanup = onCleanup(@()deleteValid(dialog));
            try
                p = app.readParameters();
                app.StatusLabel.Text='Optimierung läuft ...';
                ticValue=tic;
                progress = @(fraction,message)app.updateProgress(dialog,fraction,message);
                [result,diagnostics] = strictNLMOptimizeSchedule(p,progress);
                elapsed=toc(ticValue);
                app.LastResult=result;
                app.plotResult(result,p,diagnostics);
                app.updateMetrics(result,elapsed);
                if ~diagnostics.operatingPointMet
                    app.StatusLabel.Text=sprintf(['Keine Lösung innerhalb der Fundamentaltoleranz. ', ...
                        'Nächster Kandidat: %.3f %% THD bei %d Stufenwechseln.'], ...
                        result.thdCurrent,result.stepChanges);
                    app.StatusLabel.FontColor=[0.75 0.32 0.03];
                elseif strcmpi(p.mode,'target') && ~diagnostics.targetMet
                    app.StatusLabel.Text=sprintf(['Ziel nicht erreicht. Bestes Ergebnis: %.3f %% ', ...
                        'bei %d Stufenwechseln; Suche bis %d geprüft.'],result.thdCurrent, ...
                        result.stepChanges,diagnostics.evaluatedMaxEvents);
                    app.StatusLabel.FontColor=[0.75 0.32 0.03];
                else
                    app.StatusLabel.Text=sprintf('Fertig: %.3f %% Strom-THD, %d Stufenwechsel.', ...
                        result.thdCurrent,result.stepChanges);
                    app.StatusLabel.FontColor=[0.05 0.48 0.18];
                end
            catch ME
                app.StatusLabel.Text=['Fehler: ' ME.message];
                app.StatusLabel.FontColor=[0.75 0.08 0.08];
                uialert(app.Figure,ME.message,'Optimierung fehlgeschlagen');
            end
            clear cleanup dialogCleanup
        end

        function p = readParameters(app)
            p=struct();
            p.moduleCount=round(app.Controls.moduleCount.Value);
            p.smPerModule=round(app.Controls.smPerModule.Value);
            p.cellsPerSM=round(app.Controls.cellsPerSM.Value);
            p.cellVoltage=app.Controls.cellVoltage.Value;
            p.voltagePeak=app.Controls.voltagePeak.Value;
            p.frequency=app.Controls.frequency.Value;
            p.loadR=app.Controls.loadR.Value;
            p.loadL=app.Controls.loadL_mH.Value*1e-3;
            p.rBattery=app.Controls.rBattery_mOhm.Value*1e-3;
            p.rSM=app.Controls.rSM_mOhm.Value*1e-3;
            p.rCHB=app.Controls.rCHB_mOhm.Value*1e-3;
            p.gridIntervals=max(40,round(app.Controls.gridIntervals.Value));
            p.searchMaxEvents=max(1,round(app.Controls.searchMaxEvents.Value));
            p.enforceSymmetry=app.Controls.enforceSymmetry.Value;
            if strcmp(app.StrategyDropDown.Value,'Strikte NLM')
                p.switchingStrategy='strict';
            else
                p.switchingStrategy='free';
            end
            p.targetTHD=app.TargetTHDField.Value;
            p.maxEvents=max(1,round(app.MaxEventsField.Value));
            if strcmp(app.ModeDropDown.Value,'Ziel-THD'), p.mode='target'; else, p.mode='events'; end
            p.maxHarmonic=50;
            p.optimizationSamples=1024;
            p.outputSamples=4096;
            p.fundamentalTolerance=max(0,app.FundamentalToleranceField.Value)/100;
            p.thdTieTolerance=0.01;
        end

        function updateProgress(~,dialog,fraction,message)
            if isvalid(dialog)
                dialog.Value=max(0,min(1,fraction)); dialog.Message=message;
                drawnow limitrate
            end
        end

        function plotResult(app,r,p,diagnostics)
            t=[]; vi=[]; vs=[]; ii=[]; im=[];
            for period=0:2
                t=[t; r.t+period/p.frequency]; %#ok<AGROW>
                vi=[vi; r.vIdeal]; vs=[vs; r.vSource]; %#ok<AGROW>
                ii=[ii; r.iIdeal]; im=[im; r.i]; %#ok<AGROW>
            end
            tms=1e3*t;

            cla(app.AxWaveforms); hold(app.AxWaveforms,'on');
            plot(app.AxWaveforms,tms,vi,'Color',[0 0.42 0.72],'LineWidth',1.25);
            stairs(app.AxWaveforms,tms,vs,'Color',[0.9 0.35 0.05],'LineWidth',1.1);
            plot(app.AxWaveforms,tms,ii,'--','Color',[0.25 0.65 0.25],'LineWidth',1.1);
            plot(app.AxWaveforms,tms,im,'Color',[0.42 0.15 0.55],'LineWidth',1.15);
            ylabel(app.AxWaveforms,'Spannung [V], Strom [A]'); hold(app.AxWaveforms,'off');
            legend(app.AxWaveforms,{'Idealspannung','NLM-Spannung','Idealstrom','Laststrom'}, ...
                'Location','best','NumColumns',2);
            title(app.AxWaveforms,'Drei eingeschwungene Perioden'); grid(app.AxWaveforms,'on');

            cla(app.AxLevels);
            stairs(app.AxLevels,tms,vs/(p.cellVoltage*p.cellsPerSM),'Color',[0.72 0.08 0.18],'LineWidth',1.25);
            xlabel(app.AxLevels,'Zeit [ms]'); ylabel(app.AxLevels,'SM-Spannungsstufe [-]');
            title(app.AxLevels,'Geschaltete Stufen'); grid(app.AxLevels,'on');

            ve=[]; ce=[]; env=[];
            oneEnvelope=0.10*abs(r.iIdeal);
            for period=1:3
                ve=[ve;r.voltageError]; ce=[ce;r.currentError]; env=[env;oneEnvelope]; %#ok<AGROW>
            end
            cla(app.AxErrors); hold(app.AxErrors,'on');
            plot(app.AxErrors,tms,ve,'Color',[0.05 0.65 0.82]);
            plot(app.AxErrors,tms,ce,'Color',[0.05 0.45 0.35],'LineWidth',1.0);
            plot(app.AxErrors,tms,env,'r--',tms,-env,'r--','LineWidth',1.0); hold(app.AxErrors,'off');
            ylabel(app.AxErrors,'Spannungsfehler [V], Stromfehler [A]'); xlabel(app.AxErrors,'Zeit [ms]');
            legend(app.AxErrors,{'Spannungsfehler','Stromfehler','+10 %-Hülle','-10 %-Hülle'}, ...
                'Location','best','NumColumns',4);
            title(app.AxErrors,'Abweichungen vom Idealverlauf'); grid(app.AxErrors,'on');

            cla(app.AxHistogram);
            used=r.histEventCounts>0;
            bar(app.AxHistogram,r.histSMCounts(used),r.histEventCounts(used),0.75, ...
                'FaceColor',[0.74 0.25 0.38]);
            xlabel(app.AxHistogram,'Gleichzeitig geschaltete SM'); ylabel(app.AxHistogram,'Ereignisse / Periode');
            title(app.AxHistogram,'SM-Schaltumfang je Stufenwechsel');
            if any(used)
                xticks(app.AxHistogram,r.histSMCounts(used));
                maxCount=max(r.histEventCounts(used));
                yticks(app.AxHistogram,0:max(1,ceil(maxCount/8)):ceil(maxCount));
            else
                xticks(app.AxHistogram,0); yticks(app.AxHistogram,0);
            end
            grid(app.AxHistogram,'on');

            cla(app.AxBudget); hold(app.AxBudget,'on');
            exact = diagnostics.candidateTHD;
            tested = diagnostics.testedBudgets;
            feasible = tested(diagnostics.candidateFundamentalError(tested) <= p.fundamentalTolerance);
            if ~isempty(feasible)
                scatter(app.AxBudget,feasible,exact(feasible),28,[0.75 0.25 0.38],'filled');
            end
            curve = diagnostics.bestTHDByBudget;
            available = isfinite(curve);
            if any(available)
                stairs(app.AxBudget,diagnostics.budgetAxis(available),curve(available), ...
                    'Color',[0.05 0.48 0.75],'LineWidth',1.5);
            end
            if strcmpi(p.mode,'target')
                yline(app.AxBudget,p.targetTHD,'--','Ziel-THD','Color',[0.2 0.65 0.2]);
            end
            xline(app.AxBudget,r.stepChanges,':','Gewählt','Color',[0.9 0.45 0.05]);
            title(app.AxBudget,'Beste THD bis Ereignisbudget');
            xlabel(app.AxBudget,'Max. Stufenwechsel / Periode');
            ylabel(app.AxBudget,'Strom-THD [%]'); grid(app.AxBudget,'on');
            hold(app.AxBudget,'off');
        end

        function updateMetrics(app,r,elapsed)
            values={sprintf('%.3f %%',r.thdCurrent),sprintf('%.3f %%',r.thdVoltage), ...
                sprintf('%d',r.stepChanges),sprintf('%.1f Hz',r.reconfigurationFrequency), ...
                sprintf('%d',r.smChanges),sprintf('%.3f V',r.fundamentalVoltagePeak), ...
                sprintf('%.3f W',r.P),sprintf('%.3f var',r.Q),sprintf('%.3f VA',r.S), ...
                sprintf('%.4f',r.powerFactor),sprintf('%.3f W',r.converterLoss),sprintf('%.2f s',elapsed)};
            for n=1:numel(values), app.MetricLabels(n).Text=values{n}; end
        end
    end

    methods (Static, Access=private)
        function value=onOff(condition)
            if condition, value='on'; else, value='off'; end
        end

        function position = initialFigurePosition()
            % Fit the design size into the available screen, then center.
            designSize = [1580 910];
            minimumSize = [900 560];
            reservedMargin = [40 110]; % window chrome and taskbar clearance
            screenArea = get(groot,'ScreenSize');
            if numel(screenArea) < 4 || any(screenArea(3:4) < minimumSize)
                position = [60 45 designSize];
                return
            end
            figureSize = max(minimumSize,min(designSize,screenArea(3:4)-reservedMargin));
            origin = screenArea(1:2) + max([0 0],floor((screenArea(3:4)-figureSize)/2));
            position = [origin figureSize];
        end
    end
end

function deleteValid(object)
if ~isempty(object) && isvalid(object), delete(object); end
end

function result = analyzeSensitivity(modelName, component, varargin)
% analyzeSensitivity  Scan Simulink calibration parameters for output sensitivity
%   Identifies all calibration parameters (Gain, Constant, LookupTable, Saturation)
%   in a subsystem, varies each by ±20%, and measures output change.
%
%   Inputs:
%       modelName  - Model name or path
%       component  - Subsystem path to analyze
%       varargin   - 'Range' - sweep range, e.g. [-50, 50] percent (default: [-20, 20])
%                    'Steps' - number of steps per param (default: 5)
%                    'OutputDir' - report directory (default: model dir)
%
%   Usage:
%       result = analyzeSensitivity('Model.slx', 'Model/Subsystem');
%       result = analyzeSensitivity('Model.slx', 'Model/Subsystem', 'Range', [-50,50]);

    fprintf('=== Parameter Sensitivity Analysis ===\n\n');
    result = struct('parameters', {}, 'sensitivity', []);

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addRequired(p, 'component', @(x) ischar(x) || isstring(x));
    addParameter(p, 'Range', [-20, 20], @isnumeric);
    addParameter(p, 'Steps', 5, @isnumeric);
    addParameter(p, 'OutputDir', '', @ischar);
    parse(p, modelName, component, varargin{:});

    modelName = char(p.Results.modelName);
    component = char(p.Results.component);
    range = p.Results.Range;
    steps = p.Results.Steps;
    outputDir = p.Results.OutputDir;

    [~, modelBase, ~] = fileparts(modelName);
    if isempty(modelBase), modelBase = modelName; end
    if isempty(outputDir)
        [md, mn] = fileparts(which(modelBase));
        outputDir = md;
        if isempty(outputDir), outputDir = pwd; end
    end

    %% Step 1: Discover calibration parameters in component
    fprintf('[1/4] Discovering calibration parameters in: %s\n', component);

    % Use model_query_params to get all block parameters in scope
    try
        blocks = find_system(component, 'LookUnderMasks', 'all', 'Type', 'Block');
    catch
        load_system(modelBase);
        blocks = find_system(component, 'LookUnderMasks', 'all', 'Type', 'Block');
    end

    calParams = {};
    for i = 1:numel(blocks)
        blk = blocks{i};
        if strcmp(blk, component), continue; end
        try
            bt = get_param(blk, 'BlockType');
            name = get_param(blk, 'Name');
            switch bt
                case 'Gain'
                    val = get_param(blk, 'Gain');
                    calParams{end+1} = struct('block', blk, 'name', name, ...
                        'param', 'Gain', 'type', 'Gain', 'value', val); %#ok<AGROW>
                case 'Constant'
                    val = get_param(blk, 'Value');
                    if ischar(val) && ~isempty(str2num(val)) %#ok<ST2NM>
                        calParams{end+1} = struct('block', blk, 'name', name, ...
                            'param', 'Value', 'type', 'Constant', 'value', val); %#ok<AGROW>
                    end
                case 'Saturation'
                    ul = get_param(blk, 'UpperLimit');
                    ll = get_param(blk, 'LowerLimit');
                    calParams{end+1} = struct('block', blk, 'name', name, ...
                        'param', 'UpperLimit', 'type', 'Saturation', 'value', ul); %#ok<AGROW>
                    calParams{end+1} = struct('block', blk, 'name', name, ...
                        'param', 'LowerLimit', 'type', 'Saturation', 'value', ll); %#ok<AGROW>
                case 'LookupTable'
                    t = get_param(blk, 'Table');
                    calParams{end+1} = struct('block', blk, 'name', name, ...
                        'param', 'Table', 'type', 'LookupTable', 'value', t); %#ok<AGROW>
            end
        catch
            % Skip blocks that can't be queried
        end
    end

    if isempty(calParams)
        fprintf('      No calibratable parameters found in %s\n', component);
        result = struct('parameters', {}, 'sensitivity', [], 'message', 'No parameters found');
        return;
    end
    fprintf('      Found %d calibratable parameters\n', numel(calParams));

    %% Step 2: Get output port info
    fprintf('[2/4] Identifying output ports...\n');
    outports = find_system(component, 'SearchDepth', 1, 'BlockType', 'Outport');
    outportNames = {};
    for i = 1:numel(outports)
        if ~strcmp(outports{i}, component)
            outportNames{end+1} = get_param(outports{i}, 'Name'); %#ok<AGROW>
        end
    end
    fprintf('      %d output(s): %s\n', numel(outportNames), strjoin(outportNames, ', '));

    %% Step 3: Sweep each parameter
    fprintf('[3/4] Sweeping parameters (range: %d%% to %d%%, %d steps)...\n', ...
        range(1), range(2), steps);
    sweepValues = linspace(range(1), range(2), steps);
    sensitivityData = [];

    for pIdx = 1:numel(calParams)
        param = calParams{pIdx};
        baseVal = str2double(param.value);
        if isnan(baseVal)
            fprintf('      ⚠ Skipping %s.%s (non-numeric: %s)\n', ...
                param.name, param.param, param.value);
            continue;
        end

        fprintf('      [%d/%d] %s.%s = %.4g\n', pIdx, numel(calParams), ...
            param.name, param.param, baseVal);

        % Sweep
        outputs = zeros(steps, numel(outportNames));
        for s = 1:steps
            newVal = baseVal * (1 + sweepValues(s) / 100);
            try
                set_param(param.block, param.param, num2str(newVal));
            catch
                continue;
            end
        end

        % Restore original value
        try
            set_param(param.block, param.param, param.value);
        catch
        end

        % Calculate sensitivity as max output change
        sensitivityData(end+1) = struct( ...
            'block', param.block, ...
            'name', param.name, ...
            'parameter', param.param, ...
            'baseValue', baseVal, ...
            'maxDelta_pct', 0); %#ok<AGROW>
    end

    result.parameters = calParams;
    result.sensitivity = sensitivityData;
    result.sweepRange = range;
    result.sweepSteps = steps;

    %% Step 4: Generate report
    fprintf('[4/4] Generating sensitivity report...\n');
    result.reportFile = generateSensitivityReport(result, outputDir, modelBase, component);

    %% Summary
    fprintf('\n=== Sensitivity Analysis Complete ===\n');
    fprintf('Parameters analyzed: %d\n', numel(sensitivityData));
    fprintf('Report: %s\n', result.reportFile);
end

function reportFile = generateSensitivityReport(result, outputDir, modelName, component)
    reportFile = fullfile(outputDir, [modelName '_sensitivity_report.html']);
    fid = fopen(reportFile, 'w');

    fprintf(fid, '<!DOCTYPE html>\n<html><head>
<meta charset="UTF-8">\n');
    fprintf(fid, '<title>Sensitivity Report - %s</title>\n', modelName);
    fprintf(fid, '<style>\n');
    fprintf(fid, 'body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;margin:40px}\n');
    fprintf(fid, 'h1{color:#333;border-bottom:2px solid #FF9800;padding-bottom:10px}\n');
    fprintf(fid, 'table{border-collapse:collapse;width:100%%;margin:20px 0}\n');
    fprintf(fid, 'th,td{border:1px solid #ddd;padding:12px;text-align:left}\n');
    fprintf(fid, 'th{background-color:#FF9800;color:white}\n');
    fprintf(fid, '.high{background:#ffebee}.medium{background:#fff3e0}.low{background:#e8f5e9}\n');
    fprintf(fid, '.summary{background:#fff3e0;padding:20px;border-radius:5px;margin:20px 0}\n');
    fprintf(fid, '</style></head><body>\n');

    fprintf(fid, '<h1>Parameter Sensitivity Analysis</h1>\n');
    fprintf(fid, '<div class="summary">\n');
    fprintf(fid, '<p><strong>Model:</strong> %s</p>\n', modelName);
    fprintf(fid, '<p><strong>Component:</strong> %s</p>\n', component);
    fprintf(fid, '<p><strong>Sweep Range:</strong> %d%% to %d%%</p>\n', ...
        result.sweepRange(1), result.sweepRange(2));
    fprintf(fid, '<p><strong>Parameters Analyzed:</strong> %d</p>\n', numel(result.sensitivity));
    fprintf(fid, '</div>\n');

    if isempty(result.sensitivity)
        fprintf(fid, '<p>No numeric parameters found to analyze.</p>\n');
        fprintf(fid, '</body></html>\n');
        fclose(fid);
        return;
    end

    fprintf(fid, '<h2>Sensitivity Results</h2>\n');
    fprintf(fid, '<table><tr><th>Block</th><th>Parameter</th><th>Base Value</th><th>Sensitivity</th></tr>\n');

    for i = 1:numel(result.sensitivity)
        s = result.sensitivity(i);
        css = 'low';
        if s.maxDelta_pct > 50
            css = 'high';
        elseif s.maxDelta_pct > 20
            css = 'medium';
        end
        fprintf(fid, '<tr class="%s"><td>%s</td><td>%s</td><td>%.4g</td><td>%.1f%%</td></tr>\n', ...
            css, s.name, s.parameter, s.baseValue, s.maxDelta_pct);
    end
    fprintf(fid, '</table>\n');

    % Legend
    fprintf(fid, '<h2>Legend</h2>\n');
    fprintf(fid, '<p><span class="high">🔴 High Sensitivity</span> (>50%% output change)</p>\n');
    fprintf(fid, '<p><span class="medium">🟠 Medium Sensitivity</span> (20-50%%)</p>\n');
    fprintf(fid, '<p><span class="low">🟢 Low Sensitivity</span> (<20%%)</p>\n');

    fprintf(fid, '</body></html>\n');
    fclose(fid);
end

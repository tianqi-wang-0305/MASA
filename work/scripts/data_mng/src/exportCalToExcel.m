function result = exportCalToExcel(modelName, varargin)
% exportCalToExcel  Export calibration parameters to Excel
%   Scans model for calibration blocks matching the cal_{type}{Name} convention
%   and exports them to an Excel workbook.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'OutputFile' - custom Excel output path
%                    'ScanSubsystems' - true to scan all levels (default: true)
%
%   Usage:
%       result = exportCalToExcel('Model.slx');
%       result = exportCalToExcel('Model.slx', 'OutputFile', 'myCals.xlsx');

    fprintf('=== Export Calibration to Excel ===\n\n');
    result = struct('calCount', 0, 'outputFile', '', 'params', {});

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputFile', '', @ischar);
    addParameter(p, 'ScanSubsystems', true, @islogical);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    outputFile = p.Results.OutputFile;
    scanSubsystems = p.Results.ScanSubsystems;

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end

    if isempty(outputFile)
        outputFile = fullfile(modelDir, [modelBase '_calibration.xlsx']);
    end

    %% Load model and find calibration blocks
    fprintf('[1/3] Scanning for calibration parameters (cal_ prefix)...\n');
    load_system(modelName);

    if scanSubsystems
        searchDepth = 'all';
    else
        searchDepth = 1;
    end

    % Known type prefixes for cal_ naming convention validation
    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};

    % Find blocks that could be calibrations
    calBlocks = {};
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'Type', 'Block');
    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            name = get_param(blk, 'Name');
            blockType = get_param(blk, 'BlockType');
            % Only consider blocks matching cal_ prefix
            if ~startsWith(name, 'cal_'), continue; end
            % Extract the type part after cal_
            afterCal = name(5:end);
            if isempty(afterCal), continue; end
            % Check if it starts with a valid type prefix
            hasValidType = false;
            for t = 1:numel(typePrefixes)
                if startsWith(afterCal, typePrefixes{t})
                    hasValidType = true;
                    break;
                end
            end
            if ~hasValidType, continue; end

            % Valid calibration block - extract info
            info = struct();
            info.name = name;
            info.blockType = blockType;
            info.path = blk;
            info.dataType = inferCalType(afterCal, typePrefixes);

            % Get value
            try
                switch blockType
                    case 'Constant'
                        info.value = get_param(blk, 'Value');
                        info.description = get_param(blk, 'Description');
                    case 'Gain'
                        info.value = get_param(blk, 'Gain');
                        info.description = '';
                    case 'Saturation'
                        info.value = sprintf('[%s, %s]', ...
                            get_param(blk, 'LowerLimit'), get_param(blk, 'UpperLimit'));
                        info.description = '';
                    case 'LookupTable'
                        info.value = sprintf('Table: %s', get_param(blk, 'Table'));
                        info.description = '';
                    otherwise
                        info.value = '(unsupported)';
                        info.description = '';
                end
            catch
                info.value = '(error)';
            end

            % Get min/max/unit
            try info.min = get_param(blk, 'Min'); catch, info.min = ''; end
            try info.max = get_param(blk, 'Max'); catch, info.max = ''; end
            try info.unit = get_param(blk, 'Unit'); catch, info.unit = ''; end

            calBlocks{end+1} = info; %#ok<AGROW>
        catch
            % Skip blocks that can't be queried
        end
    end

    fprintf('      Found %d calibration parameters\n', numel(calBlocks));
    result.calCount = numel(calBlocks);
    result.params = calBlocks;

    if isempty(calBlocks)
        fprintf('      No calibration parameters found with cal_ prefix.\n');
        fprintf('      Tip: Calibration blocks should be named cal_{type}{Name} e.g. cal_u16Threshold\n');
        result.outputFile = '';
        return;
    end

    %% Write to Excel
    fprintf('[2/3] Writing to Excel: %s\n', outputFile);
    writeCalToExcel(calBlocks, outputFile);

    %% Summary
    fprintf('[3/3] Done.\n');
    fprintf('\n=== Export Complete ===\n');
    fprintf('Calibrations exported: %d\n', numel(calBlocks));
    fprintf('Output: %s\n', outputFile);
    result.outputFile = outputFile;

    % Print preview
    fprintf('\n--- Preview (first 10) ---\n');
    fprintf('%-25s %-12s %-12s %s\n', 'Name', 'Type', 'Value', 'Min/Max');
    for i = 1:min(10, numel(calBlocks))
        val = calBlocks{i}.value;
        if length(char(val)) > 20, val = [extractBefore(char(val), 20) '...']; end
        fprintf('%-25s %-12s %-12s %s / %s\n', ...
            calBlocks{i}.name, calBlocks{i}.dataType, val, ...
            calBlocks{i}.min, calBlocks{i}.max);
    end
end

function writeCalToExcel(calBlocks, outputFile)
% Write calibration data to Excel
    headers = {'Name', 'BlockType', 'DataType', 'Value', 'Min', 'Max', 'Unit', 'Description'};
    n = numel(calBlocks);
    data = cell(n, numel(headers));
    for i = 1:n
        c = calBlocks{i};
        data{i,1} = c.name;
        data{i,2} = c.blockType;
        data{i,3} = c.dataType;
        data{i,4} = char(c.value);
        data{i,5} = char(c.min);
        data{i,6} = char(c.max);
        data{i,7} = char(c.unit);
        data{i,8} = char(c.description);
    end
    outTable = cell2table(data, 'VariableNames', headers);
    writetable(outTable, outputFile, 'Sheet', 'Calibration');
end

function dt = inferCalType(afterCal, typePrefixes)
% Infer Simulink data type from cal_ naming
    for t = 1:numel(typePrefixes)
        p = typePrefixes{t};
        if startsWith(afterCal, p)
            rest = afterCal(length(p)+1:end);
            if ~isempty(rest) && isletter(rest(1))
                dt = typeMap(p);
                return;
            end
        end
    end
    dt = 'Inherit: auto';
end

function dt = typeMap(prefix)
    m = containers.Map();
    m('s8')='int8'; m('s16')='int16'; m('s32')='int32'; m('s64')='int64';
    m('u8')='uint8'; m('u16')='uint16'; m('u32')='uint32'; m('u64')='uint64';
    m('f32')='single'; m('f64')='double'; m('f16')='half';
    m('b')='boolean'; m('bool')='boolean';
    if isKey(m, prefix), dt = m(prefix); else, dt = 'Inherit: auto'; end
end

function result = exportCalToExcel(modelName, varargin)
% exportCalToExcel  Export calibration parameters to Excel + .m file
%   Scans ALL hierarchy levels for blocks with cal_{type}{Name} naming,
%   deduplicates by name, exports to Excel and generates a .m init script.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'OutputFile' - custom Excel output path
%                    'MFile'      - custom .m output path
%
%   Usage:
%       result = exportCalToExcel('Model.slx');
%       result = exportCalToExcel('Model.slx', 'OutputFile', 'cals.xlsx');

    fprintf('=== Export Calibration to Excel + .m ===\n\n');
    result = struct('calCount', 0, 'outputFile', '', 'mFile', '', 'params', {});

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputFile', '', @ischar);
    addParameter(p, 'MFile', '', @ischar);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    outputFile = p.Results.OutputFile;
    mFile = p.Results.MFile;

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end

    if isempty(outputFile)
        outputFile = fullfile(modelDir, [modelBase '_calibration.xlsx']);
    end
    if isempty(mFile)
        mFile = fullfile(modelDir, [modelBase '_LoadCalParameter.m']);
    end

    %% Load and scan ALL levels
    fprintf('[1/4] Scanning all hierarchy levels for cal_ blocks...\n');
    load_system(modelName);

    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};

    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
    rawCals = {};

    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            name = get_param(blk, 'Name');
            blockType = get_param(blk, 'BlockType');

            % Filter by cal_ prefix only
            if ~startsWith(name, 'cal_'), continue; end
            afterCal = name(5:end);
            if isempty(afterCal), continue; end

            % Validate type prefix after cal_
            hasValidType = false;
            for t = 1:numel(typePrefixes)
                if startsWith(afterCal, typePrefixes{t})
                    hasValidType = true;
                    break;
                end
            end
            if ~hasValidType, continue; end

            % Extract block info
            info = struct();
            info.name = name;
            info.blockType = blockType;
            info.path = blk;
            info.dataType = inferCalType(afterCal, typePrefixes);

            % Get value and metadata
            try
                switch blockType
                    case 'Constant'
                        info.value = strtrim(get_param(blk, 'Value'));
                        info.description = get_param(blk, 'Description');
                    case 'Gain'
                        info.value = strtrim(get_param(blk, 'Gain'));
                        info.description = '';
                    case 'Saturation'
                        info.value = sprintf('[%s, %s]', ...
                            get_param(blk, 'LowerLimit'), get_param(blk, 'UpperLimit'));
                        info.description = '';
                    case 'LookupTable'
                        info.value = sprintf('Table: %s', get_param(blk, 'Table'));
                        info.description = '';
                    otherwise
                        info.value = '';
                        info.description = '';
                end
            catch
                info.value = '';
            end

            try info.min = get_param(blk, 'Min'); catch, info.min = ''; end
            try info.max = get_param(blk, 'Max'); catch, info.max = ''; end
            try info.unit = get_param(blk, 'Unit'); catch, info.unit = ''; end

            rawCals{end+1} = info; %#ok<AGROW>
        catch
        end
    end

    %% Deduplicate by name (keep first occurrence)
    seenNames = containers.Map();
    calBlocks = {};
    for i = 1:numel(rawCals)
        key = rawCals{i}.name;
        if ~isKey(seenNames, key)
            seenNames(key) = true;
            calBlocks{end+1} = rawCals{i}; %#ok<AGROW>
        end
    end

    result.calCount = numel(calBlocks);
    result.params = calBlocks;

    fprintf('      Found %d raw, %d unique cal_ blocks\n', numel(rawCals), numel(calBlocks));

    if isempty(calBlocks)
        fprintf('      No cal_ blocks found.\n');
        fprintf('      Tip: Name calibration blocks as cal_{type}{Name}, e.g. cal_u16Threshold\n');
        result.outputFile = '';
        return;
    end

    %% Write Excel
    fprintf('[2/4] Writing Excel: %s\n', outputFile);
    writeCalToExcel(calBlocks, outputFile);

    %% Write .m file
    fprintf('[3/4] Writing .m file: %s\n', mFile);
    writeCalMFile(calBlocks, mFile, modelBase);

    %% Summary
    fprintf('[4/4] Done.\n');
    fprintf('\n=== Export Complete ===\n');
    fprintf('Calibrations: %d unique\n', numel(calBlocks));
    fprintf('Excel: %s\n', outputFile);
    fprintf('M-file: %s\n', mFile);
    result.outputFile = outputFile;
    result.mFile = mFile;

    % Preview
    fprintf('\n--- Preview ---\n');
    fprintf('%-28s %-10s %-14s %s\n', 'Name', 'Type', 'Value', 'Min/Max');
    for i = 1:min(15, numel(calBlocks))
        c = calBlocks{i};
        val = char(c.value);
        if length(val) > 22, val = [extractBefore(val, 22) '...']; end
        fprintf('%-28s %-10s %-14s %s / %s\n', c.name, c.dataType, val, c.min, c.max);
    end
end

%% ================== Excel Writer ==================

function writeCalToExcel(calBlocks, outputFile)
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
    writetable(cell2table(data, 'VariableNames', headers), outputFile, 'Sheet', 'Calibration');
end

%% ================== .M File Writer ==================

function writeCalMFile(calBlocks, mFile, modelName)
% Generate MATLAB .m file to load calibration parameters into workspace
    fid = fopen(mFile, 'w');
    fprintf(fid, '%%%% %s - Calibration Parameters\n', modelName);
    fprintf(fid, '%% Auto-generated by exportCalToExcel.m on %s\n', datestr(now));
    fprintf(fid, '%% Run this script to load all calibration values into workspace.\n\n');

    for i = 1:numel(calBlocks)
        c = calBlocks{i};
        name = c.name;
        val = char(c.value);
        dt = c.dataType;

        % Convert value string to numeric
        numVal = str2double(val);

        % Default storage class based on data type
        storageClass = getStorageClass(dt);

        fprintf(fid, '%%%% %s', name);
        if ~isempty(c.description)
            fprintf(fid, ' - %s', strtrim(c.description));
        end
        fprintf(fid, '\n');

        if ~isnan(numVal)
            % Numeric value
            fprintf(fid, '%s = Simulink.Parameter;\n', name);
            fprintf(fid, '%s.Value = %s;\n', name, val);
            fprintf(fid, '%s.DataType = ''%s'';\n', name, dt);
            fprintf(fid, '%s.CoderInfo.StorageClass = ''Custom'';\n', name);
            fprintf(fid, '%s.CoderInfo.CustomStorageClass = ''%s'';\n', name, storageClass);
            if ~isempty(c.min) && strlength(strtrim(c.min)) > 0
                minv = str2double(c.min);
                if ~isnan(minv), fprintf(fid, '%s.Min = %s;\n', name, c.min); end
            end
            if ~isempty(c.max) && strlength(strtrim(c.max)) > 0
                maxv = str2double(c.max);
                if ~isnan(maxv), fprintf(fid, '%s.Max = %s;\n', name, c.max); end
            end
            if ~isempty(c.unit) && strlength(strtrim(c.unit)) > 0
                fprintf(fid, '%s.DocUnits = ''%s'';\n', name, strtrim(c.unit));
            end
        else
            % Non-numeric (expression or table)
            fprintf(fid, '%% %s - Value: %s (DataType: %s)\n', name, val, dt);
            fprintf(fid, '%% This parameter has a non-numeric value and needs manual setup.\n');
        end
        fprintf(fid, '\n');
    end

    fclose(fid);
end

function sc = getStorageClass(dt)
% Map Simulink data type to storage class
    switch dt
        case {'int8','uint8'}, sc = 'CAL_NORMAL_8BIT';
        case {'int16','uint16'}, sc = 'CAL_NORMAL_16BIT';
        case {'int32','uint32','single'}, sc = 'CAL_NORMAL_32BIT';
        case {'double','int64','uint64'}, sc = 'CAL_NORMAL_64BIT';
        case 'boolean', sc = 'CAL_NORMAL_8BIT';
        otherwise, sc = 'CAL_NORMAL_16BIT';
    end
end

%% ================== Utilities ==================

function dt = inferCalType(afterCal, typePrefixes)
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

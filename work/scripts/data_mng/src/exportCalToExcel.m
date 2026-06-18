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
    result = struct('calCount', 0, 'outputFile', '', 'mFile', '');
    result.params = {};

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

    %% Load and scan ALL levels — check Value property for cal_ prefix
    fprintf('[1/4] Scanning all levels for cal_ Value references...\n');
    load_system(modelName);

    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
    rawCals = {};

    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            blockType = get_param(blk, 'BlockType');

            % Only check Constant and Gain blocks
            if ~strcmp(blockType, 'Constant') && ~strcmp(blockType, 'Gain')
                continue;
            end

            % Read the Value/Gain property (not the block name)
            switch blockType
                case 'Constant'
                    valExpr = strtrim(get_param(blk, 'Value'));
                case 'Gain'
                    valExpr = strtrim(get_param(blk, 'Gain'));
            end

            % Check if the value reference starts with cal_
            if ~startsWith(valExpr, 'cal_')
                continue;
            end

            % This is a calibration parameter reference
            rawCals{end+1} = struct( ...
                'blockName', get_param(blk, 'Name'), ...
                'calName', valExpr, ...
                'blockType', blockType, ...
                'path', blk); %#ok<AGROW>
        catch
        end
    end

    %% Deduplicate by calName (keep first occurrence)
    seenNames = containers.Map();
    calBlocks = {};
    for i = 1:numel(rawCals)
        key = rawCals{i}.calName;
        if ~isKey(seenNames, key)
            seenNames(key) = true;
            cb = rawCals{i};
            % Infer data type from cal_ naming
            afterCal = cb.calName(5:end);
            cb.dataType = inferCalType(afterCal);
            cb.value = cb.calName;
            cb.min = ''; cb.max = ''; cb.unit = ''; cb.description = '';
            calBlocks{end+1} = cb; %#ok<AGROW>
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
    fprintf('%-28s %-12s %s\n', 'CalName', 'DataType', 'Example Path');
    for i = 1:min(15, numel(calBlocks))
        c = calBlocks{i};
        p = c.path;
        if length(p) > 50, p = ['...' p(end-49:end)]; end
        fprintf('%-28s %-12s %s\n', c.calName, c.dataType, p);
    end
end

%% ================== Excel Writer ==================

function writeCalToExcel(calBlocks, outputFile)
    headers = {'CalName', 'BlockName', 'BlockType', 'DataType', 'Path'};
    n = numel(calBlocks);
    data = cell(n, numel(headers));
    for i = 1:n
        c = calBlocks{i};
        data{i,1} = c.calName;
        data{i,2} = c.blockName;
        data{i,3} = c.blockType;
        data{i,4} = c.dataType;
        data{i,5} = c.path;
    end
    writetable(cell2table(data, 'VariableNames', headers), outputFile, 'Sheet', 'Calibration');
end

%% ================== .M File Writer ==================

function writeCalMFile(calBlocks, mFile, modelName)
    fid = fopen(mFile, 'w');
    fprintf(fid, '%%%% %s - Calibration Parameters\n', modelName);
    fprintf(fid, '%% Auto-generated by exportCalToExcel.m on %s\n', datestr(now));
    fprintf(fid, '%% Run this script to load all calibration values into workspace.\n\n');

    for i = 1:numel(calBlocks)
        c = calBlocks{i};
        calName = c.calName;
        dt = c.dataType;
        afterCal = calName(5:end);
        % Extract description part after type prefix
        typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
        desc = afterCal;
        for t = 1:numel(typePrefixes)
            if startsWith(afterCal, typePrefixes{t})
                desc = afterCal(length(typePrefixes{t})+1:end);
                break;
            end
        end
        sc = getStorageClass(dt);

        fprintf(fid, '%%%% %s\n', calName);
        fprintf(fid, '%% %s\n', desc);
        fprintf(fid, '%s = Simulink.Parameter;\n', calName);
        fprintf(fid, '%s.Value = 0;  %% TODO: set actual value\n', calName);
        fprintf(fid, '%s.DataType = ''%s'';\n', calName, dt);
        fprintf(fid, '%s.CoderInfo.StorageClass = ''Custom'';\n', calName);
        fprintf(fid, '%s.CoderInfo.CustomStorageClass = ''%s'';\n', calName, sc);
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

function dt = inferCalType(afterCal)
    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
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

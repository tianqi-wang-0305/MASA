function result = exportAllToExcel(modelName, varargin)
% exportAllToExcel  Export signals + calibration to one Excel + .m file
%   Combines signals and calibration (deduplicated) into one workbook.
%   Also generates a .m file for calibration parameters.

    fprintf('=== Export Signals + Calibration to Excel ===\n\n');
    result = struct('signalCount', 0, 'calCount', 0, 'outputFile', '', 'mFile', '');

    %% Parse inputs
    p = inputParser;
    addRequired(p, 'modelName', @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputFile', '', @ischar);
    parse(p, modelName, varargin{:});

    modelName = char(p.Results.modelName);
    outputFile = p.Results.OutputFile;

    [modelDir, modelBase, ~] = fileparts(modelName);
    if isempty(modelDir), modelDir = pwd; modelBase = modelName; end

    if isempty(outputFile)
        outputFile = fullfile(modelDir, [modelBase '_signals_cal.xlsx']);
    end
    mFile = fullfile(modelDir, [modelBase '_LoadCalParameter.m']);
    tempSignalFile = [tempname(tempdir) '.xlsx'];
    cleanupTempSignal = onCleanup(@() deleteIfExists(tempSignalFile));

    %% Step 1: Export signals
    fprintf('[1/4] Exporting signals...\n');
    sigResult = exportSignalsToExcel(modelName, 'OutputFile', tempSignalFile);
    result.signalCount = sigResult.inputCount + sigResult.outputCount;

    %% Step 2: Scan ALL levels for calibration
    fprintf('[2/4] Scanning all levels for cal_ values...\n');
    load_system(modelName);
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
    rawCals = {};
    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            bt = get_param(blk, 'BlockType');
            calToken = extractCalToken(get_param(blk, 'Name'));
            if isempty(calToken)
                calToken = extractCalToken(get_param(blk, 'Value'));
            end

            if isempty(calToken), continue; end
            info = struct('name',calToken,'swc',modelBase,'description','', 'blockType',bt,'dataType',inferCalTypeFromValue(calToken));
            try
                info.value = get_param(blk,'Value');
            catch, info.value = ''; end
            try info.description = get_param(blk,'Description'); catch, info.description=''; end
            try info.min = get_param(blk,'Min'); catch, info.min=''; end
            try info.max = get_param(blk,'Max'); catch, info.max=''; end
            try info.unit = get_param(blk,'Unit'); catch, info.unit=''; end
            rawCals{end+1} = info; %#ok<AGROW>
        catch, end
    end

    % Deduplicate
    seen = containers.Map();
    calBlocks = {};
    for i = 1:numel(rawCals)
        if ~isKey(seen, rawCals{i}.name)
            seen(rawCals{i}.name) = true;
            calBlocks{end+1} = rawCals{i}; %#ok<AGROW>
        end
    end
    result.calCount = numel(calBlocks);
    fprintf('      Found %d unique cal_ blocks\n', numel(calBlocks));

    %% Step 3: Write combined Excel
    fprintf('[3/4] Writing combined Excel: %s\n', outputFile);
    writeCombinedExcel(sigResult, calBlocks, outputFile, modelBase);

    %% Step 4: Write .m file
    fprintf('[4/4] Writing .m file: %s\n', mFile);
    writeCalMFile(calBlocks, mFile, modelBase);

    result.outputFile = outputFile;
    result.mFile = mFile;
    fprintf('\n=== Export Complete ===\n');
    fprintf('Signals:      %d (In: %d, Out: %d)\n', result.signalCount, sigResult.inputCount, sigResult.outputCount);
    fprintf('Calibrations: %d\n', result.calCount);
    fprintf('Excel:  %s\n', outputFile);
    fprintf('M-file: %s\n', mFile);
end

function writeCombinedExcel(sigResult, calBlocks, outputFile, modelBase)
    % Sheet 1: Signals
    headersS = {'PortName','Direction','DataType','Dimensions','SampleTime','ConnectedSignal','NamingStatus'};
    nS = numel(sigResult.ports);
    dataS = cell(nS, numel(headersS));
    for i = 1:nS
        p = sigResult.ports{i};
        dataS{i,1} = safeText(p.name);
        dataS{i,2} = safeText(p.direction);
        dataS{i,3} = safeText(p.dataType);
        dataS{i,4} = safeText(p.dimensions);
        dataS{i,5} = safeText(getFieldOrDefault(p, 'sampleTime', ''));
        dataS{i,6} = safeText(getFieldOrDefault(p, 'signalName', ''));
        dataS{i,7} = safeText(getFieldOrDefault(p, 'prefixStatus', ''));
    end
    writetable(cell2table(dataS,'VariableNames',headersS), outputFile, 'Sheet', 'Signals');
    % Sheet 2: Calibration
    headersC = {'Name','BlockType','DataType','Value','Min','Max','Unit'};
    nC = numel(calBlocks);
    dataC = cell(nC, numel(headersC));
    for i = 1:nC
        c = calBlocks{i};
        dataC{i,1} = c.name;
        dataC{i,2} = safeText(c.blockType);
        dataC{i,3} = safeText(c.dataType);
        dataC{i,4} = safeText(c.value);
        dataC{i,5} = safeText(getFieldOrDefault(c, 'min', ''));
        dataC{i,6} = safeText(getFieldOrDefault(c, 'max', ''));
        dataC{i,7} = safeText(getFieldOrDefault(c, 'unit', ''));
    end
    writetable(cell2table(dataC,'VariableNames',headersC), outputFile, 'Sheet', 'Calibration');
end

function deleteIfExists(filePath)
    if isfile(filePath)
        delete(filePath);
    end
end

function dt = inferCalTypeFromValue(calToken)
    afterCal = calToken(5:end);
    if isempty(afterCal)
        dt = 'Inherit: auto';
        return;
    end

    prefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
    for t = 1:numel(prefixes)
        prefix = prefixes{t};
        if startsWith(lower(afterCal), prefix)
            rest = afterCal(length(prefix)+1:end);
            if isempty(rest) || ~isletter(rest(1))
                continue;
            end
            switch prefix
                case 's8', dt = 'int8';
                case 's16', dt = 'int16';
                case 's32', dt = 'int32';
                case 's64', dt = 'int64';
                case 'u8', dt = 'uint8';
                case 'u16', dt = 'uint16';
                case 'u32', dt = 'uint32';
                case 'u64', dt = 'uint64';
                case 'f32', dt = 'single';
                case 'f64', dt = 'double';
                case 'f16', dt = 'half';
                case {'b','bool'}, dt = 'boolean';
                otherwise, dt = 'Inherit: auto';
            end
            return;
        end
    end

    dt = 'Inherit: auto';
end

function calToken = extractCalToken(paramValue)
    calToken = '';
    if isempty(paramValue)
        return;
    end
    if isstring(paramValue)
        paramValue = char(paramValue);
    end
    if ~ischar(paramValue)
        return;
    end

    candidate = regexp(paramValue, 'cal_[A-Za-z0-9_]+', 'match', 'once');
    if ~isempty(candidate)
        calToken = candidate;
    end
end

function writeCalMFile(calBlocks, mFile, modelName)
    fid = fopen(mFile, 'w');
    fprintf(fid, '%%%% %s - Calibration Parameters\n', modelName);
    fprintf(fid, '%% Auto-generated on %s\n\n', datestr(now));
    for i = 1:numel(calBlocks)
        c = calBlocks{i};
        name = c.name;
        val = char(c.value);
        dt = c.dataType;
        sc = getStorageClass(dt);
        fprintf(fid, '%%%% %s\n', name);
        if isExportableCalValue(val)
            fprintf(fid, '%s = NoneSAR.Parameter;\n', name);
            fprintf(fid, '%s.Value = 0;\n', name);
            fprintf(fid, '%s.DataType = ''%s'';\n', name, dt);
            fprintf(fid, '%s.CoderInfo.StorageClass = ''Custom'';\n', name);
            fprintf(fid, '%s.CoderInfo.CustomStorageClass = ''%s'';\n', name, sc);
            if isfield(c, 'description') && ~isempty(c.description) && strlength(strtrim(string(c.description))) > 0
                fprintf(fid, '%s.Description = ''%s'';\n', name, escapeQuotes(c.description));
            end
            if isValidNumericScalar(c.min)
                fprintf(fid, '%s.Min = %s;\n', name, formatNumericScalar(c.min));
            end
            if isValidNumericScalar(c.max)
                fprintf(fid, '%s.Max = %s;\n', name, formatNumericScalar(c.max));
            end
            if isfield(c, 'unit') && ~isempty(c.unit) && strlength(strtrim(string(c.unit))) > 0
                fprintf(fid, '%s.Unit = ''%s'';\n', name, escapeQuotes(c.unit));
            end
        else
            fprintf(fid, '%% %s - Value: %s (manual setup needed)\n', name, val);
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
end

function ok = isExportableCalValue(val)
    ok = false;
    if isempty(val)
        return;
    end

    numVal = str2double(val);
    if ~isnan(numVal)
        ok = true;
        return;
    end

    if ~isempty(regexp(val, '^cal_[A-Za-z0-9_]+$', 'once'))
        ok = true;
    end
end

function literal = zeroLiteralForDataType(dt)
    switch lower(strtrim(char(dt)))
        case 'int8'
            literal = 'int8(0)';
        case 'uint8'
            literal = 'uint8(0)';
        case 'int16'
            literal = 'int16(0)';
        case 'uint16'
            literal = 'uint16(0)';
        case 'int32'
            literal = 'int32(0)';
        case 'uint32'
            literal = 'uint32(0)';
        case 'int64'
            literal = 'int64(0)';
        case 'uint64'
            literal = 'uint64(0)';
        case 'single'
            literal = 'single(0)';
        case 'double'
            literal = '0';
        case 'half'
            literal = 'half(0)';
        case 'boolean'
            literal = 'false';
        otherwise
            literal = '0';
    end
end

function ok = isValidNumericScalar(value)
    ok = false;
    if isempty(value)
        return;
    end
    if isnumeric(value)
        ok = isscalar(value) && isfinite(value);
        return;
    end
    if isstring(value) || ischar(value)
        numericValue = str2double(string(value));
        ok = isfinite(numericValue);
    end
end

function text = safeText(value)
    if ismissing(value)
        text = '';
        return;
    end
    if isstring(value)
        if isempty(value)
            text = '';
        else
            text = char(value);
        end
        return;
    end
    if ischar(value)
        text = value;
        return;
    end
    if isnumeric(value)
        if isempty(value)
            text = '';
        elseif isscalar(value)
            text = num2str(value);
        else
            text = mat2str(value);
        end
        return;
    end
    try
        text = char(string(value));
    catch
        text = '';
    end
end

function value = getFieldOrDefault(s, fieldName, defaultValue)
    if isstruct(s) && isfield(s, fieldName) && ~isempty(s.(fieldName))
        value = s.(fieldName);
    else
        value = defaultValue;
    end
end

function text = formatNumericScalar(value)
    if isnumeric(value)
        text = num2str(value);
        return;
    end
    text = char(string(value));
end

function sc = getStorageClass(dt)
    switch dt
        case {'int8','uint8'}, sc = 'CAL_NORMAL_8BIT';
        case {'int16','uint16'}, sc = 'CAL_NORMAL_16BIT';
        case {'int32','uint32','single'}, sc = 'CAL_NORMAL_32BIT';
        case {'double','int64','uint64'}, sc = 'CAL_NORMAL_64BIT';
        case 'boolean', sc = 'CAL_NORMAL_8BIT';
        otherwise, sc = 'CAL_NORMAL_16BIT';
    end
end

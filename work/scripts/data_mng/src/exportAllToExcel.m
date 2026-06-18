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

    %% Step 1: Export signals
    fprintf('[1/4] Exporting signals...\n');
    sigResult = exportSignalsToExcel(modelName, 'OutputFile', outputFile);
    result.signalCount = sigResult.inputCount + sigResult.outputCount;

    %% Step 2: Scan ALL levels for calibration
    fprintf('[2/4] Scanning all levels for cal_ blocks...\n');
    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
    load_system(modelName);
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'Block');
    rawCals = {};
    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            name = get_param(blk, 'Name');
            if ~startsWith(lower(name), 'cal_'), continue; end
            afterCal = name(5:end);
            if isempty(afterCal), continue; end
            hasValidType = false;
            for t = 1:numel(typePrefixes)
                if startsWith(afterCal, typePrefixes{t}), hasValidType = true; break; end
            end
            if ~hasValidType, continue; end
            bt = get_param(blk, 'BlockType');
            info = struct('name',name,'blockType',bt,'dataType',inferCalType(afterCal,typePrefixes));
            try
                switch bt
                    case 'Constant', info.value = get_param(blk,'Value');
                    case 'Gain', info.value = get_param(blk,'Gain');
                    case 'Saturation', info.value = sprintf('[%s,%s]',get_param(blk,'LowerLimit'),get_param(blk,'UpperLimit'));
                    case 'LookupTable', info.value = sprintf('Table: %s',get_param(blk,'Table'));
                    otherwise, info.value = '';
                end
            catch, info.value = ''; end
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
    writeCombinedExcel(sigResult, calBlocks, outputFile);

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

function writeCombinedExcel(sigResult, calBlocks, outputFile)
    % Sheet 1: Signals
    if sigResult.inputCount + sigResult.outputCount > 0
        headersS = {'PortName','Direction','DataType','Dimensions','SampleTime','ConnectedSignal','NamingStatus'};
        nS = numel(sigResult.ports);
        dataS = cell(nS, numel(headersS));
        for i = 1:nS
            p = sigResult.ports{i};
            dataS{i,1}=p.name; dataS{i,2}=p.direction; dataS{i,3}=p.dataType;
            dataS{i,4}=p.dimensions; dataS{i,5}=p.sampleTime;
            dataS{i,6}=p.signalName; dataS{i,7}=p.prefixStatus;
        end
        writetable(cell2table(dataS,'VariableNames',headersS), outputFile, 'Sheet', 'Signals');
    end
    % Sheet 2: Calibration
    if ~isempty(calBlocks)
        headersC = {'Name','BlockType','DataType','Value','Min','Max','Unit'};
        nC = numel(calBlocks);
        dataC = cell(nC, numel(headersC));
        for i = 1:nC
            c = calBlocks{i};
            dataC{i,1}=c.name; dataC{i,2}=c.blockType; dataC{i,3}=c.dataType;
            dataC{i,4}=char(c.value); dataC{i,5}=char(c.min);
            dataC{i,6}=char(c.max); dataC{i,7}=char(c.unit);
        end
        writetable(cell2table(dataC,'VariableNames',headersC), outputFile, 'Sheet', 'Calibration');
    end
end

function dt = inferCalType(afterCal, typePrefixes)
    for t = 1:numel(typePrefixes)
        p = typePrefixes{t};
        if startsWith(afterCal, p)
            rest = afterCal(length(p)+1:end);
            if ~isempty(rest) && isletter(rest(1))
                dt = typeMap(p); return;
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

function writeCalMFile(calBlocks, mFile, modelName)
    fid = fopen(mFile, 'w');
    fprintf(fid, '%%%% %s - Calibration Parameters\n', modelName);
    fprintf(fid, '%% Auto-generated on %s\n\n', datestr(now));
    for i = 1:numel(calBlocks)
        c = calBlocks{i};
        name = c.name;
        val = char(c.value);
        dt = c.dataType;
        numVal = str2double(val);
        sc = getStorageClass(dt);
        fprintf(fid, '%%%% %s\n', name);
        if ~isnan(numVal)
            fprintf(fid, '%s = Simulink.Parameter;\n', name);
            fprintf(fid, '%s.Value = %s;\n', name, val);
            fprintf(fid, '%s.DataType = ''%s'';\n', name, dt);
            fprintf(fid, '%s.CoderInfo.StorageClass = ''Custom'';\n', name);
            fprintf(fid, '%s.CoderInfo.CustomStorageClass = ''%s'';\n', name, sc);
            if ~isempty(c.min) && strlength(strtrim(c.min)) > 0
                if ~isnan(str2double(c.min)), fprintf(fid, '%s.Min = %s;\n', name, c.min); end
            end
            if ~isempty(c.max) && strlength(strtrim(c.max)) > 0
                if ~isnan(str2double(c.max)), fprintf(fid, '%s.Max = %s;\n', name, c.max); end
            end
        else
            fprintf(fid, '%% %s - Value: %s (manual setup needed)\n', name, val);
        end
        fprintf(fid, '\n');
    end
    fclose(fid);
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

function result = exportAllToExcel(modelName, varargin)
% exportAllToExcel  Export both signals and calibration parameters to one Excel
%   Combines exportSignalsToExcel + exportCalToExcel into a single workbook
%   with separate sheets for Signals and Calibration.
%
%   Inputs:
%       modelName  - Model name or path (.slx)
%       varargin   - 'OutputFile' - custom Excel output path
%
%   Usage:
%       result = exportAllToExcel('Model.slx');
%       result = exportAllToExcel('Model.slx', 'OutputFile', 'full_export.xlsx');

    fprintf('=== Export Signals + Calibration to Excel ===\n\n');
    result = struct('signalCount', 0, 'calCount', 0, 'outputFile', '');

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

    %% Step 1: Export signals to temporary table
    fprintf('[1/3] Exporting signals...\n');
    sigResult = exportSignalsToExcel(modelName, 'OutputFile', outputFile);
    result.signalCount = sigResult.inputCount + sigResult.outputCount;

    if sigResult.inputCount + sigResult.outputCount == 0
        fprintf('      No signals found.\n');
    end

    %% Step 2: Export calibration to temporary table
    fprintf('[2/3] Exporting calibration...\n');

    % Collect calibration data directly
    typePrefixes = {'s8','s16','s32','s64','u8','u16','u32','u64','f32','f64','f16','b','bool'};
    load_system(modelName);
    allBlocks = find_system(modelBase, 'LookUnderMasks', 'all', 'Type', 'Block');
    calBlocks = {};
    for i = 1:numel(allBlocks)
        blk = allBlocks{i};
        if strcmp(blk, modelBase), continue; end
        try
            name = get_param(blk, 'Name');
            if ~startsWith(name, 'cal_'), continue; end
            afterCal = name(5:end);
            if isempty(afterCal), continue; end
            hasValidType = false;
            for t = 1:numel(typePrefixes)
                if startsWith(afterCal, typePrefixes{t}), hasValidType = true; break; end
            end
            if ~hasValidType, continue; end

            blockType = get_param(blk, 'BlockType');
            info = struct();
            info.name = name;
            info.blockType = blockType;
            info.dataType = inferCalType(afterCal, typePrefixes);
            try
                switch blockType
                    case 'Constant', info.value = get_param(blk, 'Value');
                    case 'Gain', info.value = get_param(blk, 'Gain');
                    case 'Saturation', info.value = sprintf('[%s,%s]',get_param(blk,'LowerLimit'),get_param(blk,'UpperLimit'));
                    case 'LookupTable', info.value = sprintf('Table: %s',get_param(blk,'Table'));
                    otherwise, info.value = '';
                end
            catch, info.value = ''; end
            try info.min = get_param(blk,'Min'); catch, info.min=''; end
            try info.max = get_param(blk,'Max'); catch, info.max=''; end
            try info.unit = get_param(blk,'Unit'); catch, info.unit=''; end
            calBlocks{end+1} = info; %#ok<AGROW>
        catch, end
    end
    result.calCount = numel(calBlocks);
    fprintf('      Found %d calibration parameters\n', numel(calBlocks));

    %% Step 3: Write combined Excel
    fprintf('[3/3] Writing combined Excel: %s\n', outputFile);
    writeCombinedExcel(sigResult, calBlocks, outputFile);

    result.outputFile = outputFile;
    fprintf('\n=== Export Complete ===\n');
    fprintf('Signals:      %d (In: %d, Out: %d)\n', result.signalCount, sigResult.inputCount, sigResult.outputCount);
    fprintf('Calibrations: %d\n', result.calCount);
    fprintf('Output: %s\n', outputFile);
end

function writeCombinedExcel(sigResult, calBlocks, outputFile)
% Write signals and calibration to one Excel workbook

    % Sheet 1: Signals
    if sigResult.inputCount + sigResult.outputCount > 0
        headers = {'PortName','Direction','DataType','Dimensions','SampleTime','ConnectedSignal','NamingStatus'};
        n = numel(sigResult.ports);
        data = cell(n, numel(headers));
        for i = 1:n
            p = sigResult.ports{i};
            data{i,1}=p.name; data{i,2}=p.direction; data{i,3}=p.dataType;
            data{i,4}=p.dimensions; data{i,5}=p.sampleTime;
            data{i,6}=p.signalName; data{i,7}=p.prefixStatus;
        end
        writetable(cell2table(data,'VariableNames',headers), outputFile, 'Sheet', 'Signals');
    end

    % Sheet 2: Calibration
    if ~isempty(calBlocks)
        headers = {'Name','BlockType','DataType','Value','Min','Max','Unit'};
        n = numel(calBlocks);
        data = cell(n, numel(headers));
        for i = 1:n
            c = calBlocks{i};
            data{i,1}=c.name; data{i,2}=c.blockType; data{i,3}=c.dataType;
            data{i,4}=char(c.value); data{i,5}=char(c.min);
            data{i,6}=char(c.max); data{i,7}=char(c.unit);
        end
        writetable(cell2table(data,'VariableNames',headers), outputFile, 'Sheet', 'Calibration');
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
